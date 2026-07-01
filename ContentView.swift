import SwiftUI
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case duplicateFinder = "Duplicate Finder"
    case virusScanner = "Virus Scanner"
    case activityMonitor = "Activity Monitor"
    case smartUninstaller = "Smart Uninstaller"
    case systemJunk = "System Junk"
    case macGaming = "Mac Gaming"
    case zipCreator = "Zip Creator"
    var id: String { self.rawValue }
}

final class ContentViewState: ObservableObject {
    @Published var selectedTab: AppTab? = .virusScanner
    @Published var selectedItemForAI: FileItem? = nil
    @Published var selectedDriveForDetails: DriveInfo? = nil
}

struct ContentView: View {
    @StateObject private var vs = ContentViewState()
    @StateObject private var diskMonitor = DiskMonitor()
    @StateObject private var driveCleaner = DriveCleaner()
    
    // Convenience bindings
    var selectedTab: AppTab? { vs.selectedTab }
    var selectedItemForAI: FileItem? { vs.selectedItemForAI }
    var selectedDriveForDetails: DriveInfo? { vs.selectedDriveForDetails }
    var bSelectedTab: Binding<AppTab?> { Binding(get: { vs.selectedTab }, set: { vs.selectedTab = $0 }) }
    var bSelectedItemForAI: Binding<FileItem?> { Binding(get: { vs.selectedItemForAI }, set: { vs.selectedItemForAI = $0 }) }
    var bSelectedDriveForDetails: Binding<DriveInfo?> { Binding(get: { vs.selectedDriveForDetails }, set: { vs.selectedDriveForDetails = $0 }) }

