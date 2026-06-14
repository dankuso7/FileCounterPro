import SwiftUI
import AppKit

// MARK: - Live Power Monitor
// Responds to:
//   • Mac wake from sleep   → NSWorkspace.didWakeNotification
//   • Power mode change     → NSProcessInfo.processInfoDidChangeNotification
//   • Screen wake           → NSWorkspace.screensDidWakeNotification
//   • Periodic poll         → every 3 s via Swift structured concurrency

@MainActor
class LivePowerMonitor: ObservableObject {

    // ── Realtime published state ────────────────────────────────────────────
    @Published var totalWatts: Double        = 0
    @Published var cpuWatts: Double          = 0
    @Published var gpuWatts: Double          = 0
    @Published var ramWatts: Double          = 0
    @Published var ssdWatts: Double          = 0
    @Published var netWatts: Double          = 0
    @Published var cpuPercent: Double        = 0
    @Published var efficiencyRating: String  = "—"
    @Published var powerMode: String         = "Normal"
    @Published var kWhToday: Double          = 0
    @Published var co2Today: Double          = 0
    @Published var topConsumers: [PowerConsumerProcess] = []

    // ── Wake / sleep event state ────────────────────────────────────────────
    @Published var lastWakeTime: Date?        = nil
    @Published var wakeEventBanner: String?   = nil   // transient banner message
    @Published var isPostWake: Bool           = false  // true for 30s after wake

    // ── Hardware constants (M4 Mac mini) ───────────────────────────────────
    private let idleWatts:   Double = 7.0
    private let maxTDPWatts: Double = 22.0

    private var pollTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        registerSystemObservers()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
        bannerTask?.cancel()
        // Observers are removed in deinit — safe because NSWorkspace holds weak refs
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - System Event Registration

    private func registerSystemObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        let dnc = NotificationCenter.default

