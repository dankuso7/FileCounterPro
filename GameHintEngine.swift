import Foundation

struct GameHintEngine {
    static let shared = GameHintEngine()
    
    private let hints: [String: [String]] = [
        "the last of us": [
            "💡 **Clickers**: Don't waste ammo! Use a brick or bottle to stun them, then go in for a melee kill.",
            "💡 **Crafting**: Always keep at least one shiv crafted for opening locked resource doors.",
            "💡 **Stealth**: Moving slowly while crouching reduces your sound radius. Listen Mode is your best friend.",
            "💡 **Combat**: If you're overwhelmed, run and break line of sight to re-enter stealth.",
            "💡 **Upgrades**: Prioritize Weapon Sway and Maximum Health early on to save resources."
        ],
        "cyberpunk": [
            "💡 **Netrunning**: Always ping the network first to reveal all connected enemies and devices.",
            "💡 **Combat**: Tech weapons can shoot through thin walls. Combine with Ping for easy wall-bangs.",
            "💡 **Loot**: Don't sell common weapons; disassemble them to level up your crafting skill."
        ],
        "baldur's gate": [
            "💡 **Exploration**: Hold the Option key to highlight interactable objects and loot in the environment.",
            "💡 **Combat**: High ground gives you a significant advantage on attack rolls. Always seek elevation.",
            "💡 **Resting**: Short rests restore Warlock spell slots and fighter abilities. Use them frequently."
        ],
        "ghost of tsushima": [
            "💡 **Combat**: Match your stance to the enemy weapon (Stone for Swords, Water for Shields, Wind for Spears).",
            "💡 **Exploration**: Follow the golden birds; they always lead to hidden locations or vanity gear."
        ],
        "spider-man": [
            "💡 **Combat**: Use gadgets heavily! Web-shooters and impact webs can instantly stick enemies to walls.",
            "💡 **Traversal**: Release R2 at the very bottom of your swing arc to maximize forward speed."
        ],
        "resident evil": [
            "💡 **Combat**: Shoot zombies in the legs to cripple them, making them easier to avoid without wasting ammo.",
            "💡 **Inventory**: Always combine Green and Red herbs before using them for maximum healing."
        ],
        "god of war": [
            "💡 **Combat**: Throw your Leviathan Axe at enemies to freeze them, giving you time to focus on other threats.",
            "💡 **Exploration**: Look for ravens glowing green; breaking them yields valuable XP and rewards."
        ],
        "horizon": [
            "💡 **Combat**: Scan machines with your Focus to highlight weak points, then use Tearblast arrows to remove armor.",
            "💡 **Stealth**: Tall grass makes you completely invisible to machines unless they are actively searching for you."
        ],
        "gta": [
            "💡 **Wanted Level**: Break line of sight with police and hide in an alley or off-road area until the stars stop flashing.",
            "💡 **Vehicles**: You can shoot out the tires of pursuing vehicles to quickly disable them."
        ],
        "elden ring": [
            "💡 **Combat**: Don't get greedy! Strike once or twice, then roll away. Stamina management is key to survival.",
            "💡 **Exploration**: If an area feels too difficult, mount Torrent and ride in another direction to level up."
        ],
        "red dead redemption": [
            "💡 **Combat**: Dead Eye automatically reloads your weapon. Use it strategically in large firefights.",
            "💡 **Horse**: Tap the gallop button in rhythm with your horse's strides to consume almost zero stamina."
        ]
    ]
    
    func getHint(for gameName: String, ocrContext: String) -> String {
        if ocrContext == "ERROR_PERMISSION" {
            return "⚠️ Security Blocked: macOS prevented me from analyzing the screen. Open System Settings > Privacy & Security > Screen Recording, and enable FileCounter!"
        }
        
        if ocrContext.hasPrefix("ERROR_CAPTURE:") {
            return "⚠️ ScreenCaptureKit Failed: \(ocrContext.replacingOccurrences(of: "ERROR_CAPTURE: ", with: ""))"
        }
        
        let normalizedGame = gameName.lowercased()
        let normalizedOCR = ocrContext.lowercased()
        
        // Contextual overrides based on live scene OCR
        if normalizedGame.contains("the last of us") || normalizedGame.contains("tlou") {
            if normalizedOCR.contains("clicker") || normalizedOCR.contains("spore") || normalizedOCR.contains("infected") {
                return "💡 Scene Context (Clickers Detected): Don't waste ammo! Use a brick or bottle to stun them, then go in for a melee kill."
            } else if normalizedOCR.contains("locked") || normalizedOCR.contains("door") || normalizedOCR.contains("shiv") {
                return "💡 Scene Context (Locked Area): Always keep at least one shiv crafted for opening locked resource doors."
            } else if normalizedOCR.contains("stealth") || normalizedOCR.contains("sneak") || normalizedOCR.contains("listen") {
                return "💡 Scene Context (Stealth Phase): Moving slowly while crouching reduces your sound radius. Listen Mode is your best friend."
            }
        } else if normalizedGame.contains("cyberpunk") {
            if normalizedOCR.contains("breach") || normalizedOCR.contains("network") {
                return "💡 Scene Context (Hacking): Always ping the network first to reveal all connected enemies and devices."
            }
        } else if normalizedGame.contains("ghost of tsushima") {
            if normalizedOCR.contains("standoff") {
                return "💡 Scene Context (Standoff): Watch the enemy's feet, not their weapon. When they step forward, strike!"
            } else if normalizedOCR.contains("archer") || normalizedOCR.contains("bow") {
                return "💡 Scene Context (Archers): Listen for the shout before they fire to perfectly time your dodge."
            }
        } else if normalizedGame.contains("resident evil") {
            if normalizedOCR.contains("safe") || normalizedOCR.contains("code") || normalizedOCR.contains("dial") {
                return "💡 Scene Context (Puzzle): Check your files and inspect items in your inventory 3D view for hidden codes."
            }
        } else if normalizedGame.contains("god of war") {
            if normalizedOCR.contains("valkyrie") {
                return "💡 Scene Context (Boss Fight): Valkyries are relentless. Block their standard attacks, but dodge when you see the red ring!"
            }
        } else if normalizedGame.contains("horizon") {
            if normalizedOCR.contains("corruptor") || normalizedOCR.contains("thunderjaw") {
                return "💡 Scene Context (Heavy Machine): Aim exclusively for the heavy weapons on its back to tear them off and use them against it."
            }
        } else if normalizedGame.contains("elden ring") {
            if normalizedOCR.contains("grace") || normalizedOCR.contains("rest") {
                return "💡 Scene Context (Safe Zone): Resting at a Site of Grace restores your flasks but respawns all non-boss enemies."
            } else if normalizedOCR.contains("margit") || normalizedOCR.contains("godrick") {
                return "💡 Scene Context (Boss Fight): Wait for the boss to finish their full combo string before you commit to a heavy attack."
            }
        }
        
        // Fallback: Find the best matching key for the generic game
        for (key, gameHints) in hints {
            if normalizedGame.contains(key) || key.contains(normalizedGame) {
                // Return a random hint if no specific OCR context matched
                return gameHints.randomElement() ?? "💡 No specific hints available. Focus and stay sharp!"
            }
        }
        
        // Total fallback if game isn't in database
        if !ocrContext.isEmpty {
            return "💡 Scene Analysis Complete. I'm looking at \(ocrContext.count) characters of text. Stay focused on your objective!"
        }
        
        return "💡 Assistant Active: Waiting for visual context..."
    }
}
