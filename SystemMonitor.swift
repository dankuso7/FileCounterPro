import Foundation

/// macOS 27 Golden Gate: Full async/await SystemMonitor
/// Replaces Timer + DispatchQueue.global with Swift 6 structured concurrency.
@MainActor
class SystemMonitor: ObservableObject {
    @Published var memoryUsageFormatted: String = "0%"
    @Published var cpuUsageFormatted: String = "0.0%"
    @Published var gpuUsageFormatted: String = "0%"

    private var monitorTask: Task<Void, Never>?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitorTask = Task {
            while !Task.isCancelled {
                await updateStats()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func updateStats() async {
        // Run all three shell commands concurrently on the system executor
        async let cpuResult = shellString("top -l 2 -n 0 -s 1 | grep '^CPU usage:' | tail -1 | awk '{print $7}' | sed 's/%//'")
        async let gpuResult = shellString("ioreg -c IOAccelerator -r -l | grep -i 'PerformanceStatistics' | grep -o '\"Device Utilization %\"=[0-9]*' | grep -o '[0-9]*'")
        async let ramResult = shellString("vm_stat | awk '/Pages free/ {free=$3+0} /Pages active/ {active=$3+0} /Pages inactive/ {inactive=$3+0} /Pages speculative/ {spec=$3+0} /Pages wired down/ {wired=$4+0} /Pages purgeable/ {purge=$3+0} /Pages occupied by compressor/ {comp=$5+0} END {used = active + wired + comp + spec; total = used + free + inactive + purge; print (used/total)*100}'")

        let (cpu, gpu, ram) = await (cpuResult, gpuResult, ramResult)

        if let idle = Double(cpu.trimmingCharacters(in: .whitespacesAndNewlines)) {
            cpuUsageFormatted = String(format: "%.1f%%", max(0, 100.0 - idle))
        }
        if let g = Int(gpu.trimmingCharacters(in: .whitespacesAndNewlines)) {
            gpuUsageFormatted = "\(min(100, g))%"
        }
        if let r = Double(ram.trimmingCharacters(in: .whitespacesAndNewlines)) {
            memoryUsageFormatted = "\(Int(r))%"
        }
    }

    deinit {
        monitorTask?.cancel()
    }
}

/// Lightweight async shell helper — avoids allocating a new DispatchQueue per call
func shellString(_ cmd: String) async -> String {
    await withCheckedContinuation { continuation in
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // suppress stderr noise
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
        } catch {
            continuation.resume(returning: "")
        }
    }
}
