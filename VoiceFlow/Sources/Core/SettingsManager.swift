import Foundation
import Combine
import ServiceManagement
import AppKit
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "SettingsManager")

enum ModelSize: String, Codable, CaseIterable {
    case model1_7B = "1.7B"
    case model0_6B = "0.6B"

    var displayName: String {
        switch self {
        case .model1_7B: return "1.7B (精确)"
        case .model0_6B: return "0.6B (快速)"
        }
    }

    var modelId: String {
        switch self {
        case .model1_7B: return "mlx-community/Qwen3-ASR-1.7B-8bit"
        case .model0_6B: return "mlx-community/Qwen3-ASR-0.6B-8bit"
        }
    }
}

enum ASRLanguage: String, Codable, CaseIterable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"
    case cantonese = "yue"
    case japanese = "ja"
    case korean = "ko"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case dutch = "nl"
    case swedish = "sv"
    case danish = "da"
    case finnish = "fi"
    case polish = "pl"
    case czech = "cs"
    case greek = "el"
    case hungarian = "hu"
    case macedonian = "mk"
    case romanian = "ro"
    case arabic = "ar"
    case indonesian = "id"
    case thai = "th"
    case vietnamese = "vi"
    case turkish = "tr"
    case hindi = "hi"
    case malay = "ms"
    case filipino = "fil"
    case persian = "fa"

    // 中国方言（Qwen3-ASR 独占优势）
    case sichuanese = "zh-sichuan"      // 四川话
    case northeastern = "zh-dongbei"    // 东北话
    case shanghainese = "zh-shanghai"   // 上海话
    case hokkien = "zh-minnan"          // 闽南语
    case hakka = "zh-hakka"             // 客家话
    case wenzhou = "zh-wenzhou"         // 温州话
    case changsha = "zh-changsha"       // 长沙话
    case nanchang = "zh-nanchang"       // 南昌话

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .chinese: return "中文（普通话）"
        case .english: return "英语"
        case .cantonese: return "粤语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .german: return "德语"
        case .french: return "法语"
        case .spanish: return "西班牙语"
        case .portuguese: return "葡萄牙语"
        case .italian: return "意大利语"
        case .russian: return "俄语"
        case .dutch: return "荷兰语"
        case .swedish: return "瑞典语"
        case .danish: return "丹麦语"
        case .finnish: return "芬兰语"
        case .polish: return "波兰语"
        case .czech: return "捷克语"
        case .greek: return "希腊语"
        case .hungarian: return "匈牙利语"
        case .macedonian: return "马其顿语"
        case .romanian: return "罗马尼亚语"
        case .arabic: return "阿拉伯语"
        case .indonesian: return "印尼语"
        case .thai: return "泰语"
        case .vietnamese: return "越南语"
        case .turkish: return "土耳其语"
        case .hindi: return "印地语"
        case .malay: return "马来语"
        case .filipino: return "菲律宾语"
        case .persian: return "波斯语"
        // 中国方言
        case .sichuanese: return "🇨🇳 四川话"
        case .northeastern: return "🇨🇳 东北话"
        case .shanghainese: return "🇨🇳 上海话"
        case .hokkien: return "🇨🇳 闽南语"
        case .hakka: return "🇨🇳 客家话"
        case .wenzhou: return "🇨🇳 温州话"
        case .changsha: return "🇨🇳 长沙话"
        case .nanchang: return "🇨🇳 南昌话"
        }
    }

    /// 是否为中国方言
    var isChineseDialect: Bool {
        switch self {
        case .sichuanese, .northeastern, .shanghainese, .hokkien, .hakka, .wenzhou, .changsha, .nanchang:
            return true
        default:
            return false
        }
    }
}

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Notification Names

    static let settingsDidChangeNotification = Notification.Name("SettingsDidChange")

    @Published var hotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled)
            NSLog("[SettingsManager] Hotkey enabled changed to: \(hotkeyEnabled)")
        }
    }

    @Published var modelSize: ModelSize {
        didSet {
            if let encoded = try? JSONEncoder().encode(modelSize) {
                UserDefaults.standard.set(encoded, forKey: Keys.modelSize)
                NSLog("[SettingsManager] Model size changed to: \(modelSize.rawValue)")
            }
        }
    }

    @Published var autoLaunchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunchEnabled, forKey: Keys.autoLaunchEnabled)
            NSLog("[SettingsManager] Auto-launch enabled changed to: \(autoLaunchEnabled)")
            applyAutoLaunchSetting()
        }
    }

    @Published var textPolishEnabled: Bool {
        didSet {
            UserDefaults.standard.isTextPolishEnabled = textPolishEnabled
            NSLog("[SettingsManager] Text polish enabled changed to: \(textPolishEnabled)")
        }
    }

    @Published var useTimestamps: Bool {
        didSet {
            UserDefaults.standard.set(useTimestamps, forKey: Keys.useTimestamps)
            NSLog("[SettingsManager] Use timestamps changed to: \(useTimestamps)")
        }
    }

    @Published var llmSettings: LLMSettings {
        didSet {
            saveLLMSettings()
            NSLog("[SettingsManager] LLM settings changed: enabled=\(llmSettings.isEnabled), model=\(llmSettings.model)")
            notifySettingsChanged(category: "llm", key: "settings", value: llmSettings.isEnabled)
        }
    }

    @Published var asrLanguage: ASRLanguage {
        didSet {
            if let encoded = try? JSONEncoder().encode(asrLanguage) {
                UserDefaults.standard.set(encoded, forKey: Keys.asrLanguage)
                NSLog("[SettingsManager] ASR language changed to: \(asrLanguage.rawValue)")
            }
        }
    }

    // MARK: - General Settings (from 016- branch)

    var language: String {
        get {
            guard let value = UserDefaults.standard.string(forKey: Keys.language) else {
                return Defaults.language
            }
            let supportedLanguages = ["ko", "en", "zh"]
            if !supportedLanguages.contains(value) {
                logCorruptedSetting(key: Keys.language, value: value, defaultValue: Defaults.language)
                return Defaults.language
            }
            return value
        }
        set {
            guard validateLanguage(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Keys.language)
            notifySettingsChanged(category: "general", key: "language", value: newValue)
        }
    }

    var soundEffectsEnabled: Bool {
        get {
            guard let object = UserDefaults.standard.object(forKey: Keys.soundEffectsEnabled) else {
                return Defaults.soundEffectsEnabled
            }
            guard object is Bool else {
                logCorruptedSetting(key: Keys.soundEffectsEnabled, value: object, defaultValue: Defaults.soundEffectsEnabled)
                return Defaults.soundEffectsEnabled
            }
            return UserDefaults.standard.bool(forKey: Keys.soundEffectsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.soundEffectsEnabled)
            notifySettingsChanged(category: "general", key: "soundEffectsEnabled", value: newValue)
        }
    }

    var voiceEnabled: Bool {
        get {
            guard let object = UserDefaults.standard.object(forKey: Keys.voiceEnabled) else {
                return Defaults.voiceEnabled
            }
            guard object is Bool else {
                logCorruptedSetting(key: Keys.voiceEnabled, value: object, defaultValue: Defaults.voiceEnabled)
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
            guard let value = UserDefaults.standard.string(forKey: Keys.voiceLanguage) else {
                return Defaults.voiceLanguage
            }
            let supportedLanguages = ["ko", "en", "zh"]
            if !supportedLanguages.contains(value) {
                logCorruptedSetting(key: Keys.voiceLanguage, value: value, defaultValue: Defaults.voiceLanguage)
                return Defaults.voiceLanguage
            }
            return value
        }
        set {
            guard validateLanguage(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Keys.voiceLanguage)
            notifySettingsChanged(category: "voice", key: "language", value: newValue)
        }
    }

    var voiceSensitivity: Double {
        get {
            guard let object = UserDefaults.standard.object(forKey: Keys.voiceSensitivity) else {
                return Defaults.voiceSensitivity
            }
            guard object is NSNumber else {
                logCorruptedSetting(key: Keys.voiceSensitivity, value: object, defaultValue: Defaults.voiceSensitivity)
                return Defaults.voiceSensitivity
            }
            let value = UserDefaults.standard.double(forKey: Keys.voiceSensitivity)
            if value < 0.0 || value > 1.0 {
                logCorruptedSetting(key: Keys.voiceSensitivity, value: value, defaultValue: Defaults.voiceSensitivity)
                return Defaults.voiceSensitivity
            }
            return value
        }
        set {
            let validated = max(0.0, min(1.0, newValue))
            UserDefaults.standard.set(validated, forKey: Keys.voiceSensitivity)
            notifySettingsChanged(category: "voice", key: "sensitivity", value: validated)
        }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding)
            NSLog("[SettingsManager] hasCompletedOnboarding changed to: \(newValue)")
        }
    }

    private enum Keys {
        static let hotkeyEnabled = "hotkeyEnabled"
        static let modelSize = "modelSize"
        static let autoLaunchEnabled = "autoLaunchEnabled"
        static let asrLanguage = "asrLanguage"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let useTimestamps = "useTimestamps"
        // General settings keys
        static let language = "settings.general.language"
        static let soundEffectsEnabled = "settings.general.soundEffectsEnabled"
        static let voiceEnabled = "settings.voice.enabled"
        static let voiceLanguage = "settings.voice.language"
        static let voiceSensitivity = "settings.voice.sensitivity"
        // LLM settings keys
        static let llmSettings = "settings.llm"
    }

    private enum Defaults {
        static let language = "zh"
        static let soundEffectsEnabled = true
        static let voiceEnabled = true
        static let voiceLanguage = "zh"
        static let voiceSensitivity = 0.5
    }

    private init() {
        // Load hotkey enabled (default: true)
        self.hotkeyEnabled = UserDefaults.standard.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true

        // Load model size (default: 0.6B for faster performance)
        if let data = UserDefaults.standard.data(forKey: Keys.modelSize),
           let decoded = try? JSONDecoder().decode(ModelSize.self, from: data) {
            self.modelSize = decoded
        } else {
            self.modelSize = .model0_6B  // Changed default to 0.6B
        }

        // Load auto-launch enabled (default: false)
        self.autoLaunchEnabled = UserDefaults.standard.object(forKey: Keys.autoLaunchEnabled) as? Bool ?? false

        // Load text polish enabled (default: false)
        self.textPolishEnabled = UserDefaults.standard.isTextPolishEnabled

        // Load use timestamps (default: false)
        self.useTimestamps = UserDefaults.standard.object(forKey: Keys.useTimestamps) as? Bool ?? false

        // Load LLM settings
        self.llmSettings = Self.loadLLMSettingsStatic()

        // Load ASR language (default: auto)
        if let data = UserDefaults.standard.data(forKey: Keys.asrLanguage),
           let decoded = try? JSONDecoder().decode(ASRLanguage.self, from: data) {
            self.asrLanguage = decoded
        } else {
            self.asrLanguage = .auto
        }

        // Register defaults for general settings
        registerDefaults()

        NSLog("[SettingsManager] Initialized with hotkeyEnabled=\(hotkeyEnabled), modelSize=\(modelSize.rawValue), autoLaunchEnabled=\(autoLaunchEnabled), textPolishEnabled=\(textPolishEnabled), asrLanguage=\(asrLanguage.rawValue)")

        // Apply auto-launch setting on initialization
        applyAutoLaunchSetting()
    }

    private func registerDefaults() {
        let defaults: [String: Any] = [
            Keys.language: Defaults.language,
            Keys.soundEffectsEnabled: Defaults.soundEffectsEnabled,
            Keys.voiceEnabled: Defaults.voiceEnabled,
            Keys.voiceLanguage: Defaults.voiceLanguage,
            Keys.voiceSensitivity: Defaults.voiceSensitivity
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Auto-Launch

    private func applyAutoLaunchSetting() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp

            do {
                if autoLaunchEnabled {
                    if service.status == .enabled {
                        NSLog("[SettingsManager] Auto-launch already enabled")
                    } else {
                        try service.register()
                        NSLog("[SettingsManager] Auto-launch registered successfully")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        NSLog("[SettingsManager] Auto-launch unregistered successfully")
                    } else {
                        NSLog("[SettingsManager] Auto-launch already disabled")
                    }
                }
            } catch {
                NSLog("[SettingsManager] Failed to update auto-launch setting: \(error.localizedDescription)")
            }
        } else {
            NSLog("[SettingsManager] Auto-launch requires macOS 13.0 or later")
        }
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

    // MARK: - Corruption Handling

    private func logCorruptedSetting(key: String, value: Any, defaultValue: Any) {
        NSLog("⚠️ SettingsManager: Corrupted setting detected for key '\(key)'. Found: '\(value)', using default: '\(defaultValue)'")
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
        voiceEnabled = Defaults.voiceEnabled
        voiceLanguage = Defaults.voiceLanguage
        voiceSensitivity = Defaults.voiceSensitivity
    }

    // MARK: - LLM Settings

    /// Save LLM settings to UserDefaults (excluding API key)
    private func saveLLMSettings() {
        // Save settings without API key (stored in Keychain)
        var settingsToSave = llmSettings
        let apiKey = settingsToSave.apiKey
        settingsToSave.apiKey = ""  // Don't store in UserDefaults

        if let data = try? JSONEncoder().encode(settingsToSave) {
            UserDefaults.standard.set(data, forKey: Keys.llmSettings)
        }

        // Save API key to Keychain if not empty
        if !apiKey.isEmpty {
            do {
                try KeychainHelper.saveAPIKey(apiKey)
            } catch {
                NSLog("[SettingsManager] Failed to save API key to Keychain: \(error)")
            }
        }
    }

    /// Load LLM settings (static version for init)
    private static func loadLLMSettingsStatic() -> LLMSettings {
        var settings: LLMSettings

        if let data = UserDefaults.standard.data(forKey: Keys.llmSettings),
           let decoded = try? JSONDecoder().decode(LLMSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }

        // Load API key from Keychain
        if let apiKey = KeychainHelper.loadAPIKey() {
            settings.apiKey = apiKey
        }

        return settings
    }

    /// Reload LLM settings from storage
    func reloadLLMSettings() {
        llmSettings = Self.loadLLMSettingsStatic()
    }
}
