import Foundation
import CoreGraphics
import Vision
import ScreenCaptureKit

class LiveSceneAnalyzer {
    static let shared = LiveSceneAnalyzer()
    
    private init() {}
    
    /// Captures the main screen and performs OCR to find any contextual text
    func analyzeCurrentScene() async -> String {
        do {
            let cgImage = try await captureScreen()
            return await performOCR(on: cgImage)
        } catch {
            return "ERROR_CAPTURE: \(error.localizedDescription)"
        }
    }
    
    private func captureScreen() async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { 
            throw NSError(domain: "LiveSceneAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"]) 
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    private func performOCR(on image: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Combine all top candidates into a single block of text for analysis
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                continuation.resume(returning: recognizedText)
            }
            
            // For game HUDs, we want fast recognition. Fast mode prioritizes speed over pinpoint accuracy.
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
