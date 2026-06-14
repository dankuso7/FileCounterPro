import SwiftUI
import UniformTypeIdentifiers

final class DuplicateFinderState: ObservableObject {
    @Published var isTargeted: Bool = false
}

struct DuplicateFinderView: View {
    @StateObject private var scanner = DuplicateScanner()
    @StateObject private var viewState = DuplicateFinderState()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicate Finder")
                        .font(.system(size: 28, weight: .bold))
                    Text("Securely identify and safely remove identical files.")
                        .foregroundColor(.secondary)
                }
                Spacer()

                if scanner.isScanning {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Scanning... \(Int(scanner.scanProgress * 100))%")
                            .foregroundColor(.blue)
                    }
                } else if !scanner.duplicateGroups.isEmpty {
                    Text("Wasted Space: \(formatBytes(scanner.totalWastedSpace))")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding()

            Divider()

            if scanner.duplicateGroups.isEmpty && !scanner.isScanning {
                // Drop Zone
                VStack(spacing: 20) {
                    Image(systemName: "square.on.square.dashed")
                        .font(.system(size: 60))
                        .foregroundColor(viewState.isTargeted ? .blue : .secondary)

                    Text("Drop Folder to Find Duplicates")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Button(action: selectFolder) {
                        Text("Browse Folders")
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(viewState.isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            viewState.isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 3, dash: [15])
                        )
                )
                .padding(40)
                .onDrop(of: [UTType.fileURL], isTargeted: Binding(
                    get: { viewState.isTargeted },
                    set: { viewState.isTargeted = $0 }
                )) { providers in
                    handleDrop(providers: providers)
                    return true
                }
            } else {
                // Results List
                List {
                    ForEach(scanner.duplicateGroups) { group in
                        Section {
                            ForEach(group.files, id: \.self) { fileURL in
                                HStack {
                                    Image(systemName: "doc").foregroundColor(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(fileURL.lastPathComponent)
                                            .font(.system(.body, design: .rounded))
                                        Text(fileURL.deletingLastPathComponent().path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Button(action: { scanner.trashFile(url: fileURL) }) {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            HStack {
                                Text("\(group.files.count) Exact Copies").fontWeight(.bold)
                                Spacer()
                                Text(formatBytes(group.fileSize)).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            scanner.scan(url: url)
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        // Use modern loadObject(ofClass:) API (macOS 27)
        provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async { self.scanner.scan(url: url) }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
