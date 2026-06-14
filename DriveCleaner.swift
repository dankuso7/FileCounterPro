import Foundation
import Combine

class DriveCleaner: ObservableObject {
    @Published var isShowingModal = false
    @Published var targetDriveName: String = ""
    @Published var targetDrivePath: String = ""
    @Published var junkSizeFormatted: String = "Calculating..."
    @Published var isCleaning = false
    @Published var hasFinished = false
    
    func getJunkPaths(for path: String) -> [URL] {
        var paths: [URL] = []
        if path == "/" {
            let home = FileManager.default.homeDirectoryForCurrentUser
            paths.append(home.appendingPathComponent("Library/Caches"))
            paths.append(home.appendingPathComponent("Library/Logs"))
            paths.append(home.appendingPathComponent(".Trash"))
        } else {
            let url = URL(fileURLWithPath: path)
            paths.append(url.appendingPathComponent(".Trashes"))
        }
        return paths
    }
    
    func prepareToClean(driveName: String, drivePath: String) {
        self.targetDriveName = driveName
        self.targetDrivePath = drivePath
        self.junkSizeFormatted = "Calculating..."
        self.isCleaning = false
        self.hasFinished = false
        self.isShowingModal = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var totalSize: Int64 = 0
            let fileManager = FileManager.default
            let paths = self.getJunkPaths(for: drivePath)
            
            for path in paths {
                if let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey], options: []) {
                    for case let fileURL as URL in enumerator {
                        if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                            totalSize += Int64(size)
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                self.junkSizeFormatted = formatter.string(fromByteCount: totalSize)
            }
        }
    }
    
    func confirmClean(completion: @escaping () -> Void) {
        self.isCleaning = true
        let drivePath = self.targetDrivePath
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let paths = self.getJunkPaths(for: drivePath)
            
            for path in paths {
                if let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                    for case let fileURL as URL in enumerator {
                        try? fileManager.removeItem(at: fileURL)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isCleaning = false
                self.hasFinished = true
                completion()
            }
        }
    }
}
