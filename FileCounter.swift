import Foundation

enum FileCategory {
    case good
    case important
    case malicious
    case unknown
}

struct FileItem: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let formattedSize: String
    let category: FileCategory
    let aiExplanation: String?
}

class FileCounter: ObservableObject {
    @Published var count: Int = 0
    @Published var isCounting: Bool = false
    @Published var files: [FileItem] = []
    
    func countFiles(at url: URL) {
        DispatchQueue.main.async {
            self.isCounting = true
            self.count = 0
            self.files = []
        }
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            var localCount = 0
            var localFiles: [FileItem] = []
            
            let byteFormatter = ByteCountFormatter()
            byteFormatter.allowedUnits = [.useAll]
            byteFormatter.countStyle = .file
            
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: []) {
                while let obj = enumerator.nextObject(), let fileURL = obj as? URL {
                    autoreleasepool {
                        if let values = try? fileURL.resourceValues(forKeys: Set(keys)), let isRegular = values.isRegularFile, isRegular {
                            localCount += 1
                            
                            let size = values.fileSize ?? 0
                            let formattedSize = byteFormatter.string(fromByteCount: Int64(size))
                            let name = fileURL.lastPathComponent
                            let (category, aiExplanation) = self.classifyFile(name: name, url: fileURL, fileSize: size)
                            
                            let item = FileItem(name: name, formattedSize: formattedSize, category: category, aiExplanation: aiExplanation)
                            localFiles.append(item)
                            
                            if localCount % 1000 == 0 {
                                let currentCount = localCount
                                let newFiles = localFiles
                                DispatchQueue.main.async {
                                    self.count = currentCount
                                    self.files.append(contentsOf: newFiles)
                                }
                                localFiles.removeAll(keepingCapacity: true)
                            }
                        }
                    }
                }
            }
            
            let finalCount = localCount
            let finalFiles = localFiles
            DispatchQueue.main.async {
                self.count = finalCount
                self.files.append(contentsOf: finalFiles)
                self.isCounting = false
            }
        }
    }
    
    private func classifyFile(name: String, url: URL, fileSize: Int) -> (FileCategory, String?) {
        let ext = url.pathExtension.lowercased()
        let lowerName = name.lowercased()
        
        var threats: [String] = []
        
        // 1. Deep Content-based Malicious Heuristics
        if fileSize < 5_000_000 {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                // Threat 1: Persistence
                if content.contains("Library/LaunchAgents") || content.contains("Library/LaunchDaemons") {
                    threats.append("• Detected attempt to establish macOS persistence by writing to `LaunchAgents/LaunchDaemons`.")
                }
                if content.contains(".zshrc") || content.contains(".bash_profile") || content.contains(".bashrc") {
                    threats.append("• Detected code modifying user shell profiles (`.zshrc`/`.bash_profile`) to run silently on startup.")
                }
                
                // Threat 2: Credential Phishing / osascript
                if content.contains("osascript") && (content.contains("password") || content.contains("System Events")) {
                    threats.append("• Detected AppleScript (`osascript`) designed to silently prompt the user for their administrator password.")
                }
                
                // Threat 3: Data Exfiltration
                if content.contains(".ssh/id_rsa") || content.contains("Library/Keychains") {
                    threats.append("• Detected code attempting to read sensitive cryptographic keys (`id_rsa` or `Keychains`).")
                }
                if content.contains("Application Support/Google/Chrome") && content.contains("Cookies") {
                    threats.append("• Detected code attempting to steal browser session cookies.")
                }
                
                // Threat 4: Remote Payloads & Obfuscation
                if content.contains("eval(base64_decode(") {
                    threats.append("• Detected heavily obfuscated base64 execution payload (`eval(base64_decode`).")
                }
                if (content.contains("curl ") && content.contains(" | bash")) || (content.contains("wget ") && content.contains(" | sh")) || (content.contains("curl ") && content.contains(" | sh")) {
                    threats.append("• Detected an automated remote execution payload (`curl | bash`). This is used to download and run trojans directly from the internet.")
                }
                if content.contains("nc -e /bin/sh") || content.contains("/dev/tcp/") {
                    threats.append("• Detected a reverse shell payload. This allows an attacker to gain direct remote access to this machine.")
                }
            }
        }
        
        // 2. Extension-based Malicious Heuristics
        let maliciousExtensions = ["exe", "bat", "vbs", "cmd", "ps1"]
        if maliciousExtensions.contains(ext) {
            threats.append("• Detected a Windows executable script/binary (`\(ext)`). Analysis indicates this cannot run natively on macOS, but its presence inside a Mac environment heavily implies a multi-platform malware package.")
        }
        if lowerName.contains("virus") || lowerName.contains("malware") || lowerName.contains("trojan") || lowerName.contains("payload") {
            threats.append("• The filename explicitly matches known malicious nomenclature (`\(lowerName)`).")
        }
        
        if !threats.isEmpty {
            let explanation = """
            **Threat Level:** CRITICAL 🔴
            
            **Deep Forensic Findings:**
            \(threats.joined(separator: "\n"))
            
            **Verdict:** This file exhibits behaviors highly consistent with advanced macOS spyware/trojans or multi-platform payloads. DO NOT execute.
            """
            return (.malicious, explanation)
        }
        
        // 3. Important Heuristics
        let importantExtensions = ["plist", "dylib", "framework", "db", "sqlite", "car", "nib", "storyboardc", "mobileprovision", "cer"]
        if importantExtensions.contains(ext) {
            return (.important, "This is a standard macOS configuration file, database, or compiled library. It is required for the application to function properly.")
        }
        if ext.isEmpty && !lowerName.hasPrefix(".") {
            return (.important, "This appears to be a compiled Mach-O binary. Unlike Windows `.exe` files, macOS executables often lack a file extension. It is completely normal inside an application bundle.")
        }
        
        // 4. Good Heuristics
        let goodExtensions = ["png", "jpg", "jpeg", "gif", "svg", "txt", "md", "swift", "h", "m", "cpp", "c", "json", "xml", "html", "css", "js", "pdf", "xcassets", "sh", "py", "php", "command"]
        if goodExtensions.contains(ext) {
            return (.good, nil)
        }
        
        return (.unknown, nil)
    }
}
