import Foundation
import AppKit

struct ScanResult: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let isMalicious: Bool
    let signs: [String]
    let aiExplanation: String?
}

class LargeFileScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scannedFileName: String = ""
    @Published var scanComplete = false
    @Published var isClean = false
    @Published var scanResults: [ScanResult] = []
    
    // Malicious signatures
    let badStrings = [
        "LaunchAgents", "LaunchDaemons", "osascript -e", ".zshrc", 
        ".bash_profile", "base64_decode", "/dev/tcp", "nc -e", 
        "chmod +x", "curl -sL", "wget -q", "crontab", "rm -rf /",
        "miner", "xmrig", "cgminer", "ncat", "pupy", "empire", "metasploit", "stratum+tcp"
    ]
    
    private func generateAIAnalysis(for signs: [String]) -> String? {
        guard !signs.isEmpty else { return nil }
        
        var explanation = "Based on the detected code signatures, this file exhibits the following behaviors:\n\n"
        
        var behaviors: [String] = []
        var mainProblem = "Unknown"
        
        if signs.contains(where: { ["LaunchAgents", "LaunchDaemons", "crontab", ".zshrc", ".bash_profile"].contains($0) }) {
            behaviors.append("• Persistence Mechanism: The code attempts to embed itself in your system startup scripts (like LaunchAgents or crontab). This ensures the malware runs automatically in the background every time you start your computer without your knowledge.")
            mainProblem = "System Persistence & Background Execution"
        }
        
        if signs.contains(where: { ["/dev/tcp", "nc -e"].contains($0) }) {
            behaviors.append("• Reverse Shell: The code opens a direct network connection back to an attacker's remote server. This essentially acts as a backdoor, granting the attacker live, remote command-line access to your machine.")
            mainProblem = "Remote Code Execution & Unauthorized Access"
        }
        
        if signs.contains(where: { ["curl -sL", "wget -q", "chmod +x"].contains($0) }) {
            behaviors.append("• Payload Dropper: The script reaches out to the internet silently to download secondary malicious files, marks them as executable, and runs them. This is typical of a 'dropper' malware that fetches the main virus payload.")
            if mainProblem == "Unknown" { mainProblem = "Secondary Payload Delivery" }
        }
        
        if signs.contains("rm -rf /") {
            behaviors.append("• Destructive Payload: The code contains commands that attempt to recursively and irreversibly delete all files and folders on your hard drive, leading to a completely unrecoverable system state.")
            mainProblem = "Total Data Loss (Wiper/Destructive Malware)"
        }
        
        if signs.contains(where: { ["osascript -e", "base64_decode"].contains($0) }) {
            behaviors.append("• Obfuscation & UI Spoofing: The script uses base64 encoding to hide its true intentions from antivirus software, and utilizes AppleScript (osascript) to potentially spawn fake password prompts to steal your Mac login credentials.")
            if mainProblem == "Unknown" { mainProblem = "Credential Theft & Evasion" }
        }
        
        if behaviors.isEmpty {
            behaviors.append("• Generic Suspicious Activity: The code uses command-line techniques that are frequently abused by macOS malware to modify system state or bypass security protections.")
            mainProblem = "Suspicious System Modifications"
        }
        
        explanation += behaviors.joined(separator: "\n\n")
        explanation += "\n\n**Main Problem:** \(mainProblem)"
        
        return explanation
    }
    
    func scanFile(at url: URL) {
        startScan(urls: [url])
    }
    
    func deleteThreat(_ result: ScanResult) {
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.recycle([url], completionHandler: { (newURLs, error) in
            DispatchQueue.main.async {
                if error == nil {
                    self.scanResults.removeAll(where: { $0.id == result.id })
                    if self.scanResults.filter({ $0.isMalicious }).isEmpty {
                        self.isClean = true
                    }
                }
            }
        })
    }
    
    func revealInFinder(_ result: ScanResult) {
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    func scanFullSystem() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        let criticalDirs: [URL] = [
            homeDir.appendingPathComponent("Downloads"),
            homeDir.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
            URL(fileURLWithPath: "/tmp")
        ]
        
        startScan(urls: criticalDirs)
    }
    
    private func startScan(urls: [URL]) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0.0
            self.scanResults = []
            self.scanComplete = false
            self.isClean = false
            self.scannedFileName = urls.count == 1 ? urls[0].lastPathComponent : "Full System Scan"
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var filesToScan: [URL] = []
            
            for url in urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            if let attrs = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), attrs.isRegularFile == true {
                                filesToScan.append(fileURL)
                            }
                        }
                    }
                } else if FileManager.default.fileExists(atPath: url.path) {
                    filesToScan.append(url)
                }
            }
            
            var totalBytes: Int64 = 0
            for file in filesToScan {
                totalBytes += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
            
            var bytesRead: Int64 = 0
            var foundResults: [ScanResult] = []
            
            for fileURL in filesToScan {
                DispatchQueue.main.async {
                    self.scannedFileName = fileURL.lastPathComponent
                }
                
                guard let handle = try? FileHandle(forReadingFrom: fileURL) else { continue }
                
                let chunkSize = 1024 * 1024 * 5 // 5MB chunks for speed
                let overlap = 1024 // To catch strings cut on the chunk border
                var localThreats: Set<String> = []
                var previousChunk = Data()
                
                var isEOF = false
                while !isEOF {
                    autoreleasepool {
                        guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                            isEOF = true
                            return
                        }
                        
                        let combined = previousChunk + chunk
                        if let text = String(data: combined, encoding: .utf8) ?? String(data: combined, encoding: .ascii) {
                            for threat in self.badStrings {
                                if text.contains(threat) {
                                    localThreats.insert(threat)
                                }
                            }
                        }
                        
                        if chunk.count >= overlap {
                            previousChunk = chunk.suffix(overlap)
                        } else {
                            previousChunk = chunk
                        }
                        
                        bytesRead += Int64(chunk.count)
                        
                        let progress = Double(bytesRead) / Double(max(1, totalBytes))
                        DispatchQueue.main.async {
                            self.scanProgress = min(1.0, progress)
                        }
                    }
                }
                try? handle.close()
                
                let signsArray = Array(localThreats)
                let explanation = self.generateAIAnalysis(for: signsArray)
                
                let result = ScanResult(
                    fileName: fileURL.lastPathComponent,
                    filePath: fileURL.path,
                    isMalicious: !localThreats.isEmpty,
                    signs: signsArray,
                    aiExplanation: explanation
                )
                foundResults.append(result)
                
                if foundResults.count % 5 == 0 {
                    let partial = foundResults
                    DispatchQueue.main.async {
                        self.scanResults = partial
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.scanResults = foundResults
                self.isScanning = false
                self.scanComplete = true
                self.isClean = !foundResults.contains(where: { $0.isMalicious })
            }
        }
    }
}
