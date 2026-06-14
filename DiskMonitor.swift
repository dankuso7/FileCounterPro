import Foundation
import Combine

struct DriveInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let totalSpaceFormatted: String
    let freeSpaceFormatted: String
    let usedSpaceFormatted: String
    let usagePercentage: Double
    let smartStatus: String
}

class DiskMonitor: ObservableObject {
    @Published var drives: [DriveInfo] = []
    
    init() {
        refresh()
    }
    
    func refresh() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var fetchedDrives: [DriveInfo] = []
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            
            for url in volumes {
                // Filter to only include root and external drives mounted in /Volumes/
                guard url.path == "/" || url.path.hasPrefix("/Volumes/") else { continue }
                
                do {
                    let values = try url.resourceValues(forKeys: Set(keys))
                    guard let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity else { continue }
                    
                    let name = values.volumeName ?? url.lastPathComponent
                    let used = total - free
                    let usagePct = Double(used) / Double(total)
                    
                    // Fetch SMART status
                    var smartStatus = "Not Supported"
                    let task = Process()
                    task.launchPath = "/usr/sbin/diskutil"
                    task.arguments = ["info", url.path]
                    let pipe = Pipe()
                    task.standardOutput = pipe
                    
                    do {
                        try task.run()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            for line in output.components(separatedBy: .newlines) {
                                if line.contains("SMART Status:") {
                                    let parts = line.components(separatedBy: ":")
                                    if parts.count > 1 {
                                        let parsed = parts[1].trimmingCharacters(in: .whitespaces)
                                        if !parsed.isEmpty {
                                            smartStatus = parsed
                                        }
                                    }
                                    break
                                }
                            }
                        }
                    } catch {
                        // ignore error
                    }
                    
                    let drive = DriveInfo(
                        name: name,
                        path: url.path,
                        totalSpaceFormatted: formatter.string(fromByteCount: Int64(total)),
                        freeSpaceFormatted: formatter.string(fromByteCount: Int64(free)),
                        usedSpaceFormatted: formatter.string(fromByteCount: Int64(used)),
                        usagePercentage: usagePct,
                        smartStatus: smartStatus
                    )
                    fetchedDrives.append(drive)
                    
                } catch {
                    continue
                }
            }
            
            DispatchQueue.main.async {
                self.drives = fetchedDrives
            }
        }
    }
}
