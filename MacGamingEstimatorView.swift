import SwiftUI

final class MacGamingEstimatorViewState: ObservableObject {
    @Published var selectedResolution: Int = 1080
    @Published var selectedFilter: TranslationLayer? = nil
    @Published var searchQuery: String = ""
}

struct MacGamingEstimatorView: View {
    @StateObject private var estimator = MacGamingEstimator()
    @StateObject private var viewState = MacGamingEstimatorViewState()
    
    var filteredGames: [MacGame] {
        var result = estimator.games
        
        if let filter = viewState.selectedFilter {
            result = result.filter { $0.layer == filter }
        }
        
        if !viewState.searchQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(viewState.searchQuery) }
        }
        
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header & Search
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mac Gaming Estimator")
                        .font(.system(size: 28, weight: .bold))
                    Text("Simulate game performance using Apple's Game Porting Toolkit and CrossOver")
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search games...", text: $viewState.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !viewState.searchQuery.isEmpty {
                            Button(action: { viewState.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Hardware & Controls Bar
                HStack(spacing: 20) {
                    // Detected Chip
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Detected Hardware")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(estimator.currentChip) (\(estimator.coreCount)-Core)")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Resolution Picker
                    Picker("Resolution", selection: $viewState.selectedResolution) {
                        Text("1080p").tag(1080)
                        Text("1440p").tag(1440)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    
                    // Push to Limits Toggle
                    Toggle(isOn: $estimator.pushToLimits.animation()) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(estimator.pushToLimits ? .orange : .secondary)
                            Text("Push to Limits")
                                .fontWeight(.medium)
                        }
                    }
                    .toggleStyle(.button)
                    .tint(estimator.pushToLimits ? .orange : .secondary)
                }
                
                // Warning if Push to Limits is on
                if estimator.pushToLimits {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Warning: Simulating High Power Mode. This maximizes fan speed and disables thermal throttling to boost FPS, but your Mac will run hot.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterPill(title: "All Games", isSelected: viewState.selectedFilter == nil) {
                            withAnimation { viewState.selectedFilter = nil }
                        }
                        
                        ForEach(TranslationLayer.allCases, id: \.self) { layer in
                            FilterPill(title: layer.rawValue, isSelected: viewState.selectedFilter == layer) {
                                withAnimation { viewState.selectedFilter = layer }
                            }
                        }
                    }
                }
                
                // Games Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)], spacing: 20) {
                    ForEach(filteredGames) { game in
                        MacGamePerformanceCard(game: game, resolution: viewState.selectedResolution, estimator: estimator)
                    }
                }
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MacGamePerformanceCard: View {
    let game: MacGame
    let resolution: Int
    @ObservedObject var estimator: MacGamingEstimator
    
    var fpsColor: Color {
        let fps = estimator.estimateFPS(for: game, resolution: resolution)
        if fps >= 60 { return .green }
        if fps >= 30 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(game.layer.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(layerColor(game.layer).opacity(0.2))
                        .foregroundColor(layerColor(game.layer))
                        .cornerRadius(4)
                }
                Spacer()
                
                // FPS Badge
                VStack(spacing: 2) {
                    Text("\(estimator.estimateFPS(for: game, resolution: resolution))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(fpsColor)
                        .contentTransition(.numericText())
                    Text("FPS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(fpsColor.opacity(0.1))
                .cornerRadius(12)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                if game.requiresMetalFX {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("MetalFX")
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
                
                Text(game.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func layerColor(_ layer: TranslationLayer) -> Color {
        switch layer {
        case .native: return .blue
        case .gptk: return .indigo
        case .crossover: return .teal
        case .parallels: return .red
        }
    }
}
