import Foundation

extension UserDefaults {
    /// Keys for VoiceFlow app settings
    private enum Keys {
        static let isTextPolishEnabled = "com.voiceflow.isTextPolishEnabled"
    }

    /// Controls whether AI text polishing is enabled.
    /// When enabled, transcriptions are automatically polished to remove filler words and improve grammar.
    /// Defaults to false.
    var isTextPolishEnabled: Bool {
        get {
            // Return false if key doesn't exist (first launch)
            return object(forKey: Keys.isTextPolishEnabled) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Keys.isTextPolishEnabled)
            NSLog("[Settings] Text polish enabled: %@", newValue ? "YES" : "NO")
        }
    }
}
