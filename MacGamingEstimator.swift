import Foundation
import AppKit

enum TranslationLayer: String, CaseIterable {
    case native = "Native"
    case gptk = "GPTK 2.0"
    case crossover = "CrossOver 24"
    case parallels = "Parallels Desktop"
}

enum ChipTier: Double {
    case base = 1.0     // M1/M2/M3/M4 base
    case pro = 1.6      // M-series Pro
    case max = 2.4      // M-series Max
    case ultra = 3.5    // M-series Ultra
}

struct MacGame: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let layer: TranslationLayer
    let base1080pFPS: Int // FPS on a base M1/M2 chip at 1080p medium/high
    let base1440pFPS: Int
    let requiresMetalFX: Bool
    let notes: String
}

@MainActor
class MacGamingEstimator: ObservableObject {
    @Published var pushToLimits: Bool = false
    @Published var currentChip: String = "Detecting..."
    @Published var chipTierValue: Double = 1.0
    @Published var coreCount: Int = 8
    
    // The database of games
    let games: [MacGame] = [
        // Native Apple Silicon
        MacGame(name: "Resident Evil 4 Remake", layer: .native, base1080pFPS: 45, base1440pFPS: 30, requiresMetalFX: true, notes: "Runs beautifully with MetalFX Upscaling"),
        MacGame(name: "Resident Evil Village", layer: .native, base1080pFPS: 55, base1440pFPS: 35, requiresMetalFX: true, notes: "Highly optimized native port"),
        MacGame(name: "Death Stranding Director's Cut", layer: .native, base1080pFPS: 60, base1440pFPS: 45, requiresMetalFX: true, notes: "Native Apple Silicon port, highly optimized"),
        MacGame(name: "No Man's Sky", layer: .native, base1080pFPS: 55, base1440pFPS: 40, requiresMetalFX: true, notes: "Metal port with great performance"),
        MacGame(name: "Baldur's Gate 3", layer: .native, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Native port, heavy on CPU and RAM"),
        MacGame(name: "Lies of P", layer: .native, base1080pFPS: 60, base1440pFPS: 45, requiresMetalFX: true, notes: "Flawless native port"),
        MacGame(name: "World of Warcraft", layer: .native, base1080pFPS: 90, base1440pFPS: 60, requiresMetalFX: false, notes: "Extremely optimized for M-series chips"),
        MacGame(name: "Shadow of the Tomb Raider", layer: .native, base1080pFPS: 50, base1440pFPS: 35, requiresMetalFX: false, notes: "Native Metal port, very stable"),
        MacGame(name: "Stray", layer: .native, base1080pFPS: 60, base1440pFPS: 45, requiresMetalFX: true, notes: "Native port using MetalFX"),
        MacGame(name: "Disco Elysium", layer: .native, base1080pFPS: 60, base1440pFPS: 60, requiresMetalFX: false, notes: "Runs smoothly on all chips"),
        MacGame(name: "Metro Exodus", layer: .native, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Native port, demanding visually"),
        MacGame(name: "Grid Legends", layer: .native, base1080pFPS: 50, base1440pFPS: 35, requiresMetalFX: true, notes: "Great racing game port"),
        MacGame(name: "Hades", layer: .native, base1080pFPS: 60, base1440pFPS: 60, requiresMetalFX: false, notes: "Flawless 60fps on base M1"),
        MacGame(name: "Minecraft (Native)", layer: .native, base1080pFPS: 120, base1440pFPS: 90, requiresMetalFX: false, notes: "Uses ManyMC or native ARM Java launcher"),

        // GPTK 2.0
        MacGame(name: "Cyberpunk 2077", layer: .gptk, base1080pFPS: 35, base1440pFPS: 20, requiresMetalFX: false, notes: "Playable with FSR via GPTK 2.0"),
        MacGame(name: "Diablo IV", layer: .gptk, base1080pFPS: 50, base1440pFPS: 35, requiresMetalFX: false, notes: "Runs smoothly via GPTK"),
        MacGame(name: "Hogwarts Legacy", layer: .gptk, base1080pFPS: 30, base1440pFPS: 15, requiresMetalFX: false, notes: "Heavy game, FSR recommended"),
        MacGame(name: "Elden Ring", layer: .gptk, base1080pFPS: 45, base1440pFPS: 30, requiresMetalFX: false, notes: "Locked at 60 max, runs very well"),
        MacGame(name: "Spider-Man Remastered", layer: .gptk, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Use FSR 2.0 for best results"),
        MacGame(name: "Spider-Man: Miles Morales", layer: .gptk, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Similar performance to Remastered"),
        MacGame(name: "God of War", layer: .gptk, base1080pFPS: 35, base1440pFPS: 20, requiresMetalFX: false, notes: "Playable but demanding"),
        MacGame(name: "Final Fantasy VII Remake", layer: .gptk, base1080pFPS: 50, base1440pFPS: 30, requiresMetalFX: false, notes: "Runs surprisingly well"),
        MacGame(name: "Starfield", layer: .gptk, base1080pFPS: 20, base1440pFPS: 10, requiresMetalFX: false, notes: "Very heavy, requires Pro/Max for good FPS"),
        MacGame(name: "Palworld", layer: .gptk, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Playable, uses Unreal Engine 5"),
        MacGame(name: "Helldivers 2", layer: .gptk, base1080pFPS: 35, base1440pFPS: 20, requiresMetalFX: false, notes: "Anti-cheat issues may occur, check community updates"),

        // CrossOver 24
        MacGame(name: "Grand Theft Auto V", layer: .crossover, base1080pFPS: 60, base1440pFPS: 45, requiresMetalFX: false, notes: "Runs flawlessly on CrossOver with D3DMetal"),
        MacGame(name: "Horizon Zero Dawn", layer: .crossover, base1080pFPS: 40, base1440pFPS: 25, requiresMetalFX: false, notes: "Requires D3DMetal enabled in CrossOver"),
        MacGame(name: "Red Dead Redemption 2", layer: .crossover, base1080pFPS: 30, base1440pFPS: 15, requiresMetalFX: false, notes: "Heavy on GPU, decent on Pro/Max chips"),
        MacGame(name: "The Witcher 3: Wild Hunt", layer: .crossover, base1080pFPS: 50, base1440pFPS: 35, requiresMetalFX: false, notes: "DX12 version runs well via D3DMetal"),
        MacGame(name: "Rocket League", layer: .crossover, base1080pFPS: 120, base1440pFPS: 90, requiresMetalFX: false, notes: "Runs perfectly in CrossOver"),
        MacGame(name: "Overwatch 2", layer: .crossover, base1080pFPS: 60, base1440pFPS: 45, requiresMetalFX: false, notes: "Playable, minor shader compilation stutters"),
        MacGame(name: "Lethal Company", layer: .crossover, base1080pFPS: 60, base1440pFPS: 60, requiresMetalFX: false, notes: "Runs perfectly"),
        MacGame(name: "Fallout 4", layer: .crossover, base1080pFPS: 50, base1440pFPS: 40, requiresMetalFX: false, notes: "Playable with high settings"),
        MacGame(name: "Left 4 Dead 2", layer: .crossover, base1080pFPS: 120, base1440pFPS: 90, requiresMetalFX: false, notes: "Runs perfectly via CrossOver")
    ]
    
    init() {
        detectHardware()
    }
    
    private func detectHardware() {
        Task {
            let hwRaw = await shellString("system_profiler SPHardwareDataType 2>/dev/null")
            let chipRaw = parseFirst(hwRaw, pattern: "Chip:\\s*(.+)") ?? "Apple M1"
            let coresRaw = parseFirst(hwRaw, pattern: "Total Number of Cores:\\s*(.+)") ?? "8"
            
            self.currentChip = chipRaw
            
            // Extract core count
            if let firstNumStr = coresRaw.components(separatedBy: CharacterSet.decimalDigits.inverted).first(where: { !$0.isEmpty }),
               let count = Int(firstNumStr) {
                self.coreCount = count
            }
            
            // Determine Tier multiplier
            var baseMult = ChipTier.base.rawValue
            if chipRaw.localizedCaseInsensitiveContains("Ultra") {
                baseMult = ChipTier.ultra.rawValue
            } else if chipRaw.localizedCaseInsensitiveContains("Max") {
                baseMult = ChipTier.max.rawValue
            } else if chipRaw.localizedCaseInsensitiveContains("Pro") {
                baseMult = ChipTier.pro.rawValue
            }
            
            // M3/M4 have stronger baseline GPUs, adjust tier multiplier slightly
            if chipRaw.localizedCaseInsensitiveContains("M4") {
                baseMult *= 1.3
            } else if chipRaw.localizedCaseInsensitiveContains("M3") {
                baseMult *= 1.15
            }
            
            self.chipTierValue = baseMult
        }
    }
    
    func estimateFPS(for game: MacGame, resolution: Int) -> Int {
        let baseFPS = resolution == 1440 ? game.base1440pFPS : game.base1080pFPS
        var calculated = Double(baseFPS) * chipTierValue
        
        // Push to limits gives a ~12% boost
        if pushToLimits {
            calculated *= 1.12
        }
        
        return Int(calculated)
    }
    
    private func shellString(_ command: String) async -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
    
    private func parseFirst(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespaces)
    }
}