        // Mac woke from sleep
        let wakeObs = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleWake(reason: "Mac woke from sleep")
            }
        }

        // Screen came back on (display sleep / lid open)
        let screenObs = nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleWake(reason: "Display woke from sleep")
            }
        }

        // Power / Low Power Mode toggle
        let powerObs = dnc.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handlePowerModeChange()
            }
        }

        observers = [wakeObs, screenObs, powerObs]
    }

    // MARK: - Event Handlers

    private func handleWake(reason: String) async {
        lastWakeTime = Date()
        isPostWake = true
        wakeEventBanner = "⚡ \(reason) — refreshing power data"
        // Immediately take a fresh power sample
        await samplePower()
        // Clear post-wake flag after 30s
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            self.wakeEventBanner = nil
            try? await Task.sleep(for: .seconds(25))
            self.isPostWake = false
        }
    }

    private func handlePowerModeChange() async {
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let newMode = isLowPower ? "Low Power Mode" : "Normal"
        if newMode != powerMode {
            powerMode = newMode
            wakeEventBanner = isLowPower
                ? "🟢 Low Power Mode activated — recalculating wattage"
                : "⚡ Normal performance mode — recalculating wattage"
            await samplePower()
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(for: .seconds(5))
                self.wakeEventBanner = nil
            }
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await samplePower()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: - Core Power Sample

    func samplePower() async {
        // Run probes concurrently
        async let cpuRaw  = shellString("top -l 2 -s 1 -n 0 2>/dev/null")
        async let topProc = shellString("top -l 2 -s 1 -o power -n 25 2>/dev/null")
        async let pmRaw   = shellString("pmset -g 2>/dev/null")

        let (cpuOut, procOut, pmOut) = await (cpuRaw, topProc, pmRaw)

        // ── CPU % ───────────────────────────────────────────────────────────
        var cpuUser = 0.0; var cpuSys = 0.0
        for line in cpuOut.split(separator: "\n") {
            let s = String(line)
            if s.contains("CPU usage:") {
                if let u = matchDouble(s, pat: "([\\d.]+)% user") { cpuUser = u }
                if let y = matchDouble(s, pat: "([\\d.]+)% sys")  { cpuSys  = y }
            }
        }
        let cpuLoad = min(cpuUser + cpuSys, 100.0)

        // ── Parse top POWER column from second sample ───────────────────────
        var wsScore    = 0.0  // WindowServer (GPU proxy)
        var anedScore  = 0.0  // ANE (Neural Engine)
        var consumers: [PowerConsumerProcess] = []

        let lines = procOut.split(separator: "\n").map { String($0) }
        var sampleCount = 0; var headerSeen = false
        for line in lines {
            if line.hasPrefix("Processes:") { sampleCount += 1; if sampleCount == 2 { headerSeen = false } }
            if sampleCount < 2 { continue }
            if line.contains("PID") && line.contains("POWER") { headerSeen = true; continue }
            guard headerSeen else { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 22 else { continue }
            let pid  = Int(parts[0]) ?? 0
            let name = String(parts[1])
            let pw   = Double(parts[20]) ?? 0.0
            if name.lowercased().contains("windowserver") { wsScore   = pw }
            if name.lowercased().contains("aned")         { anedScore = pw }
            if pw > 0.5 { consumers.append(PowerConsumerProcess(name: name, pid: pid, powerScore: pw)) }
        }

        // ── Wattage from known M4 Mac mini TDP ─────────────────────────────
        let cpuFrac = cpuLoad / 100.0
        let cpuW    = 3.0 + cpuFrac * 13.0
        let gpuW    = max(1.0, min(wsScore / 20.0, 3.5) + min(anedScore / 20.0, 1.0))
        let ramW    = 0.8 + cpuFrac * 0.8   // LPDDR5X scales with activity
        let ssdW    = 0.3 + cpuFrac * 0.3
        let netW    = 0.2 + cpuFrac * 0.15
        let boardW  = 1.2                    // board + USB standby

        var total = cpuW + gpuW + ramW + ssdW + netW + boardW

        // Low Power Mode lowers TDP ceiling to ~15W
        let isLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
        let ceiling = isLPM ? 15.0 : maxTDPWatts
        total = max(idleWatts, min(total, ceiling))

        // Efficiency rating
        let utilPct = total / maxTDPWatts
        let rating = utilPct < 0.35 ? "🟢 Excellent"
                   : utilPct < 0.65 ? "🟡 Good"
                   : utilPct < 0.85 ? "🟠 High"
                   :                  "🔴 Near Max"

        // Power mode
        let mode = isLPM ? "Low Power Mode" : "Normal"

        // Power-up check (from pmset)
        let _ = pmOut  // retained for future pmset parsing

        // CO₂ / kWh (16h active day assumption)
        let kWh = total * 16.0 / 1000.0
        let co2 = kWh * 386.0  // US grid average gCO₂/kWh

        // ── Publish ─────────────────────────────────────────────────────────
        self.cpuPercent       = cpuLoad
        self.cpuWatts         = cpuW
        self.gpuWatts         = gpuW
        self.ramWatts         = ramW
        self.ssdWatts         = ssdW
        self.netWatts         = netW
        self.totalWatts       = total
        self.efficiencyRating = rating
        self.powerMode        = mode
        self.kWhToday         = kWh
        self.co2Today         = co2
        self.topConsumers     = Array(consumers.sorted { $0.powerScore > $1.powerScore }.prefix(8))
    }

    // ── Regex helper ─────────────────────────────────────────────────────────
    private func matchDouble(_ text: String, pat: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pat),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[r])
    }
}

// MARK: - Live Power Dashboard View
// Standalone view that embeds inside HardwareAnalyzerView
// Automatically refreshes on wake and power mode change.

