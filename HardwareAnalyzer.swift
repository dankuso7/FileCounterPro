import SwiftUI
import AppKit

// MARK: - Data Models

struct SmartMetrics: Equatable {
    var temperatureCelsius: Int = 0
    var percentageUsed: Int = 0
    var tbRead: Double = 0.0
    var tbWritten: Double = 0.0
    var powerCycles: Int = 0
    var powerOnHours: Int = 0
    var overallHealth: String = "PASSED"
    var isSupported: Bool = true
}

// MARK: - Power Models

struct PowerConsumerProcess: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let pid: Int
    let powerScore: Double   // from top POWER column (relative, unitless)
}

struct MacPowerMetrics: Equatable {
    // Chip-level estimates (M4 Mac mini TDP envelope)
    var estimatedCPUWatts: Double = 0
    var estimatedGPUWatts: Double = 0
    var estimatedSSDWatts: Double = 0
    var estimatedRAMWatts: Double = 0
    var estimatedFanWatts: Double = 0  // fans = 0 on M4 Mac mini (passive)
    var totalEstimatedWatts: Double = 0
    var idleWatts: Double = 0           // M4 Mac mini idle ≈ 7W
    var maxTDPWatts: Double = 0         // M4 Mac mini max TDP ≈ 22W
    var cpuLoadPercent: Double = 0
    var memPressurePercent: Double = 0
    var topConsumers: [PowerConsumerProcess] = []
    var powerEfficiencyRating: String = "Unknown"
    var powerMode: String = "Unknown"
    var networkWatts: Double = 0
    var totalKWhToday: Double = 0       // estimated kWh burned today
    var co2GramsToday: Double = 0       // CO₂ equivalent grams
}

struct HardwareReport: Equatable {
    let chipModel: String
    let coreConfig: String
    let totalRAM: String
    let ssdHealth: String
    let ssdDevice: String
    let ssdTotalGB: Int
    let ssdFreeGB: Double
    let hasBattery: Bool
    let batteryHealth: String
    let batteryCycles: String
    let thermalStatus: String
    let externalDrives: String
    let lifetimeScore: Int
    let aiDiagnosis: String
    let smartMetrics: SmartMetrics
    let powerSource: String
    let powerMetrics: MacPowerMetrics    // NEW: full power breakdown
}

// MARK: - Analyzer

