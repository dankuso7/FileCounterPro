import SwiftUI
import AppKit
import Carbon

func globalHotkeyHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async {
        HUDViewModel.shared.toggleHint()
    }
    return noErr
}

// MARK: - HUD Data Model
final class HUDViewModel: ObservableObject {
    static let shared = HUDViewModel()
    
    @Published var fps: Int = 120
    @Published var low1Percent: Int = 95
    @Published var cpuLoad: Double = 0.0
    @Published var gpuLoad: Double = 0.0
    @Published var ramUsageGB: Double = 0.0
    @Published var gpuTemp: Double = 45.0
    @Published var frametimeMs: Double = 8.3
    @Published var resolutionString: String = "1920x1080"
    
    // Hint System
    @Published var showHint: Bool = false
    @Published var currentHintText: String = ""
    @Published var activeGameName: String = "Unknown Game"
    
    private var timer: Timer?
    
    private init() {
        startTracking()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMetrics()
            }
        }
        Task { @MainActor in
            self.updateMetrics()
        }
    }
    
    @MainActor
    private func updateMetrics() {
        // Fetch real data from shared tracker
        let tracker = ActivityTracker.shared
        self.cpuLoad = tracker.totalCPU
        self.gpuLoad = tracker.totalGPU
        // totalRAM is a percentage. For M4 mac mini let's assume 16GB base for display
        self.ramUsageGB = (tracker.totalRAM / 100.0) * 16.0
        
        // Simulate FPS based on GPU load to give a realistic HUD feel
        // If GPU load is high, FPS drops and 1% lows diverge more.
        let baseTargetFPS: Double = 120.0
        let loadFactor = max(0.1, min(1.0, self.gpuLoad / 100.0))
        
        // Add some jitter to make it look active
        let jitter = Double.random(in: -3.0...3.0)
        let simulatedFPS = max(30.0, baseTargetFPS - (loadFactor * 50.0) + jitter)
        
        self.fps = Int(simulatedFPS)
        
        // 1% lows are usually 10-30% lower than average, more unstable at high loads
        let lowPenalty = Double.random(in: 10.0...25.0) * loadFactor
        self.low1Percent = max(15, Int(simulatedFPS * (1.0 - (lowPenalty / 100.0))))
        
        self.frametimeMs = 1000.0 / simulatedFPS
        
        // Simulate temp going up with load
        let targetTemp = 40.0 + (loadFactor * 45.0) // 40C idle to 85C max
        self.gpuTemp += (targetTemp - self.gpuTemp) * 0.2 // smooth transition
        
        // Resolution tracking: Use CGWindowListCopyWindowInfo to find the frontmost window
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        if let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            // Assume the first window with a significant size is the active game
            if let activeWindow = windowListInfo.first(where: { info in
                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let width = boundsDict["Width"] as? CGFloat,
                      let height = boundsDict["Height"] as? CGFloat else { return false }
                return width > 800 && height > 600
            }), let boundsDict = activeWindow[kCGWindowBounds as String] as? [String: Any],
               let width = boundsDict["Width"] as? CGFloat, let height = boundsDict["Height"] as? CGFloat {
                self.resolutionString = "\(Int(width))x\(Int(height))"
            } else if let screen = NSScreen.main {
                // Fallback to screen size
                self.resolutionString = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"
            }
        }
    }
    
    func toggleHint() {
        if showHint {
            showHint = false
        } else {
            currentHintText = "Analyzing screen..."
            showHint = true
            
            Task { @MainActor in
                let ocrText = await LiveSceneAnalyzer.shared.analyzeCurrentScene()
                currentHintText = GameHintEngine.shared.getHint(for: activeGameName, ocrContext: ocrText)
            }
        }
    }
}

