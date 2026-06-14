import SwiftUI

struct GPUSideBySideView: View {
    let selectedGPUs: [GPUModel]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hardware Comparison")
                        .font(.system(size: 24, weight: .bold))
                    Text("Side-by-side performance & efficiency analysis")
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
            .padding()
            .background(Color.primary.opacity(0.05))
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(selectedGPUs) { gpu in
                        GPUCardView(
                            gpu: gpu,
                            isTopTflops: isTop(gpu: gpu, metric: \.tflops, higherIsBetter: true),
                            isTopPower: isTop(gpu: gpu, metric: \.estimatedWatts, higherIsBetter: false),
                            isTopEfficiency: isTop(gpu: gpu, metric: { $0.tflops / max(1, $0.estimatedWatts) }, higherIsBetter: true)
                        )
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func isTop(gpu: GPUModel, metric: (GPUModel) -> Double, higherIsBetter: Bool) -> Bool {
        guard selectedGPUs.count > 1 else { return true }
        let values = selectedGPUs.map(metric)
        let target = metric(gpu)
        if higherIsBetter {
            return target == values.max()
        } else {
            return target == values.min()
        }
    }
}

struct GPUCardView: View {
    let gpu: GPUModel
    let isTopTflops: Bool
    let isTopPower: Bool
    let isTopEfficiency: Bool
    
    var efficiency: Double {
        gpu.tflops / max(1, gpu.estimatedWatts)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(gpu.vendor)
                    .font(.caption.bold())
                    .foregroundColor(gpu.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(gpu.color.opacity(0.15))
                    .cornerRadius(6)
                
                Text(gpu.name)
                    .font(.title3.bold())
                    .lineLimit(2)
                    .frame(height: 50, alignment: .topLeading)
            }
            
            Divider()
            
            // Gaming Tier
            VStack(alignment: .leading, spacing: 4) {
                Text("GAMING TIER")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: "gamecontroller.fill")
                    Text(gpu.gamingTier)
                }
                .font(.system(size: 13, weight: .semibold))
            }
            
            // Compute Power
            VStack(alignment: .leading, spacing: 4) {
                Text("COMPUTE POWER")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", gpu.tflops))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(isTopTflops ? .green : .primary)
                    Text("TFLOPS")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            
            // Estimated Power
            VStack(alignment: .leading, spacing: 4) {
                Text("MAX BOARD POWER")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(gpu.estimatedWatts))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(isTopPower ? .green : .primary)
                    Text("Watts")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            
            // Efficiency
            VStack(alignment: .leading, spacing: 4) {
                Text("EFFICIENCY")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.3f", efficiency))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(isTopEfficiency ? .green : .primary)
                    Text("TFLOPS / Watt")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                if isTopEfficiency && efficiency > 0.1 {
                    Text("Most Efficient! 🏆")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 240, height: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gpu.color.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