@MainActor
class HardwareAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var report: HardwareReport?

    func analyzeMac() {
        isAnalyzing = true
        Task {
            let r = await buildReport()
            self.report = r
            self.isAnalyzing = false
        }
    }

    private func buildReport() async -> HardwareReport {
        // Run all probes concurrently
        async let hwInfo      = shellString("system_profiler SPHardwareDataType 2>/dev/null")
        async let storageInfo = shellString("system_profiler SPStorageDataType 2>/dev/null")
        async let powerInfo   = shellString("system_profiler SPPowerDataType 2>/dev/null")
        async let pmsetBatt   = shellString("pmset -g batt 2>/dev/null")
        async let pmsetTherm  = shellString("pmset -g therm 2>/dev/null")
        async let dfInfo      = shellString("df -H / 2>/dev/null")
        async let smartRaw    = shellString("/opt/homebrew/bin/smartctl -a /dev/disk0 2>/dev/null")
        async let diskInfo    = shellString("diskutil info /dev/disk0 2>/dev/null")
        async let extVerify   = shellString("for d in $(diskutil list external | grep -Eo '^/dev/disk[0-9]+' | uniq | head -1); do diskutil verifyDisk $d 2>/dev/null; done")
        async let ioregBatt   = shellString("ioreg -r -c AppleSmartBattery 2>/dev/null | grep -E 'CycleCount|CurrentCapacity|MaxCapacity|Temperature|ExternalConnected|IsCharging'")
        // Power: two samples 1s apart so top can calculate a real delta
        async let powerRaw    = shellString("top -l 2 -s 1 -o power -n 30 2>/dev/null")
        async let pmsetPower  = shellString("pmset -g 2>/dev/null")
        async let topSummary  = shellString("top -l 1 -n 0 2>/dev/null")

        let (hw, storage, power, batt, therm, df, smart, disk, ext, iobatt, pRaw, pmPow, topSum) =
            await (hwInfo, storageInfo, powerInfo, pmsetBatt, pmsetTherm, dfInfo, smartRaw, diskInfo, extVerify, ioregBatt, powerRaw, pmsetPower, topSummary)

        // ── Hardware identity ──────────────────────────────────────────────
        let chipModel   = parseFirst(hw, pattern: "Chip:\\s*(.+)")     ?? "Apple Silicon"
        let coreConfig  = parseFirst(hw, pattern: "Total Number of Cores:\\s*(.+)") ?? "Unknown"
        let ramRaw      = parseFirst(hw, pattern: "Memory:\\s*(.+)")   ?? "Unknown"
        let totalRAM    = ramRaw.trimmingCharacters(in: .whitespaces)

        // ── SSD ─────────────────────────────────────────────────────────────
        let ssdDevice   = parseFirst(disk, pattern: "Device / Media Name:\\s*(.+)") ?? "Apple SSD"
        let ssdSMART    = storage.contains("Verified") ? "Verified" : "Failing"

        // Parse SSD total size from df (e.g. "245G")
        var ssdTotalGB = 0
        var ssdFreeGB  = 0.0
        for line in df.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 4, parts.last == "/" || parts.last?.hasSuffix("/") == true {
                if let sizeStr = parts[first: 1] {
                    ssdTotalGB = parseGB(String(sizeStr))
                }
                if let freeStr = parts[first: 3] {
                    ssdFreeGB = parseGBDouble(String(freeStr))
                }
            }
        }

        // ── Power Source ────────────────────────────────────────────────────
        // batt is the awaited value of pmsetBatt async let
        let isOnAC = batt.contains("AC Power")
        let powerSource = isOnAC ? "AC Power" : "Battery"

        // ── Battery (M4 Mac mini has no battery) ───────────────────────────
        let hasBattery: Bool
        let batteryHealth: String
        let batteryCycles: String

        // Check ioreg for real battery data first
        let ioCycles   = parseFirst(iobatt, pattern: "\"CycleCount\"\\s*=\\s*(\\d+)")
        let ioMaxCap   = parseFirst(iobatt, pattern: "\"MaxCapacity\"\\s*=\\s*(\\d+)")

        if let cyclesStr = ioCycles, let cycles = Int(cyclesStr), cycles > 0,
           let maxStr = ioMaxCap, let maxCap = Int(maxStr), maxCap > 0 {
            hasBattery    = true
            batteryCycles = "\(cycles)"
            // Derive health from capacity
            let designCap = Int(parseFirst(iobatt, pattern: "\"DesignCapacity\"\\s*=\\s*(\\d+)") ?? "0") ?? 0
            if designCap > 0 {
                let pct = Int(Double(maxCap) / Double(designCap) * 100)
                batteryHealth = pct > 80 ? "Normal (\(pct)%)" : "Service Recommended (\(pct)%)"
            } else {
                batteryHealth = parseFirst(power, pattern: "Condition:\\s*(.+)") ?? "Normal"
            }
        } else if let cond = parseFirst(power, pattern: "Condition:\\s*(.+)"),
                  let cyc  = parseFirst(power, pattern: "Cycle Count:\\s*(\\d+)") {
            hasBattery    = true
            batteryCycles = cyc
            batteryHealth = cond.trimmingCharacters(in: .whitespaces)
        } else {
            // Mac mini — no battery
            hasBattery    = false
            batteryCycles = "N/A"
            batteryHealth = "No Battery (Desktop)"
        }

        // ── Thermal ─────────────────────────────────────────────────────────
        let thermalStatus: String
        if therm.contains("No thermal warning") {
            thermalStatus = "Nominal"
        } else if therm.lowercased().contains("danger") || therm.lowercased().contains("heavy") {
            thermalStatus = "Throttling"
        } else if therm.contains("warning") {
            thermalStatus = "Elevated"
        } else {
            thermalStatus = "Nominal"
        }

        // ── External Drives ─────────────────────────────────────────────────
        let extStatus: String
        if ext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extStatus = "None Detected"
        } else if ext.contains("appears to be OK") {
            extStatus = "Verified & Healthy"
        } else if ext.lowercased().contains("corrupt") || ext.lowercased().contains("error") {
            extStatus = "Corrupted / Failing"
        } else {
            extStatus = "Present"
        }

        // ── S.M.A.R.T. Deep Metrics ─────────────────────────────────────────
        let sMetrics = parseSmartctl(smart)

        // ── Lifetime Score (adapted for Mac mini — no battery penalty) ──────
        var score = 100
        var diagnosis = "Your \(chipModel) Mac is in excellent health. All hardware subsystems are operating normally."

        if ssdSMART != "Verified" {
            score -= 50
            diagnosis = "⚠️ CRITICAL: Your SSD is failing S.M.A.R.T. checks. Physical drive failure is imminent — back up your data immediately!"
        }
        if thermalStatus == "Throttling" {
            score -= 30
            diagnosis = "⚠️ THERMAL ALERT: Your \(chipModel) is thermal-throttling. This causes irreversible degradation over time. Check for blocked airflow."
        }
        if extStatus.contains("Failing") || extStatus.contains("Corrupted") {
            score -= 20
            if score > 50 { diagnosis = "⚠️ EXTERNAL DRIVE: Connected removable storage is reporting partition corruption. Run Disk Utility First Aid immediately." }
        }
        if hasBattery, let c = Int(batteryCycles), c > 1000 {
            score -= 20
            if score > 50 { diagnosis = "⚠️ BATTERY: Cycle count \(c) exceeds the typical 1,000-cycle lifespan. Expect reduced battery capacity." }
        }
        if sMetrics.percentageUsed > 80 {
            score -= 40
            diagnosis = "⚠️ SSD LIFESPAN: Your internal SSD has used \(sMetrics.percentageUsed)% of its total write endurance. Plan for replacement soon."
        } else if sMetrics.percentageUsed > 50 {
            score -= 10
        }

        // Disk space health
        let usedPct = ssdTotalGB > 0 ? Int(Double(ssdTotalGB - Int(ssdFreeGB)) / Double(ssdTotalGB) * 100) : 0
        if usedPct > 90 {
            score -= 15
            if score > 50 { diagnosis = "⚠️ STORAGE: Your disk is over 90% full (\(ssdTotalGB - Int(ssdFreeGB)) GB used of \(ssdTotalGB) GB). This severely impacts performance." }
        }

        // ── Power Consumption ────────────────────────────────────────────────
        let powerMetrics = parsePowerMetrics(topRaw: pRaw, pmsetRaw: pmPow, topSummary: topSum, chipModel: chipModel)

        return HardwareReport(
            chipModel:    chipModel,
            coreConfig:   coreConfig,
            totalRAM:     totalRAM,
            ssdHealth:    ssdSMART,
            ssdDevice:    ssdDevice,
            ssdTotalGB:   ssdTotalGB,
            ssdFreeGB:    ssdFreeGB,
            hasBattery:   hasBattery,
            batteryHealth: batteryHealth,
            batteryCycles: batteryCycles,
            thermalStatus: thermalStatus,
            externalDrives: extStatus,
            lifetimeScore: max(0, score),
            aiDiagnosis:  diagnosis,
            smartMetrics: sMetrics,
            powerSource:  powerSource,
            powerMetrics: powerMetrics
        )
    }

    // MARK: - Parsers

    private func parseSmartctl(_ raw: String) -> SmartMetrics {
        guard !raw.isEmpty else { return SmartMetrics(isSupported: false) }
        var m = SmartMetrics()
        m.isSupported = true
        m.overallHealth = raw.contains("PASSED") ? "PASSED" : (raw.contains("FAILED") ? "FAILED" : "UNKNOWN")

        for line in raw.split(separator: "\n") {
            let s = String(line)
            if s.contains("Temperature:") {
                m.temperatureCelsius = Int(parseFirst(s, pattern: "(\\d+) Celsius") ?? "0") ?? 0
            } else if s.contains("Percentage Used:") {
                m.percentageUsed = Int(parseFirst(s, pattern: "(\\d+)%") ?? "0") ?? 0
            } else if s.contains("Data Units Read:") {
                m.tbRead = extractTB(s)
            } else if s.contains("Data Units Written:") {
                m.tbWritten = extractTB(s)
            } else if s.contains("Power Cycles:") {
                m.powerCycles = Int(parseFirst(s, pattern: "([\\d,]+)$")?.replacingOccurrences(of: ",", with: "") ?? "0") ?? 0
            } else if s.contains("Power On Hours:") {
                m.powerOnHours = Int(parseFirst(s, pattern: "([\\d,]+)$")?.replacingOccurrences(of: ",", with: "") ?? "0") ?? 0
            }
        }
        return m
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

    private func extractTB(_ line: String) -> Double {
        guard let start = line.firstIndex(of: "["), let end = line.firstIndex(of: "]") else { return 0 }
        let inner = String(line[line.index(after: start)..<end])
        let parts = inner.split(separator: " ")
        guard parts.count == 2, let val = Double(parts[0]) else { return 0 }
        let unit = parts[1].uppercased()
        if unit == "TB" { return val }
        if unit == "GB" { return val / 1024 }
        return 0
    }

    private func parseGB(_ s: String) -> Int {
        let clean = s.trimmingCharacters(in: .whitespaces).uppercased()
        if clean.hasSuffix("G"), let v = Double(clean.dropLast()) { return Int(v) }
        if clean.hasSuffix("T"), let v = Double(clean.dropLast()) { return Int(v * 1024) }
        return 0
    }

    private func parseGBDouble(_ s: String) -> Double {
        let clean = s.trimmingCharacters(in: .whitespaces).uppercased()
        if clean.hasSuffix("G"), let v = Double(clean.dropLast()) { return v }
        if clean.hasSuffix("T"), let v = Double(clean.dropLast()) { return v * 1024 }
        return 0
    }

    // MARK: - Power Consumption Parser
    // Uses top's POWER column (Apple hardware power-impact score) + CPU load
    // to derive wattage estimates calibrated for M4 Mac mini TDP envelope.

    private func parsePowerMetrics(topRaw: String, pmsetRaw: String, topSummary: String, chipModel: String) -> MacPowerMetrics {
        var m = MacPowerMetrics()

        // M4 Mac mini hardware constants
        // Source: Apple Spec + AnandTech silicon characterization
        m.idleWatts   = 7.0    // measured idle AC draw
        m.maxTDPWatts = 22.0   // M4 chip TDP (configurable up to 22W)
        let ramIdleW  = 0.8    // LPDDR5X 16GB idle
        let ssdIdleW  = 0.3    // NVMe SSD idle
        let netIdleW  = 0.2    // Wi-Fi/Ethernet standby

        // ── CPU load from top summary ──────────────────────────────────────
        var cpuUser = 0.0
        var cpuSys  = 0.0
        var cpuIdle = 100.0
        for line in topSummary.split(separator: "\n") {
            let s = String(line)
            if s.contains("CPU usage:") {
                if let u = parseFirst(s, pattern: "([\\d.]+)% user") { cpuUser = Double(u) ?? 0 }
                if let y = parseFirst(s, pattern: "([\\d.]+)% sys")  { cpuSys  = Double(y) ?? 0 }
                if let i = parseFirst(s, pattern: "([\\d.]+)% idle") { cpuIdle = Double(i) ?? 100 }
            }
        }
        let cpuActive = cpuUser + cpuSys
        m.cpuLoadPercent = min(cpuActive, 100.0)

        // ── Wattage estimation ──────────────────────────────────────────────
        // CPU: idle ~3W, max ~16W (M4 10-core)
        let cpuFraction = m.cpuLoadPercent / 100.0
        m.estimatedCPUWatts = 3.0 + cpuFraction * 13.0

        // GPU: parse from top POWER summary line or estimate from ANE / GPU load
        // Heuristic: GPU load correlates with WindowServer POWER score
        var windowServerPower = 0.0
        var anedPower = 0.0
        var topConsumers: [PowerConsumerProcess] = []

        // Parse the second sample from top -l 2 (more accurate delta)
        let lines = topRaw.split(separator: "\n").map { String($0) }
        var inSecondSample = false
        var headerPassed = false
        var sampleCount = 0

        for line in lines {
            // Detect sample boundaries (top -l 2 outputs two snapshots)
            if line.hasPrefix("Processes:") { sampleCount += 1; if sampleCount == 2 { inSecondSample = true; headerPassed = false } }
            if !inSecondSample { continue }
            if line.contains("PID") && line.contains("COMMAND") && line.contains("POWER") { headerPassed = true; continue }
            guard headerPassed else { continue }

            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 22 else { continue }
            let pid = Int(parts[0]) ?? 0
            let name = String(parts[1])
            // POWER is at index 20 in the wide top output
            let powerVal = Double(parts[20]) ?? 0.0

            if name.lowercased().contains("windowserver") { windowServerPower = powerVal }
            if name.lowercased().contains("aned") { anedPower = powerVal }

            if powerVal > 0.5 {
                topConsumers.append(PowerConsumerProcess(name: name, pid: pid, powerScore: powerVal))
            }
        }

        // GPU watts: WindowServer POWER score correlates with GPU render load
        // Scale: POWER 50 ≈ ~2.5W GPU; max GPU ≈ 3.5W on M4 Mac mini
        m.estimatedGPUWatts = min(windowServerPower / 20.0, 3.5) + min(anedPower / 20.0, 1.0)
        if m.estimatedGPUWatts == 0 { m.estimatedGPUWatts = 1.0 } // at least display idle

        // RAM: dynamic — scales with memory pressure
        let memPressureStr = parseFirst(topSummary, pattern: "([\\d.]+)%? unused") ?? ""
        let unusedMB = Double(memPressureStr.replacingOccurrences(of: "M", with: "")) ?? 0
        let usedFrac = unusedMB > 0 ? max(0, 1.0 - (unusedMB / 16384.0)) : 0.8
        m.memPressurePercent = usedFrac * 100.0
        m.estimatedRAMWatts = ramIdleW + usedFrac * 1.2

        // SSD: varies with disk I/O (we don't have live I/O watts, use heuristic)
        m.estimatedSSDWatts = ssdIdleW + (cpuFraction * 0.3)

        // Network (Wi-Fi/Ethernet active draw)
        m.networkWatts = netIdleW + (cpuFraction * 0.15)

        // Fans = 0 for M4 Mac mini (fanless design)
        m.estimatedFanWatts = 0.0

        // Total
        m.totalEstimatedWatts = m.estimatedCPUWatts
                               + m.estimatedGPUWatts
                               + m.estimatedRAMWatts
                               + m.estimatedSSDWatts
                               + m.networkWatts
                               + 1.2 // board/USB overhead

        // Clamp to hardware envelope
        m.totalEstimatedWatts = max(m.idleWatts, min(m.totalEstimatedWatts, m.maxTDPWatts))

        // Power mode from pmset
        if pmsetRaw.contains("lowpowermode 1") {
            m.powerMode = "Low Power Mode"
        } else if pmsetRaw.contains("powernap 1") {
            m.powerMode = "Power Nap Active"
        } else {
            m.powerMode = "Normal"
        }

        // Top consumers sorted
        m.topConsumers = Array(topConsumers.sorted { $0.powerScore > $1.powerScore }.prefix(8))

        // Efficiency rating
        let utilPct = m.totalEstimatedWatts / m.maxTDPWatts
        m.powerEfficiencyRating = utilPct < 0.35 ? "🟢 Excellent" :
                                  utilPct < 0.65 ? "🟡 Good" :
                                  utilPct < 0.85 ? "🟠 High" : "🔴 Near Max"

        // CO₂ estimate: average US grid 386 gCO₂/kWh
        // kWh today = watts × hours_today / 1000  (assume 16h active day)
        let hoursActiveToday = 16.0
        m.totalKWhToday = m.totalEstimatedWatts * hoursActiveToday / 1000.0
        m.co2GramsToday = m.totalKWhToday * 386.0

        return m
    }
}

