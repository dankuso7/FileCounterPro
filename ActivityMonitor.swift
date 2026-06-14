import SwiftUI

// MARK: - Data Model

struct SystemProcess: Identifiable, Equatable {
    let id: Int   // PID
    let name: String
    let cpu: Double
    let memory: Double
    let fullPath: String
}

// MARK: - Gauge

struct GaugeView: View {
    let title: String
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: 10)
                Circle()
                    .trim(from: 0.0, to: min(percentage / 100.0, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: percentage)
                    .shadow(color: color.opacity(0.6), radius: 8)
                Text("\(Int(percentage))%")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            .frame(width: 65, height: 65)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(SciFi.textDim)
        }
        .padding()
        .background(SciFi.bgCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
        .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
        .drawingGroup()
    }
}

// MARK: - View State (class wrapper to avoid @State macro requirement)

final class ActivityMonitorState: ObservableObject {
    @Published var selectedProcessForAI: SystemProcess? = nil
    @Published var showHardwareAnalyzer: Bool = false
    @Published var showGameAdvisor: Bool = false
    @Published var showGPUComparison: Bool = false
}

// MARK: - Main View

struct ActivityMonitorView: View {
    @StateObject private var tracker = ActivityTracker()
    @StateObject private var viewState = ActivityMonitorState()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADVANCED ACTIVITY MONITOR")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Live hardware usage and AI process analysis")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(SciFi.textDim)
                }
                Spacer()

                Button {
                    viewState.showGameAdvisor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(SciFi.neonOrange)
                        Text("Game Advisor")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(SciFi.bgCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SciFi.neonOrange.opacity(0.3), lineWidth: 1))
                    .shadow(color: SciFi.neonOrange.opacity(0.2), radius: 6)
                }
                .buttonStyle(.plain)

                Button {
                    viewState.showHardwareAnalyzer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(SciFi.neonMagenta)
                        Text("Analyze Mac Health")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(SciFi.bgCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SciFi.neonMagenta.opacity(0.3), lineWidth: 1))
                    .shadow(color: SciFi.neonMagenta.opacity(0.2), radius: 6)
                }
                .buttonStyle(.plain)

                LivePill()
                    .padding(.leading, 12)
            }
            .padding()
            .background(SciFi.bgPanel)

            Rectangle().fill(SciFi.border).frame(height: 1)

            // 5-Gauge Dashboard
            HStack(spacing: 15) {
                Spacer()
                GaugeView(title: "CPU", percentage: tracker.totalCPU, color: .blue)
                GaugeView(title: "GPU", percentage: tracker.totalGPU, color: .purple)
                GaugeView(title: "RAM", percentage: tracker.totalRAM, color: .orange)
                GaugeView(title: "Pressure",
                          percentage: tracker.memoryPressure,
                          color: tracker.memoryPressure > 50 ? .red : .yellow)
                GaugeView(title: "Health",
                          percentage: tracker.systemHealth,
                          color: tracker.systemHealth < 80 ? .red : .green)
                Spacer()
            }
            .padding(.vertical, 15)
            // RAM Speed Comparison
            RAMSpeedWidget(currentBandwidth: tracker.ramBandwidthGBs)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
            // GPU Leaderboard Button
            Button {
                viewState.showGPUComparison = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(SciFi.neonCyan)
                    Text("Compare M4 GPU vs AMD & NVIDIA")
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "list.bullet")
                        .foregroundColor(SciFi.textDim)
                }
                .padding(16)
                .background(SciFi.bgCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SciFi.neonCyan.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Rectangle().fill(SciFi.border).frame(height: 1)

            // Column Header
            HStack {
                Text("PROCESS NAME").frame(maxWidth: .infinity, alignment: .leading)
                Text("PID").frame(width: 80, alignment: .leading)
                Text("% CPU").frame(width: 80, alignment: .trailing)
                Text("MEM (MB)").frame(width: 80, alignment: .trailing)
                Spacer()
                Text("AI ANALYSIS")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(SciFi.neonCyan)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(SciFi.bgCard)

            Rectangle().fill(SciFi.border).frame(height: 1)

            // Process List
            List {
                ForEach(tracker.processes) { process in
                    ProcessRow(process: process) {
                        viewState.selectedProcessForAI = process
                    }
                    .listRowBackground(SciFi.bgRow)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SciFi.bgDeep)
        }
        .background(SciFi.bgDeep)
        .popover(item: Binding(
            get: { viewState.selectedProcessForAI },
            set: { viewState.selectedProcessForAI = $0 }
        )) { (process: SystemProcess) in
            AIAnalysisPopover(process: process)
        }
        .sheet(isPresented: Binding(
            get: { viewState.showHardwareAnalyzer },
            set: { viewState.showHardwareAnalyzer = $0 }
        )) {
            HardwareAnalyzerView()
        }
        .sheet(isPresented: Binding(
            get: { viewState.showGameAdvisor },
            set: { viewState.showGameAdvisor = $0 }
        )) {
            GameAdvisorView()
        }
        .sheet(isPresented: Binding(
            get: { viewState.showGPUComparison },
            set: { viewState.showGPUComparison = $0 }
        )) {
            GPUComparisonView(gpuPercent: tracker.totalGPU)
        }
    }
}