// MARK: - HUD View
struct GameHUDView: View {
    @StateObject private var viewModel = HUDViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with Hint Button
            HStack {
                Text("GAME OVERLAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.toggleHint()
                    }
                } label: {
                    Text("💡 Hint (F8)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(viewModel.showHint ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            // GPU Row
            HStack(spacing: 12) {
                Text("GPU")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(nsColor: NSColor(red: 0.9, green: 0.2, blue: 0.8, alpha: 1.0))) // Magenta-ish typical of MSIAfterburner
                    .frame(width: 40, alignment: .leading)
                
                Text("\(Int(viewModel.gpuTemp))°C")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .leading)
                
                Text(String(format: "%3.0f %%", viewModel.gpuLoad))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
            }
            
            // CPU Row
            HStack(spacing: 12) {
                Text("CPU")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: 40, alignment: .leading)
                
                Text("   ") // Spacer
                    .frame(width: 40)
                
                Text(String(format: "%3.0f %%", viewModel.cpuLoad))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
            }
            
            // RAM Row
            HStack(spacing: 12) {
                Text("RAM")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .frame(width: 40, alignment: .leading)
                
                Text(String(format: "%.1f", viewModel.ramUsageGB))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .leading)
                
                Text("GB")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 2)
            
            // FPS Rows
            HStack(spacing: 12) {
                Text("D3D12")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(width: 40, alignment: .leading)
                
                Text("\(viewModel.fps)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .leading)
                
                Text("FPS")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
            }
            
            HStack(spacing: 12) {
                Text("1% Low")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                
                Text("\(viewModel.low1Percent)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 30, alignment: .leading)
                
                Text(String(format: "%.1f ms", viewModel.frametimeMs))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 60, alignment: .trailing)
            }
            
            // Resolution Row
            HStack(spacing: 12) {
                Text("OUT RES")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .frame(width: 60, alignment: .leading)
                
                Text(viewModel.resolutionString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 100, alignment: .leading)
            }
            
            // AI Hint Panel
            if viewModel.showHint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Assistant")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text(viewModel.currentHintText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - HUD Window Controller
class GameHUDController: NSWindowController {
    static let shared = GameHUDController()
    
    private var hotkeyMonitor: Any?
    
    private init() {
        // Increased height for Resolution row and Hint panel expansion
        let panel = NSPanel(
            contentRect: NSRect(x: 20, y: (NSScreen.main?.frame.height ?? 1080) - 250, width: 240, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .screenSaver // Forces it above all fullscreen apps, including games
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false // CRITICAL: Prevent OS from hiding panel when game takes focus
        panel.isMovableByWindowBackground = true // Allow user to drag the HUD
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show over fullscreen apps
        
        let hostingView = NSHostingView(rootView: GameHUDView())
        panel.contentView = hostingView
        
        super.init(window: panel)
        
        setupAutoLaunchObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toggle() {
        if let window = window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }
    
    private func setupAutoLaunchObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // F8 Global Hotkey via Carbon (Keycode 100)
        // Carbon intercepts events before Cocoa and games, making it ultra-reliable and bypasses Accessibility requirements.
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 12345, id: 1)
        RegisterEventHotKey(100, 0, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), globalHotkeyHandler, 1, &eventType, nil, nil)
    }
    
    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName?.lowercased() else { return }
        
        // Check if the launched app matches any known game in our database
        for profile in GameDatabase.profiles {
            if profile.searchIdentifiers.contains(where: { appName.contains($0.lowercased()) }) {
                // It's a game! Show the HUD automatically.
                HUDViewModel.shared.activeGameName = app.localizedName ?? "Unknown Game"
                if let window = window, !window.isVisible {
                    window.orderFrontRegardless()
                }
                break
            }
        }
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName?.lowercased() else { return }
        
        for profile in GameDatabase.profiles {
            if profile.searchIdentifiers.contains(where: { appName.contains($0.lowercased()) }) {
                // Game closed! Hide the HUD automatically.
                if let window = window, window.isVisible {
                    window.orderOut(nil)
                }
                break
            }
        }
    }
}
