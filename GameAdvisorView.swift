import SwiftUI

struct GameAdvisorView: View {
    @StateObject private var scanner = GameScanner()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ── Header ──────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game Performance Advisor")
                            .font(.system(size: 24, weight: .bold))
                        Text("Optimal settings & power predictions for M4 Mac mini")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Launch HUD Button
                    Button {
                        GameHUDController.shared.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                            Text("Toggle Real-Time HUD")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer().frame(width: 20)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if scanner.isScanning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning drives for installed games...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    if !scanner.installedGames.isEmpty {
                        Text("Installed Games Found")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        ForEach(scanner.installedGames) { game in
                            GameProfileCard(profile: game.profile, status: "Installed: \(game.path)")
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No recognizable games found in standard folders.")
                                .font(.headline)
                            Text("Here are some recommended showcase games for your M4 chip and how they perform:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)

                        Text("Recommended for M4 Mac mini")
                            .font(.headline)
                        
                        ForEach(scanner.showcaseGames) { profile in
                            GameProfileCard(profile: profile, status: "Not Installed")
                        }
                    }
                }
            }
            .padding(28)
        }
        .frame(width: 700, height: 600)
        .background(.regularMaterial)
        .onAppear {
            Task {
                await scanner.scanForGames()
            }
        }
    }
}

struct GameProfileCard: View {
    let profile: GameProfile
    let status: String
    
    var color1: Color { Color(hex: profile.coverColor1) }
    var color2: Color { Color(hex: profile.coverColor2) }

    var body: some View {
        HStack(spacing: 20) {
            // Game Art Placeholder
            ZStack {
                LinearGradient(colors: [color1, color2], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 100, height: 140)
            .cornerRadius(8)
            .shadow(color: color1.opacity(0.3), radius: 5, x: 0, y: 5)

            // Details
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(profile.name)
                        .font(.title3.bold())
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.contains("Not") ? Color.secondary.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(status.contains("Not") ? .secondary : .green)
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    GameMetricPill(icon: "display", label: "Resolution", value: profile.recommendedResolution)
                    GameMetricPill(icon: "slider.horizontal.3", label: "Settings", value: profile.recommendedPreset)
                }
                
                HStack(spacing: 16) {
                    GameMetricPill(icon: "speedometer", label: "Target FPS", value: profile.expectedFPS, valueColor: .green)
                    GameMetricPill(icon: "bolt.fill", label: "Predicted Power", value: "\(Int(profile.predictedPowerDrawW))W (Total System)", valueColor: .orange)
                    GameMetricPill(icon: "cpu", label: "CPU Usage", value: profile.predictedCPUUsage)
                    GameMetricPill(icon: "memorychip", label: "RAM Usage", value: profile.predictedRAMUsage)
                    GameMetricPill(icon: "thermometer", label: "Thermals", value: profile.thermalPrediction, valueColor: profile.thermalPrediction.contains("Hot") ? .red : (profile.thermalPrediction.contains("Warm") ? .orange : .green))
                }

                Text("Visual Fidelity: \(profile.visualFidelity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    
                // AI Optimization Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("AI Optimization (Minimize Lag)")
                            .font(.caption.bold())
                            .foregroundColor(.purple)
                        Spacer()
                        Text("Lag Risk: \(profile.lagRisk)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(profile.lagRisk.contains("High") ? Color.red.opacity(0.2) : (profile.lagRisk.contains("Medium") ? Color.orange.opacity(0.2) : Color.green.opacity(0.2)))
                            .foregroundColor(profile.lagRisk.contains("High") ? .red : (profile.lagRisk.contains("Medium") ? .orange : .green))
                            .clipShape(Capsule())
                    }
                    Text(profile.aiOptimizedSettings)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
    }
}

struct GameMetricPill: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(valueColor)
            }
        }
    }
}

// Helper extension to parse hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