private extension Array {
    subscript(first index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Hardware Analyzer View

struct HardwareAnalyzerView: View {
    @StateObject private var analyzer = HardwareAnalyzer()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Header ──────────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Health Analyzer")
                            .font(.system(size: 24, weight: .bold))
                        Text("Live power · Deep hardware diagnostics · Sleep/wake aware")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // ── LIVE POWER — always shown immediately ──────────────────
                // No scan required: updates every 3s, reacts to sleep/wake and
                // Low Power Mode toggle automatically.
                LivePowerDashboardView()

                // ── NETWORK — always shown, live every 3s ──────────────────
                NetworkMonitorView()

                // ── Deep Scan Section ─────────────────────────────────────
                if analyzer.isAnalyzing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("Probing hardware sensors, S.M.A.R.T. telemetry\nand system thermal state…")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)

                } else if let r = analyzer.report {
                    // ── Identity Banner ────────────────────────────────────
                    IdentityBannerView(report: r)

                    // ── Health Score ───────────────────────────────────────
                    HealthScoreView(score: r.lifetimeScore)

                    // ── Hardware Metrics Grid ──────────────────────────────
                    HardwareGridView(report: r)

                    // ── Deep S.M.A.R.T. Charts ─────────────────────────────
                    SmartDiskChartsView(metrics: r.smartMetrics, ssdDevice: r.ssdDevice)

                    // ── Disk Usage Bar ─────────────────────────────────────
                    DiskUsageBarView(totalGB: r.ssdTotalGB, freeGB: r.ssdFreeGB)

                    // ── AI Diagnosis ───────────────────────────────────────
                    AIDiagnosisView(diagnosis: r.aiDiagnosis, score: r.lifetimeScore)

                } else {
                    // CTA
                    VStack(spacing: 20) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Run a deep scan for S.M.A.R.T. NVMe telemetry,\nthermal state, disk health, and lifetime score.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button("Run Deep Hardware Scan") {
                            analyzer.analyzeMac()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(height: 220)
                }
            }
            .padding(28)
        }
        .frame(width: 700)
        .background(.regularMaterial)
    }
}

