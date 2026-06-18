import Foundation
import Combine

enum ZipCompressionLevel: Int {
    case storeOnly = 0
    case fast = 1
    case standard = 6
    case maximum = 9
    
    var description: String {
        switch self {
        case .storeOnly: return "Store Only (No Compression, Ultra Fast)"
        case .fast: return "Fast (Light Compression)"
        case .standard: return "Standard (Balanced)"
        case .maximum: return "Maximum (Smallest Size, Slower)"
        }
    }
}

@MainActor
final class ZipEngine: ObservableObject {
    @Published var isZipping = false
    @Published var progress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var totalFiles: Int = 0
    @Published var processedFiles: Int = 0
    
    private var process: Process?
    
    func cancel() {
        if let p = process, p.isRunning {
            p.terminate()
            statusMessage = "Cancelled by user"
            isZipping = false
        }
    }
    
    func createZip(sourceURLs: [URL], destinationURL: URL, level: ZipCompressionLevel) {
        guard !sourceURLs.isEmpty else { return }
        
        isZipping = true
        progress = 0.0
        processedFiles = 0
        totalFiles = 0
        currentFile = "Scanning files..."
        statusMessage = "Preparing..."
        
        Task.detached {
            // Pre-count files for progress bar
            var count = 0
            for url in sourceURLs {
                if url.hasDirectoryPath {
                    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey]) {
                        for _ in enumerator { count += 1 }
                    }
                }
                count += 1 // the item itself
            }
            
            let finalCount = count
            await MainActor.run {
                self.totalFiles = finalCount
                self.statusMessage = "Compressing \(finalCount) items..."
            }
            
            // Build zip command
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let parentPath = sourceURLs.first!.deletingLastPathComponent().path
            let destPath = destinationURL.path
            let fileNames = sourceURLs.map { "'\($0.lastPathComponent)'" }.joined(separator: " ")
            let bashCommand = "cd '\(parentPath)' && /usr/bin/zip -r -\(level.rawValue) '\(destPath)' \(fileNames)"
            
            p.arguments = ["-c", bashCommand]
            
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            
            await MainActor.run { self.process = p }
            
            do {
                try p.run()
                
                let fileHandle = pipe.fileHandleForReading
                
                // Read streaming output
                for try await line in fileHandle.bytes.lines {
                    await MainActor.run {
                        if line.contains("adding:") || line.contains("updating:") {
                            self.processedFiles += 1
                            if self.totalFiles > 0 {
                                self.progress = Double(self.processedFiles) / Double(self.totalFiles)
                            }
                            // Extract filename
                            if let name = line.split(separator: " ").dropFirst().first {
                                self.currentFile = String(name)
                            }
                        }
                    }
                }
                
                p.waitUntilExit()
                
                await MainActor.run {
                    self.isZipping = false
                    if p.terminationStatus == 0 {
                        self.statusMessage = "Compression Complete!"
                        self.progress = 1.0
                        self.currentFile = "Saved to: \(destinationURL.lastPathComponent)"
                    } else if p.terminationStatus == 15 { // Terminated
                        self.statusMessage = "Cancelled"
                    } else {
                        self.statusMessage = "Error: Code \(p.terminationStatus)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isZipping = false
                    self.statusMessage = "Failed to run zip: \(error.localizedDescription)"
                }
            }
        }
    }
}
