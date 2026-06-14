import SwiftUI
import AppKit

// MARK: - Network Data Models

struct NetworkInterfaceInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String          // "Wi-Fi", "Ethernet"
    let device: String        // "en1"
    let ipv4: String
    let ipv6: String
    let macAddress: String
    let isActive: Bool
}

struct WiFiDetails: Equatable {
    var ssid: String         = "—"
    var phyMode: String      = "—"   // "802.11n", "802.11ax"
    var channel: String      = "—"
    var band: String         = "—"   // "2 GHz", "5 GHz", "6 GHz"
    var security: String     = "—"
    var signalDBm: Int       = 0
    var noiseDBm: Int        = 0
    var snr: Int             = 0
    var txRateMbps: Int      = 0
    var countryCode: String  = "—"
    var signalBars: Int      = 0     // 1–4
    var signalLabel: String  = "—"
}

struct NetworkSpeed: Equatable {
    var downloadMbps: Double = 0
    var uploadMbps: Double   = 0
    var totalReceivedGB: Double = 0
    var totalSentGB: Double     = 0
    var sessionReceivedMB: Double = 0
    var sessionSentMB: Double   = 0
    var pingMs: Double          = 0
}

struct NetworkSnapshot: Equatable {
    var connectionType: String    = "Unknown"   // "Wi-Fi", "Ethernet", "No Connection"
    var activeInterface: String   = "—"         // "en1"
    var ipAddress: String         = "—"
    var routerIP: String          = "—"
    var interfaces: [NetworkInterfaceInfo] = []
    var wifi: WiFiDetails         = WiFiDetails()
    var speed: NetworkSpeed       = NetworkSpeed()
    var isConnected: Bool         = false
    var capturedAt: Date          = Date()
}

// MARK: - Network Monitor

@MainActor
class NetworkMonitor: ObservableObject {

    @Published var snapshot = NetworkSnapshot()
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double   = 0

    // Byte counters from previous sample (for speed calculation)
    private var prevRxBytes: UInt64 = 0
    private var prevTxBytes: UInt64 = 0
    private var prevSampleTime: Date = Date()

    private var pollTask: Task<Void, Never>?

    init() { startPolling() }

    deinit { pollTask?.cancel() }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await sample()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: - Core Sample

    func sample() async {
        async let ifconfigRaw  = shellString("ifconfig -a 2>/dev/null")
        async let netstatRaw   = shellString("netstat -ibn 2>/dev/null")
        async let airportRaw   = shellString("system_profiler SPAirPortDataType 2>/dev/null")
        async let networkRaw   = shellString("networksetup -getinfo Wi-Fi 2>/dev/null")
        async let hardwareRaw  = shellString("networksetup -listallhardwareports 2>/dev/null")
        async let routeRaw     = shellString("route -n get default 2>/dev/null | grep gateway")
        async let pingRaw      = shellString("ping -c 1 -W 500 8.8.8.8 2>/dev/null")

        let (ifc, nst, ap, nw, hw, rt, png) = await (ifconfigRaw, netstatRaw, airportRaw, networkRaw, hardwareRaw, routeRaw, pingRaw)

        var snap = NetworkSnapshot()
        snap.capturedAt = Date()

        // ── Active interface detection ───────────────────────────────────────
        // Find which en* is active and has an IP
        let activeIface = detectActiveInterface(ifconfigRaw: ifc)
        snap.activeInterface = activeIface.device

        // Connection type
        snap.connectionType = activeIface.connectionType
        snap.isConnected    = activeIface.isConnected
        snap.ipAddress      = activeIface.ip

        // Router IP
        snap.routerIP = parseFirst(rt, pattern: "gateway:\\s+(\\S+)") ?? "—"

        // ── Wi-Fi details ───────────────────────────────────────────────────
        if snap.connectionType == "Wi-Fi" || ifc.contains("en1") {
            snap.wifi = parseWiFiDetails(airportRaw: ap, networkRaw: nw)
        }

        // ── Speed from netstat byte counters ────────────────────────────────
        snap.speed = parseSpeed(netstatRaw: nst, iface: activeIface.device)

        // ── Real-time throughput delta ───────────────────────────────────────
        let rxBytes = extractBytes(nst, iface: activeIface.device, rx: true)
        let txBytes = extractBytes(nst, iface: activeIface.device, rx: false)
        let now     = Date()
        let elapsed = now.timeIntervalSince(prevSampleTime)

        if elapsed > 0 && prevRxBytes > 0 {
            let rxDelta = rxBytes > prevRxBytes ? rxBytes - prevRxBytes : 0
            let txDelta = txBytes > prevTxBytes ? txBytes - prevTxBytes : 0
            downloadMbps = Double(rxDelta) * 8.0 / elapsed / 1_000_000
            uploadMbps   = Double(txDelta) * 8.0 / elapsed / 1_000_000
        }
        prevRxBytes    = rxBytes
        prevTxBytes    = txBytes
        prevSampleTime = now

        snap.speed.downloadMbps = downloadMbps
        snap.speed.uploadMbps   = uploadMbps
        
        // ── Gaming Latency ───────────────────────────────────────────────────
        if let timeStr = parseFirst(png, pattern: "time=([\\d.]+)\\s*ms"), let ms = Double(timeStr) {
            snap.speed.pingMs = ms
        } else if let msStr = parseFirst(png, pattern: "=\\s*[\\d.]+/([\\d.]+)/[\\d.]+/"), let ms = Double(msStr) {
            snap.speed.pingMs = ms
        }

        self.snapshot = snap
    }

