import SwiftUI

// MARK: - Cyberpunk Color Palette

private let cyberBase = Color(red: 0.06, green: 0.06, blue: 0.12)
private let cyberPanel = Color(red: 0.1, green: 0.1, blue: 0.18)
private let cyberCellBg = Color(red: 0.08, green: 0.08, blue: 0.15)
private let neonCyan = Color(red: 0, green: 0.9, blue: 1)
private let neonMagenta = Color(red: 1, green: 0, blue: 0.6)
private let neonGreen = Color(red: 0, green: 1, blue: 0.5)
private let electricPurple = Color(red: 0.6, green: 0.2, blue: 1)
private let cyberTextPrimary = Color.white
private let cyberTextSecondary = Color.white.opacity(0.5)
private let cyberDivider = neonCyan.opacity(0.15)

// MARK: - State

final class SystemJunkViewState: ObservableObject {
    @Published var selectedCategory: JunkCategory? = nil
    @Published var showingCleanConfirmation = false
}

// MARK: - Main View

struct SystemJunkView: View {
    @StateObject private var scanner = SystemJunkScanner()
    @StateObject private var viewState = SystemJunkViewState()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            headerPanel

            Rectangle()
                .fill(cyberDivider)
                .frame(height: 1)

            // ── Content ───────────────────────────────────────────────
            if scanner.isScanning && scanner.scannedCategories.isEmpty {
                scanningPlaceholder
            } else if scanner.scannedCategories.isEmpty {
                emptyStatePlaceholder
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cyberBase)
        .alert("Clean Safe Junk?", isPresented: Binding(
            get: { viewState.showingCleanConfirmation },
            set: { viewState.showingCleanConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                Task {
                    await scanner.cleanAllSafeJunk()
                }
            }
        } message: {
            Text("This will move \(formatBytes(scanner.safeJunkSize)) of safe cache and log files to the Trash.")
        }
    }

    // MARK: - Header Panel

    private var headerPanel: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Junk Deep Scanner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(cyberTextPrimary)
                Text("Find and safely remove massive system caches, logs, and developer junk.")
                    .foregroundColor(cyberTextSecondary)
            }
            Spacer()

            if scanner.totalJunkSize > 0 && !scanner.isScanning {
                cleanJunkBadge
            }

            scanButton
        }
        .padding(30)
        .background(cyberPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(neonCyan.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: Clean-junk badge (header trailing)

    private var cleanJunkBadge: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Safe Junk Found")
                .font(.headline)
                .foregroundColor(neonGreen)
            HStack {
                Text(formatBytes(scanner.safeJunkSize))
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundColor(neonGreen)

                Button("Clean Safe Junk") {
                    viewState.showingCleanConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(neonGreen)
                .disabled(scanner.safeJunkSize == 0)
                .shadow(color: neonGreen.opacity(0.6), radius: 10)
            }
        }
        .padding(12)
        .background(neonGreen.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(neonGreen.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: neonGreen.opacity(0.3), radius: 8)
    }

    // MARK: Scan button

    private var scanButton: some View {
        Button(action: {
            scanner.startDeepScan()
        }) {
            Label(
                scanner.scannedCategories.isEmpty ? "Start Deep Scan" : "Rescan",
                systemImage: "sparkle.magnifyingglass"
            )
            .foregroundColor(cyberBase)
            .font(.system(.body, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(neonCyan)
        .controlSize(.large)
        .disabled(scanner.isScanning)
        .shadow(color: neonCyan.opacity(0.5), radius: 8)
    }

    // MARK: - Scanning Placeholder

    private var scanningPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(neonCyan)
            Text(scanner.scanProgress)
                .foregroundColor(cyberTextSecondary)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cyberBase)
    }

    // MARK: - Empty State

    private var emptyStatePlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundColor(neonCyan)
                .shadow(color: neonCyan.opacity(0.5), radius: 8)
            Text("Click 'Start Deep Scan' to find hidden system junk.")
                .foregroundColor(cyberTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cyberBase)
    }

    // MARK: - Main Content (Category + Items)

    private var mainContent: some View {
        HStack(spacing: 0) {
            categoryList

            Rectangle()
                .fill(cyberDivider)
                .frame(width: 1)

            itemDetail
        }
        .background(cyberBase)
    }

    // MARK: Category List

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(JunkCategory.allCases, id: \.self) { category in
                    let isSelected = viewState.selectedCategory == category
                    let size = scanner.junkItems
                        .filter { $0.category == category }
                        .reduce(0) { $0 + $1.size }

                    Button {
                        viewState.selectedCategory = category
                    } label: {
                        HStack {
                            Text(category.rawValue)
                                .foregroundColor(isSelected ? neonCyan : cyberTextPrimary)
                            Spacer()
                            if size > 0 {
                                Text(formatBytes(size))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(isSelected ? neonCyan.opacity(0.8) : cyberTextSecondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(isSelected ? neonCyan.opacity(0.12) : cyberCellBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? neonCyan.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
        .frame(maxHeight: .infinity)
        .background(cyberPanel)
    }

    // MARK: Item Detail

    @ViewBuilder
    private var itemDetail: some View {
        if let category = viewState.selectedCategory {
            let items = scanner.junkItems
                .filter { $0.category == category }
                .sorted(by: { $0.size > $1.size })

            VStack(alignment: .leading, spacing: 0) {
                // Category title + safety badge
                HStack {
                    VStack(alignment: .leading) {
                        Text(category.rawValue)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(cyberTextPrimary)
                        if category.isSafeToDelete {
                            BadgeView(text: "Safe to Delete", icon: "checkmark.circle.fill", color: neonGreen)
                        } else {
                            BadgeView(text: "Caution: Review First", icon: "exclamationmark.triangle.fill", color: neonMagenta)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(cyberPanel)

                // AI Explanation Box
                aiAnalysisBox(for: category)

                Rectangle()
                    .fill(cyberDivider)
                    .frame(height: 1)

                // Items list
                if items.isEmpty {
                    VStack {
                        Spacer()
                        Text("No junk found in this category.")
                            .foregroundColor(cyberTextSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(cyberBase)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(items) { item in
                                junkItemRow(item)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(cyberBase)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack {
                Text("Select a category to view items")
                    .foregroundColor(cyberTextSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cyberBase)
        }
    }

    // MARK: AI Analysis Box

    private func aiAnalysisBox(for category: JunkCategory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(electricPurple)
                .font(.title2)
                .shadow(color: electricPurple.opacity(0.5), radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Analysis")
                    .font(.headline)
                    .foregroundColor(electricPurple)
                Text(category.aiExplanation)
                    .font(.subheadline)
                    .foregroundColor(cyberTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(electricPurple.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(electricPurple.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: electricPurple.opacity(0.25), radius: 8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: Junk Item Row

    private func junkItemRow(_ item: JunkItem) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(neonCyan.opacity(0.5))
            Text(item.url.lastPathComponent)
                .foregroundColor(cyberTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(formatBytes(item.size))
                .foregroundColor(cyberTextSecondary)
                .font(.system(.body, design: .monospaced))

            Button(role: .destructive) {
                Task {
                    _ = await scanner.cleanItem(item)
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(neonMagenta)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(cyberCellBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(neonCyan.opacity(0.1), lineWidth: 1)
        )
    }
}