// MARK: - Sub-Views

struct IdentityBannerView: View {
    let report: HardwareReport

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "macmini.fill")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 6) {
                Text(report.chipModel)
                    .font(.system(size: 18, weight: .bold))
                HStack(spacing: 16) {
                    Label(report.coreConfig, systemImage: "cpu")
                    Label(report.totalRAM, systemImage: "memorychip")
                    Label(report.powerSource, systemImage: report.powerSource == "AC Power" ? "bolt.fill" : "battery.75")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

struct HealthScoreView: View {
    let score: Int

    var scoreColor: Color {
        score > 80 ? .green : score > 50 ? .orange : .red
    }

    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: score)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text("Overall Health Score")
                    .font(.headline)
                Text(score > 80 ? "Excellent — All systems nominal." :
                     score > 50 ? "Good — Minor issues detected." :
                                  "Action Required — Critical issues found.")
                    .font(.subheadline)
                    .foregroundColor(scoreColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

struct HardwareGridView: View {
    let report: HardwareReport

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HWCard(title: "CPU/GPU Heat",
                       value: report.thermalStatus,
                       icon: "thermometer.medium",
                       isWarning: report.thermalStatus != "Nominal")
                HWCard(title: "SSD Health",
                       value: report.ssdHealth,
                       icon: "internaldrive",
                       isWarning: report.ssdHealth != "Verified")
                HWCard(title: "External Drive",
                       value: report.externalDrives,
                       icon: "externaldrive.fill",
                       isWarning: report.externalDrives.contains("Failing") || report.externalDrives.contains("Corrupted"))
            }
            HStack(spacing: 10) {
                HWCard(title: "Battery Cycles",
                       value: report.batteryCycles,
                       icon: "battery.100",
                       isWarning: (Int(report.batteryCycles) ?? 0) > 1000)
                HWCard(title: "Battery Health",
                       value: report.batteryHealth,
                       icon: "bolt.heart.fill",
                       isWarning: !report.batteryHealth.contains("Normal") && !report.batteryHealth.contains("No Battery"))
                HWCard(title: "Power Source",
                       value: report.powerSource,
                       icon: "powerplug.fill",
                       isWarning: false)
            }
        }
    }
}