    // MARK: - Parsers

    private struct ActiveIface {
        var device: String        = "—"
        var connectionType: String = "Unknown"
        var ip: String            = "—"
        var isConnected: Bool     = false
    }

    private func detectActiveInterface(ifconfigRaw: String) -> ActiveIface {
        var result = ActiveIface()
        // Split on lines starting with "en" interface blocks
        var currentIface = ""
        var currentIP = ""
        var currentStatus = false

        for line in ifconfigRaw.split(separator: "\n") {
            let s = String(line)
            if s.first?.isLetter == true && s.contains(": flags=") {
                // New interface block
                currentIface = String(s.split(separator: ":").first ?? "")
                currentIP = ""
                currentStatus = s.contains("RUNNING") && s.contains("UP")
            } else if s.contains("inet ") && !s.contains("inet6") {
                currentIP = parseFirst(s, pattern: "inet ([\\d.]+)") ?? ""
            } else if s.contains("status: active") {
                currentStatus = true
            }

            if currentStatus && !currentIP.isEmpty && currentIP != "127.0.0.1" {
                // Prefer the first active interface with a real IP
                if result.device == "—" {
                    result.device      = currentIface
                    result.ip          = currentIP
                    result.isConnected = true
                    // Classify
                    if currentIface.hasPrefix("en") && currentIface != "en0" {
                        // en0 on Mac mini is typically Ethernet but inactive; en1 is Wi-Fi
                        result.connectionType = guessConnectionType(iface: currentIface, ifconfigRaw: ifconfigRaw)
                    } else if currentIface.hasPrefix("bridge") {
                        result.connectionType = "Thunderbolt Bridge"
                    } else {
                        result.connectionType = "Unknown"
                    }
                }
            }
        }
        if !result.isConnected { result.connectionType = "No Connection" }
        return result
    }

    private func guessConnectionType(iface: String, ifconfigRaw: String) -> String {
        // en1 on Mac mini = Wi-Fi (confirmed by system_profiler SPNetworkDataType)
        // en0 = Ethernet (built-in)
        if iface == "en1" { return "Wi-Fi" }
        if iface == "en0" { return "Ethernet" }
        // Check if it has "media: autoselect" with no 802.11 → Ethernet
        return "Ethernet"
    }

