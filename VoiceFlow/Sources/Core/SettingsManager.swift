import Foundation

/// Manages application settings with UserDefaults persistence
final class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - Notification Names

    static let settingsDidChangeNotification = Notification.Name("SettingsDidChange")

    // MARK: - UserDefaults Keys

    private enum Keys {
        // General Settings
        static let language = "settings.general.language"
        static let soundEffectsEnabled = "settings.general.soundEffectsEnabled"

        // Keyboard Shortcuts
        static let activationShortcut = "settings.shortcuts.activation"

        // Voice Recognition Settings
        static let voiceEnabled = "settings.voice.enabled"
        static let voiceLanguage = "settings.voice.language"
        static let voiceSensitivity = "settings.voice.sensitivity"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let language = "ko"  // Korean
        static let soundEffectsEnabled = true
        static let activationShortcut = "ctrl-double-tap"
        static let voiceEnabled = true
        static let voiceLanguage = "ko"
        static let voiceSensitivity = 0.5
    }

    // MARK: - General Settings

    var language: String {
        get {
            UserDefaults.standard.string(forKey: Keys.language) ?? Defaults.language
        }
        set {
            guard validateLanguage(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Keys.language)
            notifySettingsChanged(category: "general", key: "language", value: newValue)
        }
    }

    var soundEffectsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.soundEffectsEnabled) == nil {
                return Defaults.soundEffectsEnabled
            }
            return UserDefaults.standard.bool(forKey: Keys.soundEffectsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.soundEffectsEnabled)
            notifySettingsChanged(category: "general", key: "soundEffectsEnabled", value: newValue)
        }
    }

    // MARK: - Keyboard Shortcuts

    var activationShortcut: String {
        get {
            UserDefaults.standard.string(forKey: Keys.activationShortcut) ?? Defaults.activationShortcut
        }
        set {
            guard validateShortcut(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Keys.activationShortcut)
            notifySettingsChanged(category: "shortcuts", key: "activation", value: newValue)
        }
    }

    // MARK: - Voice Recognition Settings

    var voiceEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.voiceEnabled) == nil {
                return Defaults.voiceEnabled
            }
            return UserDefaults.standard.bool(forKey: Keys.voiceEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.voiceEnabled)
            notifySettingsChanged(category: "voice", key: "enabled", value: newValue)
        }
    }

    var voiceLanguage: String {
        get {
            UserDefaults.standard.string(forKey: Keys.voiceLanguage) ?? Defaults.voiceLanguage
        }
        set {
            guard validateLanguage(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Keys.voiceLanguage)
            notifySettingsChanged(category: "voice", key: "language", value: newValue)
        }
    }

    var voiceSensitivity: Double {
        get {
            if UserDefaults.standard.object(forKey: Keys.voiceSensitivity) == nil {
                return Defaults.voiceSensitivity
            }
            return UserDefaults.standard.double(forKey: Keys.voiceSensitivity)
        }
        set {
            let validated = max(0.0, min(1.0, newValue))
            UserDefaults.standard.set(validated, forKey: Keys.voiceSensitivity)
            notifySettingsChanged(category: "voice", key: "sensitivity", value: validated)
        }
    }

    // MARK: - Initialization

    private init() {
        // Ensure defaults are registered
        registerDefaults()
    }

    private func registerDefaults() {
        // Register default values with UserDefaults
        let defaults: [String: Any] = [
            Keys.language: Defaults.language,
            Keys.soundEffectsEnabled: Defaults.soundEffectsEnabled,
            Keys.activationShortcut: Defaults.activationShortcut,
            Keys.voiceEnabled: Defaults.voiceEnabled,
            Keys.voiceLanguage: Defaults.voiceLanguage,
            Keys.voiceSensitivity: Defaults.voiceSensitivity
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Validation

    private func validateLanguage(_ language: String) -> Bool {
        let supportedLanguages = ["ko", "en", "zh"]
        return supportedLanguages.contains(language)
    }

    private func validateShortcut(_ shortcut: String) -> Bool {
        // Basic validation - non-empty and doesn't conflict with reserved shortcuts
        guard !shortcut.isEmpty else { return false }

        // Reserved system shortcuts that cannot be used
        let reservedShortcuts = ["cmd-q", "cmd-w", "cmd-h", "cmd-m"]
        return !reservedShortcuts.contains(shortcut.lowercased())
    }

    // MARK: - Notifications

    private func notifySettingsChanged(category: String, key: String, value: Any) {
        let userInfo: [String: Any] = [
            "category": category,
            "key": key,
            "value": value
        ]
        NotificationCenter.default.post(
            name: SettingsManager.settingsDidChangeNotification,
            object: self,
            userInfo: userInfo
        )
    }

    // MARK: - Reset

    func resetToDefaults() {
        language = Defaults.language
        soundEffectsEnabled = Defaults.soundEffectsEnabled
        activationShortcut = Defaults.activationShortcut
        voiceEnabled = Defaults.voiceEnabled
        voiceLanguage = Defaults.voiceLanguage
        voiceSensitivity = Defaults.voiceSensitivity
    }
}