struct HWCard: View {
    let title: String
    let value: String
    let icon: String
    let isWarning: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isWarning ? .red : .blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(isWarning ? .red : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

struct SmartDiskChartsView: View {
    let metrics: SmartMetrics
    let ssdDevice: String

    var tempColor: Color {
        metrics.temperatureCelsius > 60 ? .red :
        metrics.temperatureCelsius > 45 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.blue)
                Text("Deep NVMe S.M.A.R.T. Telemetry")
                    .font(.headline)
                Spacer()
                Text(ssdDevice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if metrics.isSupported && (metrics.tbRead > 0 || metrics.tbWritten > 0) {
                HStack(alignment: .top, spacing: 20) {

                    // ── Lifespan Gauge ─────────────────────────
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: CGFloat(metrics.percentageUsed) / 100.0)
                                .stroke(metrics.percentageUsed > 80 ? Color.red : metrics.percentageUsed > 50 ? Color.orange : Color.blue,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.3), value: metrics.percentageUsed)
                            VStack(spacing: 2) {
                                Text("\(metrics.percentageUsed)%")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                Text("Degraded")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 85, height: 85)
                        Text("Write Endurance")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // ── Temperature Gauge ──────────────────────
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: min(CGFloat(metrics.temperatureCelsius) / 80.0, 1.0))
                                .stroke(tempColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(metrics.temperatureCelsius)°C")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(tempColor)
                                Text("SSD Temp")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 85, height: 85)
                        Text("Drive Temperature")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // ── TBW Bar Chart ──────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Read / Write Volume")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        let maxTB = max(metrics.tbRead, metrics.tbWritten, 1.0)

                        TBBar(label: "Read", value: metrics.tbRead, max: maxTB, color: .green)
                        TBBar(label: "Written", value: metrics.tbWritten, max: maxTB, color: .orange)

                        Text("SMART: \(metrics.overallHealth)")
                            .font(.caption2.bold())
                            .foregroundColor(metrics.overallHealth == "PASSED" ? .green : .red)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)

                    // ── Power Stats ────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        StatRow(icon: "power", label: "Power Cycles", value: "\(metrics.powerCycles)", color: .purple)
                        StatRow(icon: "clock.fill", label: "Hours On", value: "\(metrics.powerOnHours) hrs", color: .blue)
                        StatRow(icon: "calendar", label: "Est. Days On", value: "\(metrics.powerOnHours / 24) days", color: .teal)
                    }
                    .frame(width: 130)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("S.M.A.R.T. data unavailable — USB bridge or firmware restriction.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

struct TBBar: View {
    let label: String
    let value: Double
    let max: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .frame(width: 42, alignment: .trailing)
                .foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(value / max) : 0)
                        .animation(.easeOut(duration: 0.3), value: value)
                }
            }
            .frame(height: 12)
            Text(String(format: "%.1f TB", value))
                .font(.caption2.bold())
                .frame(width: 52, alignment: .leading)
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(.subheadline, design: .rounded).bold())
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