// MARK: - Sub-components

struct LivePill: View {
    @StateObject private var pillState = LivePillState()

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(SciFi.neonGreen)
                .frame(width: 8, height: 8)
                .shadow(color: SciFi.neonGreen.opacity(0.6), radius: 4)
                .scaleEffect(pillState.pulse ? 1.25 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pillState.pulse)
                .onAppear { pillState.pulse = true }
            Text("LIVE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(SciFi.neonGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SciFi.neonGreen.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(SciFi.neonGreen.opacity(0.3), lineWidth: 1))
        .shadow(color: SciFi.neonGreen.opacity(0.2), radius: 4)
    }
}

final class LivePillState: ObservableObject {
    @Published var pulse: Bool = false
}

struct ProcessRow: View {
    let process: SystemProcess
    let onAI: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .foregroundColor(process.cpu > 50.0 ? SciFi.neonMagenta : SciFi.neonCyan)
                    .shadow(color: (process.cpu > 50.0 ? SciFi.neonMagenta : SciFi.neonCyan).opacity(0.5), radius: 3)
                Text(process.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(process.cpu > 20.0 ? .semibold : .regular)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.id)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(SciFi.textDim)
                .frame(width: 80, alignment: .leading)

            Text(String(format: "%.1f", process.cpu))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(process.cpu > 50.0 ? SciFi.neonMagenta : .white)
                .frame(width: 80, alignment: .trailing)

            Text(String(format: "%.1f", process.memory))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .trailing)

            Spacer()

            Button(action: onAI) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("AI Pro")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LinearGradient(colors: [SciFi.neonPurple, SciFi.neonCyan],
                                           startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: SciFi.neonPurple.opacity(0.4), radius: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AIAnalysisPopover: View {
    let process: SystemProcess

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundColor(SciFi.neonPurple)
                Text("AI PROCESS ANALYSIS").font(.system(.headline, design: .monospaced)).foregroundColor(SciFi.neonPurple)
            }
            Text("Process: \(process.name) (PID: \(process.id))")
                .font(.system(.subheadline, design: .monospaced)).fontWeight(.medium).foregroundColor(SciFi.textDim)
            Divider().background(SciFi.border)
            Text(LocalizedStringKey(analyzeProcess(process)))
                .font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true).foregroundColor(.white)
        }
        .padding(20)
        .frame(width: 350)
        .background(SciFi.bgPanel)
    }

    private func analyzeProcess(_ p: SystemProcess) -> String {
        let n = p.name.lowercased()
        switch true {
        case n.contains("windowserver"):
            return "CRITICAL SYSTEM PROCESS.\nWindowServer draws all UI. High CPU = heavy 4K monitors or buggy app. **DO NOT QUIT** (will log you out)."
        case n.contains("mds") || n.contains("mdworker"):
            return "SYSTEM (Spotlight).\nIndexing your files. Safe — let it finish."
        case n.contains("kernel_task"):
            return "CRITICAL: kernel_task throttles other apps when the M4 chip overheats. If high, check airflow."
        case n.contains("chrome"):
            return "Chrome: multi-process, memory-heavy. Safe to Force Quit. Safari has better Apple Silicon efficiency."
        case n.contains("filecounter"):
            return "THIS APP — File Counter Pro is scanning or analyzing. Highly optimized."
        case n.contains("helper") || n.contains("xpc"):
            return "Background helper — networking, updates, IPC. Safe unless stuck."
        default:
            return p.cpu > 50.0 ? "Heavy CPU usage detected. Likely rendering, compiling, or gaming. Force Quit if frozen." : "Background task. Looks normal."
        }
    }
}

