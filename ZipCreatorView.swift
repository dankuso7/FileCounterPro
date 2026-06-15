import SwiftUI
import UniformTypeIdentifiers

final class ZipCreatorViewState: ObservableObject {
    @Published var isTargeted = false
    @Published var droppedURLs: [URL] = []
    @Published var selectedLevel: ZipCompressionLevel = .maximum
}

struct ZipCreatorView: View {
    @StateObject private var engine = ZipEngine()
    @StateObject private var vs = ZipCreatorViewState()
    
    // Convenience bindings
    var bIsTargeted: Binding<Bool> { Binding(get: { vs.isTargeted }, set: { vs.isTargeted = $0 }) }
    var bDroppedURLs: Binding<[URL]> { Binding(get: { vs.droppedURLs }, set: { vs.droppedURLs = $0 }) }
    var bSelectedLevel: Binding<ZipCompressionLevel> { Binding(get: { vs.selectedLevel }, set: { vs.selectedLevel = $0 }) }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 24))
                    .foregroundColor(SciFi.neonCyan)
                    .shadow(color: SciFi.neonCyan.opacity(0.8), radius: 5)
                
                Text("ZIP CREATOR PRO")
                    .font(.custom("Courier", size: 24).bold())
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
            .background(SciFi.bgPanel)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SciFi.neonCyan.opacity(0.5), lineWidth: 1))
            
            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SciFi.bgPanel)
                
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        vs.isTargeted ? SciFi.neonGreen : SciFi.neonPurple.opacity(0.5),
                        style: StrokeStyle(lineWidth: vs.isTargeted ? 3 : 2, dash: [10])
                    )
                    .animation(.easeInOut(duration: 0.2), value: vs.isTargeted)
                
                VStack(spacing: 16) {
                    Image(systemName: vs.isTargeted ? "arrow.down.circle.fill" : "doc.zipper")
                        .font(.system(size: 60))
                        .foregroundColor(vs.isTargeted ? SciFi.neonGreen : SciFi.neonPurple)
                        .shadow(color: (vs.isTargeted ? SciFi.neonGreen : SciFi.neonPurple).opacity(0.8), radius: 10)
                    
                    if vs.droppedURLs.isEmpty {
                        Text("DRAG & DROP FILES OR FOLDERS HERE")
                            .font(.custom("Courier", size: 16).bold())
                            .foregroundColor(.white)
                        Text("No Size Limit • Hardware Accelerated")
                            .font(.custom("Courier", size: 12))
                            .foregroundColor(SciFi.textDim)
                    } else {
                        Text("\(vs.droppedURLs.count) ITEM(S) SELECTED")
                            .font(.custom("Courier", size: 18).bold())
                            .foregroundColor(SciFi.neonCyan)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(vs.droppedURLs, id: \.self) { url in
                                    Text(url.lastPathComponent)
                                        .font(.custom("Courier", size: 12))
                                        .foregroundColor(SciFi.textDim)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                        
                        Button("Clear Selection") {
                            vs.droppedURLs.removeAll()
                        }
                        .font(.custom("Courier", size: 12))
                        .foregroundColor(SciFi.neonMagenta)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: bIsTargeted) { providers in
                vs.droppedURLs.removeAll()
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async {
                                self.vs.droppedURLs.append(url)
                            }
                        }
                    }
                }
                return true
            }
            
            // Settings & Action
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMPRESSION LEVEL")
                        .font(.custom("Courier", size: 12).bold())
                        .foregroundColor(SciFi.textDim)
                    
                    Picker("", selection: bSelectedLevel) {
                        Text("Store Only (Fastest)").tag(ZipCompressionLevel.storeOnly)
                        Text("Fast").tag(ZipCompressionLevel.fast)
                        Text("Standard").tag(ZipCompressionLevel.standard)
                        Text("Maximum (Smallest)").tag(ZipCompressionLevel.maximum)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    .disabled(engine.isZipping)
                }
                
                Spacer()
                
                if engine.isZipping {
                    Button(action: { engine.cancel() }) {
                        Text("CANCEL")
                            .font(.custom("Courier", size: 14).bold())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(SciFi.neonMagenta.opacity(0.2))
                            .foregroundColor(SciFi.neonMagenta)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SciFi.neonMagenta, lineWidth: 1))
                            .shadow(color: SciFi.neonMagenta.opacity(0.5), radius: 5)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: startCompression) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("START COMPRESSION")
                        }
                        .font(.custom("Courier", size: 14).bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(vs.droppedURLs.isEmpty ? Color.gray.opacity(0.2) : SciFi.neonGreen.opacity(0.2))
                        .foregroundColor(vs.droppedURLs.isEmpty ? .gray : SciFi.neonGreen)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(vs.droppedURLs.isEmpty ? .gray : SciFi.neonGreen, lineWidth: 1))
                        .shadow(color: (vs.droppedURLs.isEmpty ? .clear : SciFi.neonGreen).opacity(0.5), radius: 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(vs.droppedURLs.isEmpty)
                }
            }
            .padding()
            .background(SciFi.bgPanel)
            .cornerRadius(12)
            
            // Progress Area
            if engine.isZipping || engine.progress > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Text(engine.statusMessage)
                            .font(.custom("Courier", size: 14).bold())
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(engine.progress * 100))%")
                            .font(.custom("Courier", size: 14).bold())
                            .foregroundColor(SciFi.neonCyan)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.5))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [SciFi.neonCyan, SciFi.neonPurple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * CGFloat(engine.progress)), height: 8)
                                .shadow(color: SciFi.neonCyan.opacity(0.8), radius: 5)
                                .animation(.linear(duration: 0.2), value: engine.progress)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text(engine.currentFile)
                            .font(.custom("Courier", size: 10))
                            .foregroundColor(SciFi.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(engine.processedFiles) / \(engine.totalFiles)")
                            .font(.custom("Courier", size: 10))
                            .foregroundColor(SciFi.textDim)
                    }
                }
                .padding()
                .background(SciFi.bgPanel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SciFi.neonCyan.opacity(0.3), lineWidth: 1))
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SciFi.bgDeep)
    }
    
    private func startCompression() {
        guard !droppedURLs.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.zip]
        savePanel.nameFieldStringValue = "Archive.zip"
        savePanel.title = "Save Zip File"
        
        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            engine.createZip(sourceURLs: droppedURLs, destinationURL: destURL, level: selectedLevel)
        }
    }
}