struct DiskUsageBarView: View {
    let totalGB: Int
    let freeGB: Double

    var usedGB: Double { Double(totalGB) - freeGB }
    var usedPct: Double { totalGB > 0 ? usedGB / Double(totalGB) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(.blue)
                Text("Internal Storage")
                    .font(.headline)
                Spacer()
                Text("\(Int(usedGB)) GB used of \(totalGB) GB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(usedPct > 0.9 ? Color.red : usedPct > 0.7 ? Color.orange : Color.blue)
                        .frame(width: geo.size.width * CGFloat(usedPct), height: 16)
                        .animation(.easeOut(duration: 0.3), value: usedPct)
                }
            }
            .frame(height: 16)

            HStack {
                Text(String(format: "%.1f GB free", freeGB))
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text(String(format: "%.0f%% used", usedPct * 100))
                    .font(.caption.bold())
                    .foregroundColor(usedPct > 0.9 ? .red : .primary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

struct AIDiagnosisView: View {
    let diagnosis: String
    let score: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 6) {
                Text("AI Diagnosis")
                    .font(.headline)
                Text(diagnosis)
                    .font(.body)
                    .foregroundColor(score > 80 ? .primary : score > 50 ? .orange : .red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

// MARK: - Power Consumption View

struct PowerConsumptionView: View {
    let metrics: MacPowerMetrics
    let chipModel: String

    var totalColor: Color {
        let pct = metrics.totalEstimatedWatts / metrics.maxTDPWatts
        return pct < 0.35 ? .green : pct < 0.65 ? .blue : pct < 0.85 ? .orange : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("Power Consumption")
                    .font(.headline)
                Spacer()
                Text(metrics.powerMode)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(metrics.powerMode == "Low Power Mode" ? Color.green.opacity(0.15) : Color.blue.opacity(0.1))
                    .foregroundColor(metrics.powerMode == "Low Power Mode" ? .green : .blue)
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 20) {

                // ── Total Watt Arc ─────────────────────────────────────────
                VStack(spacing: 8) {
                    ZStack {
                        // Background arc
                        Circle()
                            .trim(from: 0.1, to: 0.9)
                            .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(126))

                        // Filled arc
                        Circle()
                            .trim(from: 0.1, to: 0.1 + 0.8 * CGFloat(metrics.totalEstimatedWatts / metrics.maxTDPWatts))
                            .stroke(
                                LinearGradient(colors: [.green, .blue, .orange, .red],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(126))
                            .animation(.easeOut(duration: 0.3), value: metrics.totalEstimatedWatts)

                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", metrics.totalEstimatedWatts))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(totalColor)
                            Text("Watts")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("of \(Int(metrics.maxTDPWatts))W max")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 110, height: 110)

                    Text(metrics.powerEfficiencyRating)
                        .font(.caption.bold())

                    // CO₂
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f kWh/day", metrics.totalKWhToday))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text(String(format: "≈ %.0fg CO₂/day", metrics.co2GramsToday))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                }

                // ── Component Breakdown ────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Component Breakdown")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    PowerBar(label: "CPU (\(Int(metrics.cpuLoadPercent))%)", watts: metrics.estimatedCPUWatts, max: metrics.maxTDPWatts, color: .blue, icon: "cpu")
                    PowerBar(label: "GPU / Display", watts: metrics.estimatedGPUWatts, max: metrics.maxTDPWatts, color: .purple, icon: "display")
                    PowerBar(label: "RAM", watts: metrics.estimatedRAMWatts, max: metrics.maxTDPWatts, color: .orange, icon: "memorychip")
                    PowerBar(label: "SSD", watts: metrics.estimatedSSDWatts, max: metrics.maxTDPWatts, color: .teal, icon: "internaldrive")
                    PowerBar(label: "Network", watts: metrics.networkWatts, max: metrics.maxTDPWatts, color: .green, icon: "wifi")
                    PowerBar(label: "Fan", watts: metrics.estimatedFanWatts, max: metrics.maxTDPWatts, color: .gray, icon: "wind")

                    HStack {
                        Spacer()
                        Text("Idle floor: \(Int(metrics.idleWatts))W  •  TDP ceiling: \(Int(metrics.maxTDPWatts))W")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // ── Top Power Consumers ────────────────────────────────────────
            if !metrics.topConsumers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Power Consumers")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    let maxScore = metrics.topConsumers.first?.powerScore ?? 1.0

                    ForEach(metrics.topConsumers.prefix(6)) { proc in
                        HStack(spacing: 10) {
                            Text(proc.name)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                                .frame(width: 160, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.orange.opacity(0.12))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(colors: [.orange, .red],
                                                           startPoint: .leading, endPoint: .trailing)
                                        )
                                        .frame(width: geo.size.width * CGFloat(proc.powerScore / maxScore))
                                        .animation(.easeOut(duration: 0.3), value: proc.powerScore)
                                }
                            }
                            .frame(height: 10)

                            Text(String(format: "%.1f", proc.powerScore))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }
}

struct PowerBar: View {
    let label: String
    let watts: Double
    let max: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11))
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(watts / max) : 0)
                        .animation(.easeOut(duration: 0.3), value: watts)
                }
            }
            .frame(height: 10)
            Text(String(format: "%.1fW", watts))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - Legacy Card (used by ContentView)

struct HardwareMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let isWarning: Bool

    var body: some View {
        HWCard(title: title, value: value, icon: icon, isWarning: isWarning)
    }
}