    var body: some View {
        NavigationSplitView {
            // Left Sidebar - Sci-Fi Navigation
            ZStack {
                SciFi.bgDeep
                
                List(selection: bSelectedTab) {
                    Section {
                        sidebarLink(.dashboard, icon: "chart.bar.fill", color: SciFi.neonCyan)
                        sidebarLink(.duplicateFinder, icon: "square.on.square.dashed", color: SciFi.neonPurple)
                        sidebarLink(.virusScanner, icon: "shield.checkerboard", color: SciFi.neonMagenta)
                        sidebarLink(.activityMonitor, icon: "cpu", color: SciFi.neonOrange)
                        sidebarLink(.smartUninstaller, icon: "trash", color: SciFi.neonMagenta)
                        sidebarLink(.systemJunk, icon: "externaldrive.badge.xmark", color: SciFi.neonGreen)
                        sidebarLink(.macGaming, icon: "gamecontroller.fill", color: SciFi.neonOrange)
                        sidebarLink(.zipCreator, icon: "archivebox.fill", color: SciFi.neonCyan)
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(SciFi.neonCyan)
                                .font(.system(size: 10))
                            Text("FILE COUNTER PRO")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(SciFi.neonCyan)
                            Image(systemName: "diamond.fill")
                                .foregroundColor(SciFi.neonCyan)
                                .font(.system(size: 10))
                        }
                        .padding(.top, 24)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            
        } detail: {
            ZStack {
                SciFi.bgDeep.ignoresSafeArea()
                
                Group {
                    if selectedTab == .dashboard {
                        DashboardView(selectedItemForAI: bSelectedItemForAI)
                    } else if selectedTab == .duplicateFinder {
                        DuplicateFinderView()
                    } else if selectedTab == .virusScanner {
                        VirusScannerView()
                    } else if selectedTab == .activityMonitor {
                        ActivityMonitorView()
                    } else if selectedTab == .smartUninstaller {
                        SmartUninstallerView()
                    } else if selectedTab == .systemJunk {
                        SystemJunkView()
                    } else if selectedTab == .macGaming {
                        MacGamingEstimatorView()
                    } else if selectedTab == .zipCreator {
                        ZipCreatorView()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundColor(SciFi.neonCyan.opacity(0.4))
                            Text("Select a module from the sidebar")
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(SciFi.textDim)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button(action: {
                            vs.selectedTab = .activityMonitor
                        }) {
                            SystemStatsPill()
                        }
                        .buttonStyle(.plain)
                        .help("Open Activity Monitor")
                        
                        Divider().frame(height: 20)
                        
                        if diskMonitor.drives.isEmpty {
                            ProgressView().scaleEffect(0.5)
                        } else {
                            ForEach(diskMonitor.drives) { drive in
                                Button(action: {
                                    vs.selectedDriveForDetails = drive
                                }) {
                                    HStack(spacing: 8) {
                                        Text(drive.name.prefix(1).uppercased())
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.black)
                                            .frame(width: 16, height: 16)
                                            .background(SciFi.neonCyan)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.1))
                                                    .frame(width: 60, height: 6)
                                                
                                                Capsule()
                                                    .fill(LinearGradient(gradient: Gradient(colors: [SciFi.neonCyan, SciFi.neonPurple]), startPoint: .leading, endPoint: .trailing))
                                                    .frame(width: max(0, 60 * CGFloat(drive.usagePercentage)), height: 6)
                                            }
                                            Text("\(drive.freeSpaceFormatted) free")
                                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                                .foregroundColor(SciFi.textDim)
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(vs.selectedDriveForDetails?.id == drive.id ? SciFi.neonCyan.opacity(0.15) : Color.white.opacity(0.05))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(SciFi.neonCyan.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .popover(item: bSelectedDriveForDetails) { drive in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: drive.path == "/" ? "internaldrive.fill" : "externaldrive.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(SciFi.neonCyan)
                                Text(drive.name)
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            Divider().background(SciFi.border)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("STORAGE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(SciFi.textDim)
                                    Spacer()
                                    Text("\(drive.usedSpaceFormatted) / \(drive.totalSpaceFormatted)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(gradient: Gradient(colors: [SciFi.neonCyan, SciFi.neonPurple]), startPoint: .leading, endPoint: .trailing))
                                            .frame(width: max(0, geometry.size.width * CGFloat(drive.usagePercentage)), height: 8)
                                            .shadow(color: SciFi.neonCyan.opacity(0.5), radius: 4)
                                    }
                                }
                                .frame(height: 8)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("HEALTH (S.M.A.R.T)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(SciFi.textDim)
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(drive.smartStatus == "Verified" ? SciFi.neonGreen : (drive.smartStatus.contains("Not Supported") ? Color.gray : SciFi.neonMagenta))
                                            .frame(width: 8, height: 8)
                                            .shadow(color: (drive.smartStatus == "Verified" ? SciFi.neonGreen : SciFi.neonMagenta).opacity(0.6), radius: 4)
                                        
                                        Text(drive.smartStatus)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    vs.selectedDriveForDetails = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        driveCleaner.prepareToClean(driveName: drive.name, drivePath: drive.path)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                        Text("Smart Clean")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(SciFi.neonCyan.opacity(0.15))
                                    .foregroundColor(SciFi.neonCyan)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(SciFi.neonCyan.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                        .frame(width: 300)
                        .background(SciFi.bgPanel)
                    }
                }
            }
        }
        .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 650)
        .popover(item: bSelectedItemForAI) { (item: FileItem) in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(SciFi.neonPurple)
                    Text("AI PRO ANALYSIS")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(SciFi.neonPurple)
                }
                
                Text("File: \(item.name)")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(SciFi.textDim)
                
                Divider().background(SciFi.border)
                
                if let explanation = item.aiExplanation {
                    Text(LocalizedStringKey(explanation))
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.white)
                }
            }
            .padding(20)
            .frame(width: 350)
            .background(SciFi.bgPanel)
        }
        .sheet(isPresented: $driveCleaner.isShowingModal) {
            VStack(spacing: 20) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(SciFi.neonCyan)
                    .shadow(color: SciFi.neonCyan.opacity(0.5), radius: 10)
                
                Text("SMART DRIVE CLEANER")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if driveCleaner.hasFinished {
                    Text("Successfully cleaned \(driveCleaner.targetDriveName)!")
                        .foregroundColor(SciFi.neonGreen)
                        .font(.system(.body, design: .monospaced))
                    Button("Done") {
                        driveCleaner.isShowingModal = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SciFi.neonCyan)
                } else {
                    Text("Scanning \(driveCleaner.targetDriveName) for unwanted caches, logs, and trash...")
                        .multilineTextAlignment(.center)
                        .foregroundColor(SciFi.textDim)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Potential Savings: \(driveCleaner.junkSizeFormatted)")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(driveCleaner.junkSizeFormatted == "Calculating..." ? SciFi.textDim : SciFi.neonGreen)
                    
                    if driveCleaner.isCleaning {
                        ProgressView("Cleaning...")
                            .tint(SciFi.neonCyan)
                    } else {
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                driveCleaner.isShowingModal = false
                            }
                            
                            Button("Confirm Delete") {
                                driveCleaner.confirmClean {
                                    diskMonitor.refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(SciFi.neonMagenta)
                            .disabled(driveCleaner.junkSizeFormatted == "Calculating..." || driveCleaner.junkSizeFormatted == "Zero KB" || driveCleaner.junkSizeFormatted == "0 bytes")
                        }
                    }
                }
            }
            .padding(30)
            .frame(width: 400)
            .background(SciFi.bgPanel)
        }
    }
    
    @ViewBuilder
    func sidebarLink(_ tab: AppTab, icon: String, color: Color) -> some View {
        NavigationLink(value: tab) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: selectedTab == tab ? 6 : 0)
                Text(tab.rawValue)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTab == tab ? .white : SciFi.textDim)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - System Stats Pill (Sci-Fi)

struct SystemStatsPill: View {
    @StateObject private var systemMonitor = SystemMonitor()

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("CPU: \(systemMonitor.cpuUsageFormatted)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonCyan)
                Text("GPU: \(systemMonitor.gpuUsageFormatted)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonPurple)
                Text("RAM: \(systemMonitor.memoryUsageFormatted)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(SciFi.neonOrange)
            }
            Image(systemName: "memorychip")
                .font(.system(size: 14))
                .foregroundColor(SciFi.neonCyan)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(SciFi.bgCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(SciFi.neonCyan.opacity(0.3), lineWidth: 1))
        .shadow(color: SciFi.neonCyan.opacity(0.2), radius: 6)
        .drawingGroup()
    }
}

// MARK: - Dashboard View (Sci-Fi)
final class DashboardViewState: ObservableObject {
    @Published var isTargeted: Bool = false
}

struct DashboardView: View {
    @StateObject private var fileCounter = FileCounter()
    @StateObject private var dvs = DashboardViewState()
    @Binding var selectedItemForAI: FileItem?
    