// MARK: - RAM Speed Widget
struct RAMSpeedWidget: View {
    let currentBandwidth: Double
    
    // Theoretical maxes
    let pcDDR5Max = 64.0 // Standard PC DDR5 ~64 GB/s
    let m4Max = 120.0 // M4 LPDDR5X ~120 GB/s
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(SciFi.neonPurple)
                    .shadow(color: SciFi.neonPurple.opacity(0.5), radius: 4)
                Text("LIVE MEMORY BANDWIDTH vs PC DDR5")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.textDim)
                
                Spacer()
                
                Text(String(format: "%.1f GB/s", currentBandwidth))
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundColor(SciFi.neonPurple)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: currentBandwidth)
            }
            
            // PC Bar
            HStack {
                Text("Standard PC (DDR5)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(SciFi.textDim)
                    .frame(width: 120, alignment: .leading)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        
                        Capsule()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(pcDDR5Max / m4Max))
                    }
                }
                .frame(height: 6)
                
                Text("~64 GB/s")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(SciFi.textDim)
                    .frame(width: 50, alignment: .trailing)
            }
            
            // M4 Bar
            HStack {
                Text("M4 Mac (LPDDR5X)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 120, alignment: .leading)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        
                        // Max capacity bar
                        Capsule()
                            .fill(SciFi.neonPurple.opacity(0.2))
                        
                        Capsule()
                            .fill(LinearGradient(colors: [SciFi.neonCyan, SciFi.neonPurple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(currentBandwidth, m4Max) / m4Max))
                            .animation(.easeOut(duration: 0.3), value: currentBandwidth)
                            .shadow(color: SciFi.neonPurple.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 8)
                .drawingGroup()
                
                Text("~120 GB/s")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonPurple)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(12)
        .background(SciFi.bgCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SciFi.neonPurple.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - GPU Comparison View
struct GPUModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let tflops: Double
    let vendor: String
    let color: Color
    let gamingTier: String
    let estimatedWatts: Double
    
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: GPUModel, rhs: GPUModel) -> Bool {
        lhs.id == rhs.id
    }
}

final class GPUComparisonViewState: ObservableObject {
    @Published var searchText = ""
    @Published var selectedGPUs: Set<GPUModel> = []
    @Published var showSideBySide = false
}

struct GPUComparisonView: View {
    let gpuPercent: Double
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewState = GPUComparisonViewState()
    
    let m4Max = 4.6 // M4 10-core GPU
    
    var liveM4Tflops: Double {
        return (gpuPercent / 100.0) * m4Max
    }
    
    // Comprehensive list of popular GPUs and gaming tiers
    let gpus: [GPUModel] = [
        // Apple Silicon
        GPUModel(name: "Apple M4 Max (40-Core)", tflops: 34.0, vendor: "Apple", color: .gray, gamingTier: "4K High / 90Hz", estimatedWatts: 60),
        GPUModel(name: "Apple M3 Max (40-Core)", tflops: 28.6, vendor: "Apple", color: .gray, gamingTier: "1440p High / 90Hz", estimatedWatts: 45),
        GPUModel(name: "Apple M2 Ultra (76-Core)", tflops: 27.2, vendor: "Apple", color: .gray, gamingTier: "4K Med / 60Hz", estimatedWatts: 60),
        GPUModel(name: "Apple M1 Ultra (64-Core)", tflops: 21.0, vendor: "Apple", color: .gray, gamingTier: "1440p High / 60Hz", estimatedWatts: 60),
        GPUModel(name: "Apple M4 Pro (20-Core)", tflops: 17.0, vendor: "Apple", color: .gray, gamingTier: "1440p High / 60Hz", estimatedWatts: 40),
        GPUModel(name: "Apple M2 Max (38-Core)", tflops: 13.6, vendor: "Apple", color: .gray, gamingTier: "1440p Med / 60Hz", estimatedWatts: 35),
        GPUModel(name: "Apple M3 Pro (18-Core)", tflops: 12.9, vendor: "Apple", color: .gray, gamingTier: "1080p High / 75Hz", estimatedWatts: 32),
        GPUModel(name: "Apple M1 Max (32-Core)", tflops: 10.4, vendor: "Apple", color: .gray, gamingTier: "1080p High / 60Hz", estimatedWatts: 30),
        GPUModel(name: "Apple M3 Pro (14-Core)", tflops: 6.8, vendor: "Apple", color: .gray, gamingTier: "1080p Med / 50Hz", estimatedWatts: 28),
        GPUModel(name: "Apple M2 Pro (19-Core)", tflops: 6.8, vendor: "Apple", color: .gray, gamingTier: "1080p Med / 60Hz", estimatedWatts: 30),
        GPUModel(name: "Apple M1 Pro (16-Core)", tflops: 5.2, vendor: "Apple", color: .gray, gamingTier: "1080p Med / 45Hz", estimatedWatts: 25),
        GPUModel(name: "Apple M4 (10-Core)", tflops: 4.6, vendor: "Apple", color: .mint, gamingTier: "1080p Low-Med / 60Hz", estimatedWatts: 18),
        GPUModel(name: "Apple M3 (10-Core)", tflops: 4.1, vendor: "Apple", color: .gray, gamingTier: "1080p Low / 60Hz", estimatedWatts: 15),
        GPUModel(name: "Apple M2 (10-Core)", tflops: 3.6, vendor: "Apple", color: .gray, gamingTier: "1080p Low / 45Hz", estimatedWatts: 15),
        GPUModel(name: "Apple M1 (8-Core)", tflops: 2.6, vendor: "Apple", color: .gray, gamingTier: "720p Med / 60Hz", estimatedWatts: 15),
        
        // NVIDIA RTX 40-Series
        GPUModel(name: "NVIDIA RTX 4090", tflops: 82.6, vendor: "NVIDIA", color: .green, gamingTier: "4K+ Ultra / 144Hz", estimatedWatts: 450),
        GPUModel(name: "NVIDIA RTX 4080 Super", tflops: 52.2, vendor: "NVIDIA", color: .green, gamingTier: "4K Ultra / 120Hz", estimatedWatts: 320),
        GPUModel(name: "NVIDIA RTX 4080", tflops: 48.7, vendor: "NVIDIA", color: .green, gamingTier: "4K Ultra / 100Hz", estimatedWatts: 320),
        GPUModel(name: "NVIDIA RTX 4070 Ti Super", tflops: 44.1, vendor: "NVIDIA", color: .green, gamingTier: "4K High / 100Hz", estimatedWatts: 285),
        GPUModel(name: "NVIDIA RTX 4070 Ti", tflops: 40.1, vendor: "NVIDIA", color: .green, gamingTier: "1440p Ultra / 120Hz", estimatedWatts: 285),
        GPUModel(name: "NVIDIA RTX 4070 Super", tflops: 35.5, vendor: "NVIDIA", color: .green, gamingTier: "1440p Ultra / 100Hz", estimatedWatts: 220),
        GPUModel(name: "NVIDIA RTX 4070", tflops: 29.1, vendor: "NVIDIA", color: .green, gamingTier: "1440p High / 100Hz", estimatedWatts: 200),
        GPUModel(name: "NVIDIA RTX 4060 Ti", tflops: 22.1, vendor: "NVIDIA", color: .green, gamingTier: "1080p Ultra / 120Hz", estimatedWatts: 160),
        GPUModel(name: "NVIDIA RTX 4060", tflops: 15.1, vendor: "NVIDIA", color: .green, gamingTier: "1080p High / 80Hz", estimatedWatts: 115),
        
        // NVIDIA RTX 30-Series
        GPUModel(name: "NVIDIA RTX 3090 Ti", tflops: 40.0, vendor: "NVIDIA", color: .green, gamingTier: "4K Ultra / 90Hz", estimatedWatts: 450),
        GPUModel(name: "NVIDIA RTX 3090", tflops: 35.6, vendor: "NVIDIA", color: .green, gamingTier: "4K High / 80Hz", estimatedWatts: 350),
        GPUModel(name: "NVIDIA RTX 3080 Ti", tflops: 34.1, vendor: "NVIDIA", color: .green, gamingTier: "4K High / 70Hz", estimatedWatts: 350),
        GPUModel(name: "NVIDIA RTX 3080", tflops: 29.8, vendor: "NVIDIA", color: .green, gamingTier: "1440p High / 100Hz", estimatedWatts: 320),
        GPUModel(name: "NVIDIA RTX 3070 Ti", tflops: 21.7, vendor: "NVIDIA", color: .green, gamingTier: "1440p High / 90Hz", estimatedWatts: 290),
        GPUModel(name: "NVIDIA RTX 3070", tflops: 20.3, vendor: "NVIDIA", color: .green, gamingTier: "1440p Med / 90Hz", estimatedWatts: 220),
        GPUModel(name: "NVIDIA RTX 3060 Ti", tflops: 16.2, vendor: "NVIDIA", color: .green, gamingTier: "1080p High / 90Hz", estimatedWatts: 200),
        GPUModel(name: "NVIDIA RTX 3060", tflops: 12.7, vendor: "NVIDIA", color: .green, gamingTier: "1080p Med / 80Hz", estimatedWatts: 170),
        GPUModel(name: "NVIDIA RTX 3050", tflops: 9.1, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 60Hz", estimatedWatts: 130),
        
        // NVIDIA RTX 20-Series & GTX
        GPUModel(name: "NVIDIA RTX 2080 Ti", tflops: 13.4, vendor: "NVIDIA", color: .green, gamingTier: "1440p Med / 60Hz", estimatedWatts: 250),
        GPUModel(name: "NVIDIA RTX 2080 Super", tflops: 11.1, vendor: "NVIDIA", color: .green, gamingTier: "1080p High / 70Hz", estimatedWatts: 250),
        GPUModel(name: "NVIDIA RTX 2070 Super", tflops: 9.1, vendor: "NVIDIA", color: .green, gamingTier: "1080p Med / 80Hz", estimatedWatts: 215),
        GPUModel(name: "NVIDIA RTX 2060", tflops: 6.5, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 60Hz", estimatedWatts: 160),
        GPUModel(name: "NVIDIA GTX 1080 Ti", tflops: 11.3, vendor: "NVIDIA", color: .green, gamingTier: "1080p Med / 60Hz", estimatedWatts: 250),
        GPUModel(name: "NVIDIA GTX 1080", tflops: 8.9, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 60Hz", estimatedWatts: 180),
        GPUModel(name: "NVIDIA GTX 1070", tflops: 6.5, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 45Hz", estimatedWatts: 150),
        GPUModel(name: "NVIDIA GTX 1060 (6GB)", tflops: 4.4, vendor: "NVIDIA", color: .green, gamingTier: "720p High / 60Hz", estimatedWatts: 120),
        GPUModel(name: "NVIDIA GTX 1660 Ti", tflops: 5.4, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 50Hz", estimatedWatts: 120),
        GPUModel(name: "NVIDIA GTX 1650", tflops: 2.9, vendor: "NVIDIA", color: .green, gamingTier: "1080p Low / 45Hz", estimatedWatts: 75),
        
        // AMD Radeon RX 7000 Series
        GPUModel(name: "AMD Radeon RX 7900 XTX", tflops: 61.4, vendor: "AMD", color: .red, gamingTier: "4K Ultra / 120Hz", estimatedWatts: 355),
        GPUModel(name: "AMD Radeon RX 7900 XT", tflops: 51.6, vendor: "AMD", color: .red, gamingTier: "4K Ultra / 90Hz", estimatedWatts: 300),
        GPUModel(name: "AMD Radeon RX 7900 GRE", tflops: 46.0, vendor: "AMD", color: .red, gamingTier: "1440p Ultra / 120Hz", estimatedWatts: 260),
        GPUModel(name: "AMD Radeon RX 7800 XT", tflops: 37.3, vendor: "AMD", color: .red, gamingTier: "1440p Ultra / 100Hz", estimatedWatts: 263),
        GPUModel(name: "AMD Radeon RX 7700 XT", tflops: 35.2, vendor: "AMD", color: .red, gamingTier: "1440p High / 100Hz", estimatedWatts: 245),
        GPUModel(name: "AMD Radeon RX 7600 XT", tflops: 22.6, vendor: "AMD", color: .red, gamingTier: "1080p Ultra / 90Hz", estimatedWatts: 190),
        GPUModel(name: "AMD Radeon RX 7600", tflops: 21.7, vendor: "AMD", color: .red, gamingTier: "1080p High / 100Hz", estimatedWatts: 165),
        
        // AMD Radeon RX 6000 Series
        GPUModel(name: "AMD Radeon RX 6950 XT", tflops: 23.8, vendor: "AMD", color: .red, gamingTier: "4K High / 80Hz", estimatedWatts: 335),
        GPUModel(name: "AMD Radeon RX 6900 XT", tflops: 23.0, vendor: "AMD", color: .red, gamingTier: "4K Med / 70Hz", estimatedWatts: 300),
        GPUModel(name: "AMD Radeon RX 6800 XT", tflops: 20.7, vendor: "AMD", color: .red, gamingTier: "1440p High / 80Hz", estimatedWatts: 300),
        GPUModel(name: "AMD Radeon RX 6800", tflops: 16.2, vendor: "AMD", color: .red, gamingTier: "1440p Med / 70Hz", estimatedWatts: 250),
        GPUModel(name: "AMD Radeon RX 6750 XT", tflops: 13.3, vendor: "AMD", color: .red, gamingTier: "1080p Ultra / 100Hz", estimatedWatts: 250),
        GPUModel(name: "AMD Radeon RX 6700 XT", tflops: 13.2, vendor: "AMD", color: .red, gamingTier: "1080p Ultra / 90Hz", estimatedWatts: 230),
        GPUModel(name: "AMD Radeon RX 6650 XT", tflops: 10.8, vendor: "AMD", color: .red, gamingTier: "1080p High / 80Hz", estimatedWatts: 176),
        GPUModel(name: "AMD Radeon RX 6600 XT", tflops: 10.6, vendor: "AMD", color: .red, gamingTier: "1080p High / 70Hz", estimatedWatts: 160),
        GPUModel(name: "AMD Radeon RX 6600", tflops: 8.9, vendor: "AMD", color: .red, gamingTier: "1080p Med / 60Hz", estimatedWatts: 132),
        GPUModel(name: "AMD Radeon RX 6500 XT", tflops: 5.7, vendor: "AMD", color: .red, gamingTier: "1080p Low / 45Hz", estimatedWatts: 107),
        
        // AMD Radeon RX 5000 Series & Legacy
        GPUModel(name: "AMD Radeon RX 5700 XT", tflops: 9.8, vendor: "AMD", color: .red, gamingTier: "1080p High / 60Hz", estimatedWatts: 225),
        GPUModel(name: "AMD Radeon RX 5700", tflops: 7.9, vendor: "AMD", color: .red, gamingTier: "1080p Med / 60Hz", estimatedWatts: 180),
        GPUModel(name: "AMD Radeon RX 5600 XT", tflops: 7.2, vendor: "AMD", color: .red, gamingTier: "1080p Med / 50Hz", estimatedWatts: 150),
        GPUModel(name: "AMD Radeon RX 580", tflops: 6.2, vendor: "AMD", color: .red, gamingTier: "1080p Low / 45Hz", estimatedWatts: 185),
        GPUModel(name: "AMD Radeon RX 570", tflops: 5.1, vendor: "AMD", color: .red, gamingTier: "720p High / 60Hz", estimatedWatts: 150),
        GPUModel(name: "AMD Radeon Vega 64", tflops: 12.6, vendor: "AMD", color: .red, gamingTier: "1080p Med / 60Hz", estimatedWatts: 295),
        
        // Intel Arc
        GPUModel(name: "Intel Arc A770", tflops: 19.6, vendor: "Intel", color: .blue, gamingTier: "1080p Ultra / 80Hz", estimatedWatts: 225),
        GPUModel(name: "Intel Arc A750", tflops: 17.2, vendor: "Intel", color: .blue, gamingTier: "1080p High / 70Hz", estimatedWatts: 225),
        GPUModel(name: "Intel Arc A580", tflops: 12.7, vendor: "Intel", color: .blue, gamingTier: "1080p Med / 60Hz", estimatedWatts: 185),
        GPUModel(name: "Intel Arc A380", tflops: 4.1, vendor: "Intel", color: .blue, gamingTier: "1080p Low / 45Hz", estimatedWatts: 75),
        GPUModel(name: "Intel UHD 770", tflops: 0.8, vendor: "Intel", color: .blue, gamingTier: "720p Low / 30Hz", estimatedWatts: 15),
        
        // Consoles / Handhelds
        GPUModel(name: "PS5 GPU", tflops: 10.3, vendor: "AMD", color: .purple, gamingTier: "4K Console Target", estimatedWatts: 180),
        GPUModel(name: "Xbox Series X", tflops: 12.1, vendor: "AMD", color: .green, gamingTier: "4K Console Target", estimatedWatts: 200),
        GPUModel(name: "Xbox Series S", tflops: 4.0, vendor: "AMD", color: .green, gamingTier: "1440p Console Target", estimatedWatts: 74),
        GPUModel(name: "Steam Deck (RDNA 2)", tflops: 1.6, vendor: "AMD", color: .red, gamingTier: "800p Low-Med / 45Hz", estimatedWatts: 15),
        GPUModel(name: "ASUS ROG Ally (Z1 Ext)", tflops: 8.6, vendor: "AMD", color: .red, gamingTier: "1080p Low / 60Hz", estimatedWatts: 30),
        GPUModel(name: "Nintendo Switch", tflops: 0.4, vendor: "NVIDIA", color: .green, gamingTier: "720p Console Target", estimatedWatts: 8)
    ].sorted { $0.tflops > $1.tflops }
    
    var filteredGPUs: [GPUModel] {
        if viewState.searchText.isEmpty {
            return gpus
        } else {
            return gpus.filter { $0.name.localizedCaseInsensitiveContains(viewState.searchText) || $0.vendor.localizedCaseInsensitiveContains(viewState.searchText) }
        }
    }
    
    var maxTflops: Double {
        gpus.first?.tflops ?? 100.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ULTIMATE GPU POWER LEADERBOARD")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(.white)
                    Text("Comparing FP32 Compute & Estimated Gaming Performance")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(SciFi.textDim)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(SciFi.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(SciFi.bgPanel)
            
            // List Header
            HStack {
                Text("MODEL & GAMING TIER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonCyan)
                    .frame(width: 250, alignment: .leading)
                    .padding(.leading, 36)
                
                Spacer()
                
                Text("TFLOPS COMPUTE POWER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonCyan)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(SciFi.bgCard)
            
            Rectangle().fill(SciFi.border).frame(height: 1)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredGPUs) { gpu in
                        HStack {
                            // Checkbox for selection
                            Button {
                                if viewState.selectedGPUs.contains(gpu) {
                                    viewState.selectedGPUs.remove(gpu)
                                } else {
                                    if viewState.selectedGPUs.count < 4 { // Max 4 for side-by-side
                                        viewState.selectedGPUs.insert(gpu)
                                    }
                                }
                            } label: {
                                Image(systemName: viewState.selectedGPUs.contains(gpu) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(viewState.selectedGPUs.contains(gpu) ? .blue : .secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(gpu.name)
                                    .font(.headline)
                                    .foregroundColor(gpu.name == "Apple M4 (10-Core)" ? SciFi.neonCyan : .white)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 10))
                                    Text(gpu.gamingTier)
                                        .font(.caption)
                                }
                                .foregroundColor(SciFi.textDim)
                            }
                            .frame(width: 200, alignment: .leading)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                    
                                    if gpu.name == "Apple M4 (10-Core)" {
                                        // Max Capacity Bar
                                        Capsule()
                                            .fill(gpu.color.opacity(0.3))
                                            .frame(width: geo.size.width * CGFloat(gpu.tflops / maxTflops))
                                        
                                        // Live Usage Overlay
                                        Capsule()
                                            .fill(LinearGradient(colors: [SciFi.neonCyan, SciFi.neonPurple], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: max(0, geo.size.width * CGFloat(liveM4Tflops / maxTflops)))
                                            .animation(.easeOut(duration: 0.3), value: liveM4Tflops)
                                            .shadow(color: SciFi.neonCyan.opacity(0.5), radius: 4)
                                    } else {
                                        Capsule()
                                            .fill(gpu.color)
                                            .frame(width: geo.size.width * CGFloat(gpu.tflops / maxTflops))
                                    }
                                }
                            }
                            .frame(height: 12)
                            
                            Text(String(format: "%.1f TF", gpu.tflops))
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundColor(gpu.name == "Apple M4 (10-Core)" ? SciFi.neonCyan : gpu.color)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(12)
                        .background(gpu.name == "Apple M4 (10-Core)" ? SciFi.neonCyan.opacity(0.08) : SciFi.bgCard)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(gpu.name == "Apple M4 (10-Core)" ? SciFi.neonCyan.opacity(0.3) : SciFi.border, lineWidth: 1))
                        
                        if gpu.name == "Apple M4 (10-Core)" {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text("Live Compute Usage: ")
                                    .font(.caption.bold())
                                Text("\(String(format: "%.1f", liveM4Tflops)) TFLOPS currently active")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .animation(.none, value: liveM4Tflops)
                        }
                    }
                }
                .padding(20)
            }
            .searchable(text: Binding(get: { viewState.searchText }, set: { viewState.searchText = $0 }), prompt: "Search by GPU name or vendor...")
            
            // Floating Action Bar for Comparison
            if !viewState.selectedGPUs.isEmpty {
                VStack {
                    Divider()
                    HStack {
                        Text("\(viewState.selectedGPUs.count) selected")
                            .font(.headline)
                        if viewState.selectedGPUs.count == 4 {
                            Text("(Max allowed)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewState.showSideBySide = true
                        } label: {
                            HStack {
                                Image(systemName: "square.split.2x1")
                                Text("Compare Side-by-Side")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewState.selectedGPUs.count > 1 ? Color.blue : Color.gray.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewState.selectedGPUs.count < 2)
                        .help(viewState.selectedGPUs.count < 2 ? "Select at least 2 GPUs to compare" : "Launch comparison view")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .transition(.move(edge: .bottom))
            }
        }
        .frame(width: 750, height: 750)
        .background(SciFi.bgDeep)
        .sheet(isPresented: Binding(get: { viewState.showSideBySide }, set: { viewState.showSideBySide = $0 })) {
            GPUSideBySideView(selectedGPUs: Array(viewState.selectedGPUs).sorted { $0.tflops > $1.tflops })
        }
    }
}
