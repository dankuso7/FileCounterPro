import Foundation
import Combine

struct InstalledGame: Identifiable, Equatable {
    let id = UUID()
    let profile: GameProfile
    let path: String
}

@MainActor
class GameScanner: ObservableObject {
    @Published var installedGames: [InstalledGame] = []
    @Published var isScanning: Bool = false
    
    // Fallback games to show if nothing is installed
    @Published var showcaseGames: [GameProfile] = []

    func scanForGames() async {
        isScanning = true
        installedGames = []
        
        // Setup showcase games (just pick the top 4 from the database)
        showcaseGames = Array(GameDatabase.profiles.prefix(4))
        
        var searchDirectories = [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
            "\(NSHomeDirectory())/Library/Application Support/Steam/steamapps/common",
            "/Users/Shared/Epic Games"
        ]
        
        let fileManager = FileManager.default
        
        // Add external volumes
        if let volumes = try? fileManager.contentsOfDirectory(atPath: "/Volumes") {
            for volume in volumes {
                let volPath = "/Volumes/\(volume)"
                if volume != "Macintosh HD" && !volume.hasPrefix(".") {
                    searchDirectories.append(volPath)
                    searchDirectories.append("\(volPath)/Applications")
                    searchDirectories.append("\(volPath)/Games")
                }
            }
        }
        
        var foundApps: [String] = []
        
        // Scan standard paths concurrently but process sequentially to keep it simple
        for dir in searchDirectories {
            let url = URL(fileURLWithPath: dir)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) else {
                continue
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                foundApps.append(fileURL.lastPathComponent)
            }
        }
        
        // Now match found apps against the database
        var matchedGames: [InstalledGame] = []
        
        for profile in GameDatabase.profiles {
            for appName in foundApps {
                let lowerApp = appName.lowercased()
                if profile.searchIdentifiers.contains(where: { lowerApp.contains($0.lowercased()) }) {
                    // Avoid duplicates
                    if !matchedGames.contains(where: { $0.profile.name == profile.name }) {
                        matchedGames.append(InstalledGame(profile: profile, path: appName))
                    }
                    break
                }
            }
        }
        
        // Fake a tiny delay for UX purposes
        try? await Task.sleep(for: .seconds(1))
        
        self.installedGames = matchedGames
        self.isScanning = false
    }
}
