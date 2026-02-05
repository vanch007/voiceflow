import Foundation

/// Manages application-wide settings including language preference
final class SettingsManager {
    static let shared = SettingsManager()

    private let languageKey = "app_language"

    /// Current language setting (ko, en, or zh)
    /// Defaults to Korean if not set
    var language: String {
        get {
            UserDefaults.standard.string(forKey: languageKey) ?? "ko"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: languageKey)
        }
    }

    private init() {}
}