struct LivePowerDashboardView: View {
    @StateObject private var monitor = LivePowerMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ─────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Power Monitor")
                        .font(.headline)
                    Text("Updates every 3 s · Responds to sleep/wake & power mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Power Mode badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.powerMode == "Low Power Mode" ? Color.green : Color.blue)
                        .frame(width: 7, height: 7)
                    Text(monitor.powerMode)
                        .font(.caption.bold())
                        .foregroundColor(monitor.powerMode == "Low Power Mode" ? .green : .blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(monitor.powerMode == "Low Power Mode" ? Color.green.opacity(0.12) : Color.blue.opacity(0.08))
                .clipShape(Capsule())
            }

            // ── Wake / Mode-Change Banner ──────────────────────────────────
            if let banner = monitor.wakeEventBanner {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text(banner)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .transition(.asymmetric(insertion: .push(from: .top), removal: .opacity))
                .animation(.easeOut(duration: 0.3), value: monitor.wakeEventBanner)
            }

            // ── Total Wattage Row ──────────────────────────────────────────
            HStack(alignment: .center, spacing: 24) {

                // Big watt number
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", monitor.totalWatts))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(totalColor(monitor.totalWatts))
                            .animation(.easeOut(duration: 0.3), value: monitor.totalWatts)
                        Text("W")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    Text("Total system draw")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider().frame(height: 60)

                // Efficiency + CO₂
                VStack(alignment: .leading, spacing: 8) {
                    Label(monitor.efficiencyRating, systemImage: "leaf.fill")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundColor(totalColor(monitor.totalWatts))

                    Label(String(format: "%.2f kWh today", monitor.kWhToday), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(String(format: "≈ %.0fg CO₂ today", monitor.co2Today), systemImage: "leaf.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                // Mini arc gauge
                ZStack {
                    Circle()
                        .trim(from: 0.1, to: 0.9)
                        .stroke(Color.gray.opacity(0.15),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(126))
                    Circle()
                        .trim(from: 0.1,
                              to: 0.1 + 0.8 * min(CGFloat(monitor.totalWatts / 22.0), 1.0))
                        .stroke(
                            LinearGradient(colors: [.green, .blue, .orange, .red],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(126))
                        .animation(.easeOut(duration: 0.3), value: monitor.totalWatts)
                    VStack(spacing: 1) {
                        Text("\(Int((monitor.totalWatts / 22.0) * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("of TDP")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
            }

            // ── Per-Component Live Bars ────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("Component Breakdown")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                LivePowerBar(label: "CPU", sublabel: "\(Int(monitor.cpuPercent))% load",
                             watts: monitor.cpuWatts, maxW: 22, color: .blue, icon: "cpu")
                LivePowerBar(label: "GPU / Display", sublabel: "",
                             watts: monitor.gpuWatts, maxW: 22, color: .purple, icon: "display")
                LivePowerBar(label: "RAM", sublabel: "LPDDR5X 16 GB",
                             watts: monitor.ramWatts, maxW: 22, color: .orange, icon: "memorychip")
                LivePowerBar(label: "SSD", sublabel: "NVMe",
                             watts: monitor.ssdWatts, maxW: 22, color: .teal, icon: "internaldrive")
                LivePowerBar(label: "Network", sublabel: "",
                             watts: monitor.netWatts, maxW: 22, color: .green, icon: "wifi")
                LivePowerBar(label: "Fan", sublabel: "Fanless",
                             watts: 0, maxW: 22, color: .gray, icon: "wind")
            }

            Divider()

            // ── Top Consumers ──────────────────────────────────────────────
            if !monitor.topConsumers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top Power Consumers")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Live · refreshes every 3 s")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    let maxScore = monitor.topConsumers.first?.powerScore ?? 1.0
                    ForEach(monitor.topConsumers.prefix(6)) { proc in
                        HStack(spacing: 10) {
                            Text(proc.name)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 170, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.orange.opacity(0.1))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.orange, .red],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(proc.powerScore / maxScore))
                                        .animation(.easeOut(duration: 0.3), value: proc.powerScore)
                                }
                            }
                            .frame(height: 9)
                            Text(String(format: "%.1f", proc.powerScore))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }

            // ── Last Wake Info ─────────────────────────────────────────────
            if let wakeTime = monitor.lastWakeTime {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption)
                        .foregroundColor(.indigo)
                    Text("Last wake: \(wakeTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if monitor.isPostWake {
                        Text("• Post-wake monitoring active")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
        .drawingGroup() // Optimize GPU load for frequently updating power bars
    }

    private func totalColor(_ w: Double) -> Color {
        let pct = w / 22.0
        return pct < 0.35 ? .green : pct < 0.65 ? .blue : pct < 0.85 ? .orange : .red
    }
}

// MARK: - Live Power Bar (animated, with watt label)

struct LivePowerBar: View {
    let label: String
    let sublabel: String
    let watts: Double
    let maxW: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                if !sublabel.isEmpty {
                    Text(sublabel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 118, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: maxW > 0 ? geo.size.width * CGFloat(watts / maxW) : 0)
                        .animation(.easeOut(duration: 0.3), value: watts)
                }
            }
            .frame(height: 12)

            Text(watts == 0 ? "0.0 W" : String(format: "%.1f W", watts))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(watts == 0 ? .secondary : color)
                .frame(width: 42, alignment: .trailing)
                .animation(.none, value: watts) // Removed content transition to save GPU
        }
    }
}
