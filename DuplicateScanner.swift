import Foundation
import Combine
import CryptoKit

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    var files: [URL]
}

class DuplicateScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scannedFileName = ""
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var totalWastedSpace: Int64 = 0
    
    func scan(url: URL) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0.0
            self.duplicateGroups = []
            self.totalWastedSpace = 0
        }
        
        Task.detached(priority: .userInitiated) {
            var filesBySize: [Int64: [URL]] = [:]
            
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
                // Use nextObject() to avoid Swift 6 makeIterator-in-async-context restriction
                while let obj = enumerator.nextObject(), let fileURL = obj as? URL {
                    if let attrs = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), attrs.isRegularFile == true {
                        let size = Int64(attrs.fileSize ?? 0)
                        if size > 0 {
                            filesBySize[size, default: []].append(fileURL)
                        }
                    }
                }
            }
            
            let potentialDuplicates = filesBySize.filter { $0.value.count > 1 }
            let totalPotentialFiles = self.potentialFilesCount(potentialDuplicates)
            var processedFiles = 0
            
            var confirmedGroups: [DuplicateGroup] = []
            var wastedSpace: Int64 = 0
            
            for (size, urls) in potentialDuplicates {
                var hashGroups: [String: [URL]] = [:]
                for fileURL in urls {
                    await MainActor.run { self.scannedFileName = fileURL.lastPathComponent }
                    
                    if let hash = self.hashFile(url: fileURL) {
                        hashGroups[hash, default: []].append(fileURL)
                    }
                    
                    processedFiles += 1
                    let progress = Double(processedFiles) / Double(max(1, totalPotentialFiles))
                    await MainActor.run { self.scanProgress = min(1.0, progress) }
                }
                
                for (hash, groupUrls) in hashGroups {
                    if groupUrls.count > 1 {
                        let group = DuplicateGroup(hash: hash, fileSize: size, files: groupUrls)
                        confirmedGroups.append(group)
                        wastedSpace += size * Int64(groupUrls.count - 1)
                    }
                }
            }
            
            let finalGroups = confirmedGroups.sorted(by: { $0.fileSize > $1.fileSize })
            let finalWasted = wastedSpace
            
            await MainActor.run {
                self.duplicateGroups = finalGroups
                self.totalWastedSpace = finalWasted
                self.isScanning = false
            }
        }
    }
    
    private func potentialFilesCount(_ dict: [Int64: [URL]]) -> Int {
        return dict.values.reduce(0) { $0 + $1.count }
    }
    
    private func hashFile(url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            
            // Hash first 1MB for extremely fast hashing
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            let hash = SHA256.hash(data: chunk)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
    
    func trashFile(url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for i in 0..<self.duplicateGroups.count {
                    if let idx = self.duplicateGroups[i].files.firstIndex(of: url) {
                        self.duplicateGroups[i].files.remove(at: idx)
                        self.totalWastedSpace -= self.duplicateGroups[i].fileSize
                        
                        if self.duplicateGroups[i].files.count <= 1 {
                            self.duplicateGroups.remove(at: i)
                        }
                        break
                    }
                }
            }
        } catch {
            print("Failed to trash file: \(error)")
        }
    }
}
