import Foundation

struct GameProfile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let searchIdentifiers: [String] // Strings to match in app/folder names
    let recommendedResolution: String
    let recommendedPreset: String
    let expectedFPS: String
    let predictedPowerDrawW: Double
    let visualFidelity: String
    let coverColor1: String // Hex string or named color representation for UI
    let coverColor2: String
    
    // AI Optimizations & Resource Predictions
    let predictedCPUUsage: String
    let predictedGPUUsage: String
    let predictedRAMUsage: String
    let thermalPrediction: String
    let lagRisk: String
    let aiOptimizedSettings: String
}

struct GameDatabase {
    static let profiles: [GameProfile] = [
        GameProfile(
            name: "Resident Evil Village",
            searchIdentifiers: ["Resident Evil Village", "RE8", "Resident Evil"],
            recommendedResolution: "1440p (MetalFX Quality)",
            recommendedPreset: "Prioritize Graphics",
            expectedFPS: "60+ FPS",
            predictedPowerDrawW: 21.0,
            visualFidelity: "Stunning HDR, High Textures",
            coverColor1: "1A1A1D",
            coverColor2: "4E4E50",
            predictedCPUUsage: "35%",
            predictedGPUUsage: "90%",
            predictedRAMUsage: "9.5 GB",
            thermalPrediction: "Warm (Active Cooling ON)",
            lagRisk: "Low",
            aiOptimizedSettings: "Disable Ray Tracing, Set Shadows to Medium, MetalFX to Performance to eliminate stutter during intense combat."
        ),
        GameProfile(
            name: "Baldur's Gate 3",
            searchIdentifiers: ["Baldur's Gate 3", "BG3"],
            recommendedResolution: "1080p",
            recommendedPreset: "Medium-High (FSR Quality)",
            expectedFPS: "45-60 FPS",
            predictedPowerDrawW: 22.0,
            visualFidelity: "Rich Detail, Smooth Combat",
            coverColor1: "8A2387",
            coverColor2: "E94057",
            predictedCPUUsage: "60%",
            predictedGPUUsage: "95%",
            predictedRAMUsage: "12 GB",
            thermalPrediction: "Hot (Heavy Load)",
            lagRisk: "Medium (Act 3)",
            aiOptimizedSettings: "Cap FPS to 45. Lower Crowd Density and Disable God Rays for consistent frame pacing in Act 3."
        ),
        GameProfile(
            name: "No Man's Sky",
            searchIdentifiers: ["No Man's Sky", "NMS"],
            recommendedResolution: "1440p (MetalFX Quality)",
            recommendedPreset: "High",
            expectedFPS: "60 FPS",
            predictedPowerDrawW: 18.0,
            visualFidelity: "Vibrant Colors, High Draw Distance",
            coverColor1: "0F2027",
            coverColor2: "203A43",
            predictedCPUUsage: "40%",
            predictedGPUUsage: "85%",
            predictedRAMUsage: "8 GB",
            thermalPrediction: "Moderate",
            lagRisk: "Low",
            aiOptimizedSettings: "Set Planet Details to Standard and MetalFX to Balanced for completely flawless 60 FPS flight."
        ),
        GameProfile(
            name: "Death Stranding",
            searchIdentifiers: ["Death Stranding", "Director's Cut"],
            recommendedResolution: "1440p (MetalFX Quality)",
            recommendedPreset: "Very High",
            expectedFPS: "60 FPS",
            predictedPowerDrawW: 20.0,
            visualFidelity: "Photorealistic Landscapes",
            coverColor1: "333333",
            coverColor2: "dd1818",
            predictedCPUUsage: "30%",
            predictedGPUUsage: "92%",
            predictedRAMUsage: "10 GB",
            thermalPrediction: "Warm",
            lagRisk: "Low",
            aiOptimizedSettings: "Keep Water and Shadow resolution on Medium. MetalFX handles the rest perfectly."
        ),
        GameProfile(
            name: "Hades",
            searchIdentifiers: ["Hades"],
            recommendedResolution: "4K Native",
            recommendedPreset: "Max Settings",
            expectedFPS: "120 FPS",
            predictedPowerDrawW: 10.0,
            visualFidelity: "Crisp 2D Art, Instant Response",
            coverColor1: "f12711",
            coverColor2: "f5af19",
            predictedCPUUsage: "15%",
            predictedGPUUsage: "40%",
            predictedRAMUsage: "4 GB",
            thermalPrediction: "Cool",
            lagRisk: "None",
            aiOptimizedSettings: "Run at 4K Native. The M4 chip can handle this at 120Hz with barely any power draw."
        ),
        GameProfile(
            name: "Minecraft",
            searchIdentifiers: ["Minecraft"],
            recommendedResolution: "1440p Native",
            recommendedPreset: "Fabulous! (16 chunks)",
            expectedFPS: "120+ FPS",
            predictedPowerDrawW: 12.0,
            visualFidelity: "Smooth Voxel Rendering",
            coverColor1: "56ab2f",
            coverColor2: "a8e063",
            predictedCPUUsage: "25%",
            predictedGPUUsage: "50%",
            predictedRAMUsage: "6 GB",
            thermalPrediction: "Cool",
            lagRisk: "Low",
            aiOptimizedSettings: "Install Sodium + Iris mods for Mac. It will drop power draw by 40% and double your framerate."
        ),
        GameProfile(
            name: "Cyberpunk 2077 (via CrossOver/Mythic)",
            searchIdentifiers: ["Cyberpunk 2077", "Cyberpunk"],
            recommendedResolution: "1080p",
            recommendedPreset: "Medium (FSR Balanced)",
            expectedFPS: "40-50 FPS",
            predictedPowerDrawW: 22.0,
            visualFidelity: "Playable Neon Cityscape",
            coverColor1: "FCE043",
            coverColor2: "FB7BA2",
            predictedCPUUsage: "75%",
            predictedGPUUsage: "100%",
            predictedRAMUsage: "13 GB",
            thermalPrediction: "Very Hot (Translation Overhead)",
            lagRisk: "High",
            aiOptimizedSettings: "Enable D3DMetal in CrossOver. Set Crowd Density to Low and FSR 2.1 to Performance for stable driving."
        ),
        GameProfile(
            name: "World of Warcraft",
            searchIdentifiers: ["World of Warcraft", "WoW"],
            recommendedResolution: "1440p Native",
            recommendedPreset: "Graphics Level 7",
            expectedFPS: "60-100 FPS",
            predictedPowerDrawW: 15.0,
            visualFidelity: "High View Distance, Fluid Raids",
            coverColor1: "11998e",
            coverColor2: "38ef7d",
            predictedCPUUsage: "25%",
            predictedGPUUsage: "70%",
            predictedRAMUsage: "8 GB",
            thermalPrediction: "Moderate",
            lagRisk: "Low",
            aiOptimizedSettings: "Turn down Liquid Detail and Particle Density in 40-man raids to prevent sudden 1% low drops."
        ),
        GameProfile(
            name: "Crimson Desert",
            searchIdentifiers: ["Crimson Desert"],
            recommendedResolution: "1080p (MetalFX Quality)",
            recommendedPreset: "High",
            expectedFPS: "60 FPS",
            predictedPowerDrawW: 24.0,
            visualFidelity: "Next-Gen Lighting & Physics",
            coverColor1: "800000",
            coverColor2: "A52A2A",
            predictedCPUUsage: "65%",
            predictedGPUUsage: "100%",
            predictedRAMUsage: "14 GB",
            thermalPrediction: "Very Hot",
            lagRisk: "Medium",
            aiOptimizedSettings: "Drop Volumetric Fog to Low and use MetalFX Performance. The M4 GPU will be fully saturated."
        ),
        GameProfile(
            name: "Horizon Zero Dawn",
            searchIdentifiers: ["Horizon Zero Dawn"],
            recommendedResolution: "1440p",
            recommendedPreset: "Original/High",
            expectedFPS: "60+ FPS",
            predictedPowerDrawW: 20.0,
            visualFidelity: "Vibrant Open World",
            coverColor1: "d16400",
            coverColor2: "eb8c15",
            predictedCPUUsage: "45%",
            predictedGPUUsage: "90%",
            predictedRAMUsage: "11 GB",
            thermalPrediction: "Warm",
            lagRisk: "Low",
            aiOptimizedSettings: "Cap at 60 FPS. Set Clouds to Medium. The port runs beautifully through GPTK/CrossOver."
        ),
        GameProfile(
            name: "Marvel's Spider-Man",
            searchIdentifiers: ["Marvel’s Spider-Man", "Spider-Man"],
            recommendedResolution: "1440p (MetalFX Quality)",
            recommendedPreset: "Very High",
            expectedFPS: "60+ FPS",
            predictedPowerDrawW: 21.0,
            visualFidelity: "Fluid Ray-Traced Reflections",
            coverColor1: "e60000",
            coverColor2: "2a52be",
            predictedCPUUsage: "55%",
            predictedGPUUsage: "95%",
            predictedRAMUsage: "10.5 GB",
            thermalPrediction: "Hot",
            lagRisk: "Medium",
            aiOptimizedSettings: "Disable Ray Tracing. Set Level of Detail (LOD) to High instead of Very High for smooth web-swinging."
        ),
        GameProfile(
            name: "Red Dead Redemption 2",
            searchIdentifiers: ["Red Dead Redemption 2", "RDR2"],
            recommendedResolution: "1080p (FSR Quality)",
            recommendedPreset: "High/Ultra Textures",
            expectedFPS: "45-60 FPS",
            predictedPowerDrawW: 22.0,
            visualFidelity: "Incredible Cinematic Realism",
            coverColor1: "cc0000",
            coverColor2: "ff4d4d",
            predictedCPUUsage: "50%",
            predictedGPUUsage: "98%",
            predictedRAMUsage: "12 GB",
            thermalPrediction: "Hot",
            lagRisk: "Medium",
            aiOptimizedSettings: "Use Vulkan API. Drop Water Physics and Near Volumetric Fog to lowest settings. Textures can stay Ultra."
        ),
        GameProfile(
            name: "The Last of Us Part I",
            searchIdentifiers: ["The Last of Us Part I", "TLOU"],
            recommendedResolution: "1080p (MetalFX Quality)",
            recommendedPreset: "Medium",
            expectedFPS: "60 FPS",
            predictedPowerDrawW: 23.0,
            visualFidelity: "Highly Detailed Environments",
            coverColor1: "4d664d",
            coverColor2: "809980",
            predictedCPUUsage: "80%",
            predictedGPUUsage: "100%",
            predictedRAMUsage: "14.5 GB",
            thermalPrediction: "Very Hot (CPU Bound)",
            lagRisk: "High",
            aiOptimizedSettings: "Wait for Shaders to fully compile before playing! Set CPU thread affinity if possible. Use FSR 2.2 Balanced."
        )
    ]
}