    var bIsTargeted: Binding<Bool> { Binding(get: { dvs.isTargeted }, set: { dvs.isTargeted = $0 }) }
    
    var body: some View {
        HStack(spacing: 0) {
            // Drop Zone - Sci-Fi Panel
            VStack(spacing: 30) {
                Spacer()
                
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(SciFi.neonCyan.opacity(0.3), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .shadow(color: SciFi.neonCyan.opacity(0.4), radius: 12)
                    
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [SciFi.neonCyan.opacity(0.3), SciFi.neonPurple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(SciFi.neonCyan)
                        .shadow(color: SciFi.neonCyan.opacity(0.6), radius: 8)
                }
                
                VStack(spacing: 8) {
                    Text("FOLDER ANALYZER")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("Drag & drop any folder or app")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(SciFi.textDim)
                        .multilineTextAlignment(.center)
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(dvs.isTargeted ? SciFi.neonCyan : SciFi.border, style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .background(dvs.isTargeted ? SciFi.neonCyan.opacity(0.08) : Color.clear)
                        .animation(.easeInOut(duration: 0.2), value: dvs.isTargeted)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 30))
                            .foregroundColor(dvs.isTargeted ? SciFi.neonCyan : SciFi.textDim)
                            .shadow(color: dvs.isTargeted ? SciFi.neonCyan.opacity(0.6) : .clear, radius: 8)
                        Text("Drop Here")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(dvs.isTargeted ? SciFi.neonCyan : SciFi.textDim)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .onDrop(of: [UTType.fileURL], isTargeted: bIsTargeted) { providers in
                    handleDrop(providers: providers)
                }
                
                Button(action: selectFolder) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("Browse Files")
                    }
                    .font(.system(.headline, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(SciFi.neonCyan)
                .controlSize(.large)
                .disabled(fileCounter.isCounting)
                
                Spacer()
            }
            .padding(30)
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 350)
            .frame(maxHeight: .infinity)
            .background(SciFi.bgPanel)
            
            // Thin neon divider
            Rectangle()
                .fill(SciFi.neonCyan.opacity(0.3))
                .frame(width: 1)
                .shadow(color: SciFi.neonCyan.opacity(0.3), radius: 3)
            
            // Results
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANALYSIS RESULTS")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if fileCounter.isCounting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(SciFi.neonCyan)
                                Text("Scanning \(fileCounter.count) files...")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(SciFi.neonCyan)
                            }
                        } else {
                            Text(fileCounter.count > 0 ? "Total files found: \(fileCounter.count)" : "Awaiting input...")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(SciFi.textDim)
                        }
                    }
                    Spacer()
                }
                .padding(24)
                .background(SciFi.bgPanel)
                
                Rectangle().fill(SciFi.border).frame(height: 1)
                
