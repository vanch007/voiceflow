import Foundation
import Combine
import ServiceManagement
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

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .chinese: return "中文"
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
        }
    }
}

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

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

    @Published var asrLanguage: ASRLanguage {
        didSet {
            if let encoded = try? JSONEncoder().encode(asrLanguage) {
                UserDefaults.standard.set(encoded, forKey: Keys.asrLanguage)
                NSLog("[SettingsManager] ASR language changed to: \(asrLanguage.rawValue)")
            }
        }
    }

    private enum Keys {
        static let hotkeyEnabled = "hotkeyEnabled"
        static let modelSize = "modelSize"
        static let autoLaunchEnabled = "autoLaunchEnabled"
        static let asrLanguage = "asrLanguage"
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

        // Load ASR language (default: auto)
        if let data = UserDefaults.standard.data(forKey: Keys.asrLanguage),
           let decoded = try? JSONDecoder().decode(ASRLanguage.self, from: data) {
            self.asrLanguage = decoded
        } else {
            self.asrLanguage = .auto
        }

        NSLog("[SettingsManager] Initialized with hotkeyEnabled=\(hotkeyEnabled), modelSize=\(modelSize.rawValue), autoLaunchEnabled=\(autoLaunchEnabled), textPolishEnabled=\(textPolishEnabled), asrLanguage=\(asrLanguage.rawValue)")

        // Apply auto-launch setting on initialization
        applyAutoLaunchSetting()
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
}
