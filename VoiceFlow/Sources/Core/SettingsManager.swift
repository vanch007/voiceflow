import Foundation
import AppKit

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
            guard validateShortcut(newValue, currentKey: Keys.activationShortcut) else { return }
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

        guard supportedLanguages.contains(language) else {
            showValidationError(
                title: localizedString(key: "validation.error.title"),
                message: localizedString(key: "validation.error.unsupportedLanguage", language)
            )
            return false
        }

        return true
    }

    private func validateShortcut(_ shortcut: String, currentKey: String) -> Bool {
        // Empty shortcut validation
        guard !shortcut.isEmpty else {
            showValidationError(
                title: localizedString(key: "validation.error.title"),
                message: localizedString(key: "validation.error.emptyShortcut")
            )
            return false
        }

        // Reserved system shortcuts that cannot be used
        let reservedShortcuts = ["cmd-q", "cmd-w", "cmd-h", "cmd-m", "cmd-n", "cmd-t", "cmd-option-esc"]
        if reservedShortcuts.contains(shortcut.lowercased()) {
            showValidationError(
                title: localizedString(key: "validation.error.title"),
                message: localizedString(key: "validation.error.reservedShortcut", shortcut)
            )
            return false
        }

        // Check for duplicate shortcuts across all shortcut settings
        if isDuplicateShortcut(shortcut, excludingKey: currentKey) {
            showValidationError(
                title: localizedString(key: "validation.error.title"),
                message: localizedString(key: "validation.error.duplicateShortcut", shortcut)
            )
            return false
        }

        return true
    }

    /// Check if a shortcut is already used by another setting
    private func isDuplicateShortcut(_ shortcut: String, excludingKey: String) -> Bool {
        let allShortcutKeys = [
            Keys.activationShortcut
            // Add more shortcut keys here as they are added to the app
        ]

        for key in allShortcutKeys where key != excludingKey {
            if let existingShortcut = UserDefaults.standard.string(forKey: key),
               existingShortcut.lowercased() == shortcut.lowercased() {
                return true
            }
        }

        return false
    }

    /// Show validation error dialog to user
    private func showValidationError(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: self.localizedString(key: "validation.error.ok"))
            alert.runModal()
        }
    }

    /// Get localized string based on current language setting
    private func localizedString(key: String, _ args: CVarArg...) -> String {
        let currentLanguage = language

        let translations: [String: [String: String]] = [
            "validation.error.title": [
                "ko": "설정 오류",
                "en": "Settings Error",
                "zh": "设置错误"
            ],
            "validation.error.unsupportedLanguage": [
                "ko": "지원하지 않는 언어입니다: %@",
                "en": "Unsupported language: %@",
                "zh": "不支持的语言: %@"
            ],
            "validation.error.emptyShortcut": [
                "ko": "단축키는 비어있을 수 없습니다.",
                "en": "Shortcut cannot be empty.",
                "zh": "快捷键不能为空。"
            ],
            "validation.error.reservedShortcut": [
                "ko": "'%@'는 시스템 예약 단축키입니다.",
                "en": "'%@' is a reserved system shortcut.",
                "zh": "'%@'是系统保留快捷键。"
            ],
            "validation.error.duplicateShortcut": [
                "ko": "'%@'는 이미 다른 기능에 할당되어 있습니다.",
                "en": "'%@' is already assigned to another function.",
                "zh": "'%@'已分配给其他功能。"
            ],
            "validation.error.ok": [
                "ko": "확인",
                "en": "OK",
                "zh": "确定"
            ]
        ]

        guard let languageDict = translations[key],
              let template = languageDict[currentLanguage] ?? languageDict["en"] else {
            return key
        }

        if args.isEmpty {
            return template
        } else {
            return String(format: template, arguments: args)
        }
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