                if fileCounter.files.isEmpty && !fileCounter.isCounting {
                    VStack {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(SciFi.neonCyan.opacity(0.2))
                            .shadow(color: SciFi.neonCyan.opacity(0.1), radius: 10)
                            .padding(.bottom, 10)
                        Text("No files to display")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(SciFi.textDim)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SciFi.bgDeep)
                } else {
                    List {
                        ForEach(fileCounter.files) { item in
                            HStack(spacing: 12) {
                                categoryIcon(for: item.category)
                                    .frame(width: 20)
                                
                                Text(item.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Text(item.formattedSize)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(SciFi.textDim)
                                
                                if item.aiExplanation != nil {
                                    Button(action: {
                                        selectedItemForAI = item
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                            Text("AI Pro")
                                        }
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(LinearGradient(gradient: Gradient(colors: [SciFi.neonPurple, SciFi.neonCyan]), startPoint: .leading, endPoint: .trailing))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .shadow(color: SciFi.neonPurple.opacity(0.4), radius: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(SciFi.bgRow)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .background(SciFi.bgDeep)
                }
            }
            .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true 
        
        if panel.runModal() == .OK, let url = panel.url {
            fileCounter.countFiles(at: url)
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async { self.fileCounter.countFiles(at: url) }
            }
        }
        return true
    }
    
    @ViewBuilder
    func categoryIcon(for category: FileCategory) -> some View {
        switch category {
        case .good:
            Image(systemName: "doc.fill")
                .foregroundColor(SciFi.neonGreen)
                .shadow(color: SciFi.neonGreen.opacity(0.5), radius: 3)
        case .important:
            Image(systemName: "gearshape.fill")
                .foregroundColor(SciFi.neonOrange)
                .shadow(color: SciFi.neonOrange.opacity(0.5), radius: 3)
        case .malicious:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(SciFi.neonMagenta)
                .shadow(color: SciFi.neonMagenta.opacity(0.5), radius: 3)
        case .unknown:
            Image(systemName: "doc")
                .foregroundColor(SciFi.textDim)
        }
    }
}

// MARK: - Virus Scanner View (Sci-Fi)
final class VirusScannerViewState: ObservableObject {
    @Published var isTargeted: Bool = false
    @Published var selectedResultForAI: ScanResult? = nil
}

struct VirusScannerView: View {
    @StateObject private var scanner = LargeFileScanner()
    @StateObject private var vvs = VirusScannerViewState()
    
    var bIsTargeted: Binding<Bool> { Binding(get: { vvs.isTargeted }, set: { vvs.isTargeted = $0 }) }
    var bSelectedResultForAI: Binding<ScanResult?> { Binding(get: { vvs.selectedResultForAI }, set: { vvs.selectedResultForAI = $0 }) }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("DEEP VIRUS SCANNER")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Scan massive files with zero memory overhead")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(SciFi.textDim)
                    .multilineTextAlignment(.center)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(vvs.isTargeted ? SciFi.neonMagenta : SciFi.border, style: StrokeStyle(lineWidth: 2, dash: [15]))
                    .background(vvs.isTargeted ? SciFi.neonMagenta.opacity(0.06) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: vvs.isTargeted)
                    .shadow(color: vvs.isTargeted ? SciFi.neonMagenta.opacity(0.3) : .clear, radius: 12)
                
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 60))
                        .foregroundColor(vvs.isTargeted ? SciFi.neonMagenta : SciFi.textDim)
                        .shadow(color: vvs.isTargeted ? SciFi.neonMagenta.opacity(0.6) : .clear, radius: 10)
                    
                    Text(scanner.isScanning ? "SCANNING: \(scanner.scannedFileName)..." : "Drop File Here")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if scanner.isScanning {
                        ProgressView(value: scanner.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: SciFi.neonMagenta))
                            .frame(maxWidth: 250)
                            .shadow(color: SciFi.neonMagenta.opacity(0.4), radius: 4)
                        Text("\(Int(scanner.scanProgress * 100))%")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(SciFi.neonMagenta)
                    } else {
                        HStack(spacing: 16) {
                            Button(action: selectDrive) {
                                HStack(spacing: 8) {
                                    Image(systemName: "externaldrive.badge.plus")
                                    Text("Select File")
                                }
                                .font(.system(.headline, design: .monospaced))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(SciFi.textDim.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { scanner.scanFullSystem() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.shield.fill")
                                    Text("Full System Scan")
                                }
                                .font(.system(.headline, design: .monospaced))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(SciFi.neonMagenta.opacity(0.1))
                                .foregroundColor(SciFi.neonMagenta)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(SciFi.neonMagenta.opacity(0.5), lineWidth: 1))
                                .shadow(color: SciFi.neonMagenta.opacity(0.4), radius: 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
            .frame(height: 300)
            .onDrop(of: [UTType.fileURL], isTargeted: bIsTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            if !scanner.scanResults.isEmpty || scanner.scanComplete {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: scanner.isScanning ? "arrow.triangle.2.circlepath.circle.fill" : (scanner.isClean ? "checkmark.seal.fill" : "xmark.shield.fill"))
                            .foregroundColor(scanner.isScanning ? SciFi.neonCyan : (scanner.isClean ? SciFi.neonGreen : SciFi.neonMagenta))
                            .font(.system(size: 30))
                            .shadow(color: (scanner.isScanning ? SciFi.neonCyan : (scanner.isClean ? SciFi.neonGreen : SciFi.neonMagenta)).opacity(0.6), radius: 8)
                            .symbolEffect(.pulse, options: .repeating, isActive: scanner.isScanning)
                        Text(scanner.isScanning ? "Scanning... (\(scanner.scanResults.count) checked)" : (scanner.isClean ? "ALL FILES CLEAN" : "THREATS DETECTED"))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(scanner.isScanning ? SciFi.neonCyan : (scanner.isClean ? SciFi.neonGreen : SciFi.neonMagenta))
                    }
                    
                    List(scanner.scanResults) { result in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: result.isMalicious ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(result.isMalicious ? SciFi.neonMagenta : SciFi.neonGreen)
                                .font(.system(size: 16))
                                .shadow(color: (result.isMalicious ? SciFi.neonMagenta : SciFi.neonGreen).opacity(0.5), radius: 4)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.fileName)
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(result.filePath)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(SciFi.textDim)
                                
                                if result.isMalicious {
                                    HStack {
                                        ForEach(result.signs, id: \.self) { sign in
                                            Text(sign)
                                                .font(.system(.caption2, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(SciFi.neonMagenta.opacity(0.2))
                                                .foregroundColor(SciFi.neonMagenta)
                                                .cornerRadius(4)
                                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(SciFi.neonMagenta.opacity(0.4), lineWidth: 1))
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if result.aiExplanation != nil {
                                            Button(action: {
                                                vvs.selectedResultForAI = result
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "sparkles")
                                                    Text("AI Threat Analysis")
                                                }
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(LinearGradient(gradient: Gradient(colors: [SciFi.neonPurple, SciFi.neonMagenta]), startPoint: .leading, endPoint: .trailing))
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        
                                        Button(action: {
                                            scanner.revealInFinder(result)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "folder.fill")
                                                Text("Show in Finder")
                                            }
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(SciFi.neonCyan.opacity(0.2))
                                            .foregroundColor(SciFi.neonCyan)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SciFi.neonCyan.opacity(0.4), lineWidth: 1))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: {
                                            scanner.deleteThreat(result)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "trash.fill")
                                                Text("Delete File")
                                            }
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(SciFi.neonMagenta.opacity(0.2))
                                            .foregroundColor(SciFi.neonMagenta)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SciFi.neonMagenta.opacity(0.4), lineWidth: 1))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(SciFi.bgRow)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 250)
                    .background(SciFi.bgCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(SciFi.border, lineWidth: 1))
                }
                .padding()
                .background(scanner.isScanning ? SciFi.neonCyan.opacity(0.03) : (scanner.isClean ? SciFi.neonGreen.opacity(0.03) : SciFi.neonMagenta.opacity(0.03)))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(scanner.isScanning ? SciFi.neonCyan.opacity(0.2) : (scanner.isClean ? SciFi.neonGreen.opacity(0.2) : SciFi.neonMagenta.opacity(0.2)), lineWidth: 1))
                .transition(.opacity)
            } else {
                Spacer().frame(height: 80)
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SciFi.bgDeep)
        .popover(item: bSelectedResultForAI) { (result: ScanResult) in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(SciFi.neonPurple)
                    Text("AI THREAT ANALYSIS")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(SciFi.neonPurple)
                }
                
                Text("File: \(result.fileName)")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(SciFi.textDim)
                
                Divider().background(SciFi.border)
                
                if let explanation = result.aiExplanation {
                    Text(LocalizedStringKey(explanation))
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.white)
                }
            }
            .padding(20)
            .frame(width: 400)
            .background(SciFi.bgPanel)
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url { self.scanner.scanFile(at: url) }
        }
    }
    
    func selectDrive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            scanner.scanFile(at: url)
        }
    }
}

// MARK: - Visual Effect
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
