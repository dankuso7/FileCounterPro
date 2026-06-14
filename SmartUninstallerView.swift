import SwiftUI

// -- Cyberpunk color palette --
private let cyberBase = Color(red: 0.06, green: 0.06, blue: 0.12)
private let cyberPanel = Color(red: 0.1, green: 0.1, blue: 0.18)
private let cyberSurface = Color(red: 0.12, green: 0.12, blue: 0.22)
private let neonCyan = Color(red: 0, green: 0.9, blue: 1)
private let neonMagenta = Color(red: 1, green: 0, blue: 0.6)
private let neonGreen = Color(red: 0, green: 1, blue: 0.5)
private let neonPurple = Color(red: 0.6, green: 0.2, blue: 1)
private let neonRed = Color(red: 1, green: 0.15, blue: 0.2)
private let textPrimary = Color.white
private let textSecondary = Color.white.opacity(0.55)

final class SmartUninstallerViewState: ObservableObject {
    @Published var selectedApp: InstalledApp? = nil
    @Published var showingConfirmation = false
}

struct SmartUninstallerView: View {
    @StateObject private var uninstaller = SmartUninstaller()
    @StateObject private var viewState = SmartUninstallerViewState()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart App Uninstaller & Cleaner")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(neonCyan)
                        .shadow(color: neonCyan.opacity(0.5), radius: 8)
                    Text("Deep scan installed applications and safely clear up system trash.")
                        .foregroundColor(textSecondary)
                }
                Spacer()

                // Trash Module
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Trash Bin")
                        .font(.headline)
                        .foregroundColor(neonRed)
                        .shadow(color: neonRed.opacity(0.4), radius: 4)
                    HStack {
                        Text(formatBytes(uninstaller.trashSize))
                            .font(.system(.title2, design: .monospaced).bold())
                            .foregroundColor(uninstaller.trashSize > 1024 * 1024 * 100 ? neonMagenta : textPrimary)
                        Button("Empty Trash") {
                            Task {
                                _ = await uninstaller.emptyTrash()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(neonMagenta)
                        .disabled(uninstaller.trashSize == 0)
                    }
                }
                .padding(12)
                .background(neonRed.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(neonRed.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: neonRed.opacity(0.25), radius: 8)

                Button(action: {
                    uninstaller.scanApplications()
                }) {
                    Label(uninstaller.apps.isEmpty ? "Scan Now" : "Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(neonCyan)
                .controlSize(.large)
                .disabled(uninstaller.isScanning)
            }
            .padding(30)
            .background(cyberPanel)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(neonCyan.opacity(0.2)),
                alignment: .bottom
            )

            if uninstaller.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(neonCyan)
                    Text(uninstaller.scanProgress)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(neonCyan.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(cyberBase)
            } else if uninstaller.apps.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(neonPurple.opacity(0.6))
                        .shadow(color: neonPurple.opacity(0.4), radius: 10)
                    Text("Click 'Scan Now' to find installed applications.")
                        .foregroundColor(textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(cyberBase)
            } else {
                // Split View for Apps and Details
                HStack(spacing: 0) {
                    // Apps List
                    List(selection: Binding(
                        get: { viewState.selectedApp },
                        set: { viewState.selectedApp = $0 }
                    )) {
                        ForEach(uninstaller.apps) { app in
                            AppRowView(app: app)
                                .tag(app)
                                .listRowBackground(
                                    viewState.selectedApp == app
                                        ? neonCyan.opacity(0.12)
                                        : Color.clear
                                )
                                .padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(cyberBase)
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

                    // Neon divider
                    Rectangle()
                        .fill(neonCyan.opacity(0.25))
                        .frame(width: 1)

                    // Detail Pane
                    if let app = viewState.selectedApp {
                        AppDetailView(
                            app: app,
                            onUninstall: {
                                viewState.showingConfirmation = true
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack {
                            Text("Select an application to view details")
                                .foregroundColor(textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(cyberBase)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cyberBase)
        .onAppear {
            if uninstaller.apps.isEmpty && !uninstaller.isScanning {
                uninstaller.scanApplications()
            }
        }
        .alert("Uninstall \(viewState.selectedApp?.name ?? "App")?", isPresented: Binding(
            get: { viewState.showingConfirmation },
            set: { viewState.showingConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                if let app = viewState.selectedApp {
                    Task {
                        let success = await uninstaller.uninstall(app: app)
                        if success {
                            await MainActor.run {
                                viewState.selectedApp = nil
                                uninstaller.scanApplications()
                            }
                        }
                    }
                }
            }
        } message: {
            if let app = viewState.selectedApp {
                Text("This will move the application and \(app.leftoverFiles.count) leftover cache/preference files to the Trash. This action cannot be undone.")
            }
        }
    }
}

// MARK: - App Row View

struct AppRowView: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
            // App icon with faint glow ring
            ZStack {
                Circle()
                    .stroke(neonCyan.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 46, height: 46)
                    .shadow(color: neonCyan.opacity(0.3), radius: 6)

                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(neonPurple.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.headline)
                    .foregroundColor(textPrimary)
                    .lineLimit(1)

                Text(formatBytes(app.totalSize))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(neonCyan.opacity(0.7))
            }
            Spacer()
        }
    }
}

// MARK: - App Detail View

struct AppDetailView: View {
    let app: InstalledApp
    let onUninstall: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Profile
                HStack(alignment: .top, spacing: 20) {
                    if let icon = app.icon {
                        ZStack {
                            Circle()
                                .stroke(neonPurple.opacity(0.35), lineWidth: 2)
                                .frame(width: 102, height: 102)
                                .shadow(color: neonPurple.opacity(0.4), radius: 10)

                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        Text(app.bundleId)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(textSecondary)
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            BadgeView(text: formatBytes(app.totalSize), icon: "internaldrive.fill", color: neonCyan)
                            BadgeView(text: "\(app.leftoverFiles.count) Leftovers", icon: "doc.on.doc.fill", color: .orange)
                        }
                        .padding(.top, 4)
                    }
                    Spacer()

                    // Uninstall button with magenta glow
                    Button(role: .destructive, action: onUninstall) {
                        Label("Uninstall", systemImage: "trash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(neonMagenta)
                    .controlSize(.large)
                    .shadow(color: neonMagenta.opacity(0.5), radius: 8)
                }
                .padding()
                .background(cyberPanel)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(neonPurple.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: neonPurple.opacity(0.15), radius: 8, y: 2)

                // Leftover Files List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Associated Files")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(neonCyan)
                        .shadow(color: neonCyan.opacity(0.3), radius: 4)

                    if app.leftoverFiles.isEmpty {
                        Text("No leftover application support or cache files found.")
                            .foregroundColor(textSecondary)
                            .font(.subheadline)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(app.leftoverFiles, id: \.self) { leftover in
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(neonCyan.opacity(0.5))
                                    Text(leftover.url.path)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()

                                    BadgeView(text: leftover.safety.label, icon: "sparkles", color: leftover.safety.color)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(cyberSurface.opacity(0.6))
                            }
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(neonCyan.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(30)
        }
        .background(cyberBase)
    }
}

// MARK: - Badge View (shared across files)

struct BadgeView: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.3), radius: 4)
    }
}

// Global helper for formatting bytes across views
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