    private func parseWiFiDetails(airportRaw: String, networkRaw: String) -> WiFiDetails {
        var w = WiFiDetails()

        // Parse system_profiler SPAirPortDataType
        // It shows the currently associated network block first
        var foundCurrentNetwork = false
        for line in airportRaw.split(separator: "\n") {
            let s = String(line).trimmingCharacters(in: .whitespaces)

            // Current Network Info block starts after "Current Network Information:"
            if s.contains("Current Network Information:") { foundCurrentNetwork = true }
            if !foundCurrentNetwork { continue }

            if s.hasPrefix("PHY Mode:") {
                w.phyMode = s.replacingOccurrences(of: "PHY Mode:", with: "").trimmingCharacters(in: .whitespaces)
            } else if s.hasPrefix("Channel:") {
                let chanLine = s.replacingOccurrences(of: "Channel:", with: "").trimmingCharacters(in: .whitespaces)
                w.channel = chanLine
                if chanLine.contains("2GHz")      { w.band = "2.4 GHz" }
                else if chanLine.contains("5GHz") { w.band = "5 GHz" }
                else if chanLine.contains("6GHz") { w.band = "6 GHz" }
            } else if s.hasPrefix("Security:") {
                w.security = s.replacingOccurrences(of: "Security:", with: "").trimmingCharacters(in: .whitespaces)
            } else if s.hasPrefix("Signal / Noise:") {
                let parts = s.replacingOccurrences(of: "Signal / Noise:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: "/")
                if parts.count == 2 {
                    w.signalDBm = Int(parseFirst(parts[0], pattern: "(-?\\d+)") ?? "0") ?? 0
                    w.noiseDBm  = Int(parseFirst(parts[1], pattern: "(-?\\d+)") ?? "0") ?? 0
                    w.snr       = w.signalDBm - w.noiseDBm
                }
            } else if s.hasPrefix("Transmit Rate:") {
                w.txRateMbps = Int(s.replacingOccurrences(of: "Transmit Rate:", with: "")
                    .trimmingCharacters(in: .whitespaces)) ?? 0
            } else if s.hasPrefix("Country Code:") {
                w.countryCode = s.replacingOccurrences(of: "Country Code:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        // Try to get SSID from networksetup (SPAirPortDataType doesn't expose it in all macOS versions)
        if let ssidLine = networkRaw.split(separator: "\n").first(where: { $0.contains("Current Wi-Fi Network:") }) {
            w.ssid = String(ssidLine).replacingOccurrences(of: "Current Wi-Fi Network:", with: "").trimmingCharacters(in: .whitespaces)
        }
        // Also try parsing the network name from the block header
        if w.ssid.isEmpty || w.ssid == "—" {
            // SPAirPortDataType: network name is the key before "PHY Mode:" in its sub-block
            let lines = airportRaw.split(separator: "\n").map { String($0) }
            for (i, line) in lines.enumerated() {
                if line.contains("PHY Mode:") && i > 0 {
                    let candidate = lines[i-1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ":", with: "")
                    if !candidate.isEmpty && !candidate.contains("Information") {
                        w.ssid = candidate
                    }
                    break
                }
            }
        }
        if w.ssid.isEmpty { w.ssid = "Connected" }

        // Signal quality bars (1–4)
        let rssi = w.signalDBm
        if rssi >= -50      { w.signalBars = 4; w.signalLabel = "Excellent" }
        else if rssi >= -65 { w.signalBars = 3; w.signalLabel = "Good" }
        else if rssi >= -75 { w.signalBars = 2; w.signalLabel = "Fair" }
        else                { w.signalBars = 1; w.signalLabel = "Weak" }

        return w
    }

    private func parseSpeed(netstatRaw: String, iface: String) -> NetworkSpeed {
        var s = NetworkSpeed()
        for line in netstatRaw.split(separator: "\n") {
            let parts = String(line).split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 10, String(parts[0]) == iface else { continue }
            if String(parts[2]).contains("<Link#") {
                let rx = UInt64(parts[6]) ?? 0
                let tx = UInt64(parts[9]) ?? 0
                s.totalReceivedGB = Double(rx) / 1_073_741_824
                s.totalSentGB     = Double(tx) / 1_073_741_824
            }
        }
        return s
    }

    private func extractBytes(_ netstatRaw: String, iface: String, rx: Bool) -> UInt64 {
        for line in netstatRaw.split(separator: "\n") {
            let parts = String(line).split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 10, String(parts[0]) == iface,
                  String(parts[2]).contains("<Link#") else { continue }
            return UInt64(parts[rx ? 6 : 9]) ?? 0
        }
        return 0
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

// MARK: - Network Monitor Card View

struct NetworkMonitorView: View {
    @StateObject private var monitor = NetworkMonitor()

    var connectionColor: Color {
        switch monitor.snapshot.connectionType {
        case "Wi-Fi":     return .blue
        case "Ethernet":  return .green
        default:          return .red
        }
    }

    var connectionIcon: String {
        switch monitor.snapshot.connectionType {
        case "Wi-Fi":    return "wifi"
        case "Ethernet": return "cable.connector"
        default:         return "wifi.slash"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ─────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: connectionIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(colors: [connectionColor, connectionColor.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network Monitor")
                        .font(.headline)
                    Text("Live · updates every 3 s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Connection type badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.snapshot.isConnected ? connectionColor : .red)
                        .frame(width: 7, height: 7)
                    Text(monitor.snapshot.connectionType)
                        .font(.caption.bold())
                        .foregroundColor(connectionColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(connectionColor.opacity(0.1))
                .clipShape(Capsule())
            }

            // ── Live Speed Row ─────────────────────────────────────────────
            HStack(spacing: 0) {
                // Download
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text(formatSpeed(monitor.downloadMbps))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.3), value: monitor.downloadMbps)
                        Text("Mbps")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                    Text("Download")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50)

                // Upload
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text(formatSpeed(monitor.uploadMbps))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.3), value: monitor.uploadMbps)
                        Text("Mbps")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                    Text("Upload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 50)
                
                // Gaming Latency (Ping)
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(.orange)
                        Text(monitor.snapshot.speed.pingMs == 0 ? "—" : String(format: "%.0f", monitor.snapshot.speed.pingMs))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(monitor.snapshot.speed.pingMs == 0 ? .secondary : (monitor.snapshot.speed.pingMs < 50 ? .green : (monitor.snapshot.speed.pingMs < 150 ? .orange : .red)))
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.3), value: monitor.snapshot.speed.pingMs)
                        Text("ms")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                    Text("Gaming Latency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(12)

            // ── Session totals ─────────────────────────────────────────────
            HStack(spacing: 16) {
                NetworkStatPill(
                    icon: "arrow.down.to.line",
                    label: "Total Received",
                    value: formatGB(monitor.snapshot.speed.totalReceivedGB),
                    color: .blue
                )
                NetworkStatPill(
                    icon: "arrow.up.to.line",
                    label: "Total Sent",
                    value: formatGB(monitor.snapshot.speed.totalSentGB),
                    color: .green
                )
            }

            Divider()

            // ── Connection Details Grid ────────────────────────────────────
            let snap = monitor.snapshot
            VStack(alignment: .leading, spacing: 10) {
                Text("Connection Details")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    NetDetailCell(label: "IP Address",       value: snap.ipAddress)
                    NetDetailCell(label: "Router",           value: snap.routerIP)
                    NetDetailCell(label: "Interface",        value: snap.activeInterface)
                    NetDetailCell(label: "Connection",       value: snap.connectionType)
                }
            }

            // ── Wi-Fi Section (only when on Wi-Fi) ─────────────────────────
            if snap.connectionType == "Wi-Fi" {
                Divider()
                WiFiDetailsSection(wifi: snap.wifi)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
    }

    private func formatSpeed(_ mbps: Double) -> String {
        if mbps < 0.01 { return "0.0" }
        if mbps >= 1000 { return String(format: "%.1f Gbps", mbps / 1000) }
        return String(format: "%.1f", mbps)
    }

    private func formatGB(_ gb: Double) -> String {
        if gb < 1.0 { return String(format: "%.0f MB", gb * 1024) }
        return String(format: "%.2f GB", gb)
    }
}

// MARK: - Wi-Fi Details Section

struct WiFiDetailsSection: View {
    let wifi: WiFiDetails

    var signalColor: Color {
        switch wifi.signalBars {
        case 4: return .green
        case 3: return .blue
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                Text("Wi-Fi Details")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                // SSID badge
                if wifi.ssid != "—" {
                    Text(wifi.ssid)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            // Signal strength visualizer
            HStack(alignment: .center, spacing: 16) {
                // Animated signal bars
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(1...4, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(bar <= wifi.signalBars ? signalColor : Color.gray.opacity(0.2))
                            .frame(width: 8, height: CGFloat(bar) * 7 + 4)
                            .animation(.easeOut(duration: 0.3), value: wifi.signalBars)
                    }
                }
                .frame(height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(wifi.signalLabel) Signal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(signalColor)
                    Text("\(wifi.signalDBm) dBm  •  SNR: \(wifi.snr) dB")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tx Rate
                VStack(spacing: 2) {
                    Text("\(wifi.txRateMbps)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("Mbps Link")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(signalColor.opacity(0.06))
            .cornerRadius(10)

            // Detail grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                NetDetailCell(label: "Standard",  value: wifi.phyMode)
                NetDetailCell(label: "Band",      value: wifi.band)
                NetDetailCell(label: "Channel",   value: wifi.channel)
                NetDetailCell(label: "Security",  value: wifi.security)
                NetDetailCell(label: "Noise",     value: "\(wifi.noiseDBm) dBm")
                NetDetailCell(label: "Country",   value: wifi.countryCode)
            }
        }
    }
}

// MARK: - Helper Sub-Views

struct NetworkStatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NetDetailCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}
