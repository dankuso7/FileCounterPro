import Foundation
import AppKit
import SwiftUI

enum SafetyRating {
    case safe
    case caution
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        }
    }
    
    var label: String {
        switch self {
        case .safe: return "Safe to Delete"
        case .caution: return "Caution: User Data"
        }
    }
}

struct LeftoverFile: Hashable {
    let url: URL
    let safety: SafetyRating
}

struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleId: String
    let appUrl: URL
    let icon: NSImage?
    let totalSize: Int64
    let leftoverFiles: [LeftoverFile]
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
class SmartUninstaller: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: String = ""
    @Published var trashSize: Int64 = 0
    
    private let fileManager = FileManager.default
    
    func scanApplications() {
        isScanning = true
        apps = []
        scanProgress = "Scanning /Applications folder..."
        scanTrash()
        
        Task {
            let appUrls = getApplicationURLs()
            var results: [InstalledApp] = []
            
            for (index, appUrl) in appUrls.enumerated() {
                // Throttle UI updates
                if index % 5 == 0 {
                    let name = appUrl.deletingPathExtension().lastPathComponent
                    await MainActor.run { scanProgress = "Analyzing \(name)..." }
                }
                
                if let bundleId = getBundleIdentifier(for: appUrl) {
                    let name = appUrl.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
                    
                    let leftovers = findLeftoverFiles(for: bundleId, appName: name)
                    let appSize = sizeForLocalFilePath(appUrl.path)
                    let leftoversSize = leftovers.reduce(0) { $0 + sizeForLocalFilePath($1.url.path) }
                    
                    let app = InstalledApp(
                        name: name,
                        bundleId: bundleId,
                        appUrl: appUrl,
                        icon: icon,
                        totalSize: appSize + leftoversSize,
                        leftoverFiles: leftovers
                    )
                    results.append(app)
                }
            }
            
            // Sort by size
            results.sort { $0.totalSize > $1.totalSize }
            
            await MainActor.run {
                self.apps = results
                self.isScanning = false
                self.scanProgress = "Found \(results.count) applications."
            }
        }
    }
    
    func uninstall(app: InstalledApp) async -> Bool {
        do {
            try fileManager.trashItem(at: app.appUrl, resultingItemURL: nil)
            for leftover in app.leftoverFiles {
                if fileManager.fileExists(atPath: leftover.url.path) {
                    try fileManager.trashItem(at: leftover.url, resultingItemURL: nil)
                }
            }
            return true
        } catch {
            print("Failed to trash files: \(error)")
            return false
        }
    }
    
    func scanTrash() {
        let trashUrl = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        self.trashSize = sizeForLocalFilePath(trashUrl.path)
    }
    
    func emptyTrash() async -> Bool {
        let trashUrl = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        do {
            let contents = try fileManager.contentsOfDirectory(at: trashUrl, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
            }
            await MainActor.run {
                self.trashSize = 0
            }
            return true
        } catch {
            print("Failed to empty trash: \(error)")
            return false
        }
    }
    
    private func getApplicationURLs() -> [URL] {
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        var urls: [URL] = []
        for dir in appDirs {
            if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsPackageDescendants, .skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        urls.append(fileURL)
                    }
                }
            }
        }
        return urls
    }
    
    private func getBundleIdentifier(for url: URL) -> String? {
        let plistUrl = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistUrl) else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }
    
    private func findLeftoverFiles(for bundleId: String, appName: String) -> [LeftoverFile] {
        var leftovers: [LeftoverFile] = []
        let homeUrl = fileManager.homeDirectoryForCurrentUser
        let userLibraryUrl = homeUrl.appendingPathComponent("Library")
        let globalLibraryUrl = URL(fileURLWithPath: "/Library")
        
        // Target common leftover directories
        let searchLocations = [
            userLibraryUrl.appendingPathComponent("Application Support"),
            userLibraryUrl.appendingPathComponent("Caches"),
            userLibraryUrl.appendingPathComponent("Preferences"),
            userLibraryUrl.appendingPathComponent("Preferences/ByHost"),
            userLibraryUrl.appendingPathComponent("Logs"),
            userLibraryUrl.appendingPathComponent("Saved Application State"),
            userLibraryUrl.appendingPathComponent("Containers"),
            userLibraryUrl.appendingPathComponent("WebKit"),
            userLibraryUrl.appendingPathComponent("Cookies"),
            globalLibraryUrl.appendingPathComponent("Application Support"),
            globalLibraryUrl.appendingPathComponent("Caches"),
            globalLibraryUrl.appendingPathComponent("Preferences"),
            globalLibraryUrl.appendingPathComponent("Logs")
        ]
        
        for searchDir in searchLocations {
            if !fileManager.fileExists(atPath: searchDir.path) { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: searchDir, includingPropertiesForKeys: nil)
                for fileUrl in contents {
                    let name = fileUrl.lastPathComponent.lowercased()
                    // Match by bundle ID or Application Name
                    if name.contains(bundleId.lowercased()) || name.contains(appName.lowercased()) {
                        let safety = analyzeSafety(for: searchDir, fileName: name)
                        leftovers.append(LeftoverFile(url: fileUrl, safety: safety))
                    }
                }
            } catch {
                continue
            }
        }
        return leftovers
    }
    
    private func analyzeSafety(for directory: URL, fileName: String) -> SafetyRating {
        let dirName = directory.lastPathComponent.lowercased()
        let name = fileName.lowercased()
        
        // AI Rules for safety
        if dirName == "caches" || dirName == "logs" || dirName == "cookies" || dirName == "webkit" || name.contains(".cache") || name.contains(".log") {
            return .safe
        } else {
            return .caution
        }
    }
    
    private func sizeForLocalFilePath(_ filePath: String) -> Int64 {
        do {
            let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
            if let fileSize = fileAttributes[FileAttributeKey.size] as? NSNumber {
                return fileSize.int64Value
            } else if let type = fileAttributes[FileAttributeKey.type] as? String, type == FileAttributeType.typeDirectory.rawValue {
                // If it's a directory (like an app bundle), we need to iterate
                var folderSize: Int64 = 0
                if let enumerator = fileManager.enumerator(atPath: filePath) {
                    for file in enumerator {
                        if let attrs = enumerator.fileAttributes {
                            folderSize += (attrs[FileAttributeKey.size] as? NSNumber)?.int64Value ?? 0
                        }
                    }
                }
                return folderSize
            }
            return 0
        } catch {
            return 0
        }
    }
}
