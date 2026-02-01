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

    private enum Keys {
        static let hotkeyEnabled = "hotkeyEnabled"
        static let modelSize = "modelSize"
        static let autoLaunchEnabled = "autoLaunchEnabled"
    }

    private init() {
        // Load hotkey enabled (default: true)
        self.hotkeyEnabled = UserDefaults.standard.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true

        // Load model size (default: 1.7B)
        if let data = UserDefaults.standard.data(forKey: Keys.modelSize),
           let decoded = try? JSONDecoder().decode(ModelSize.self, from: data) {
            self.modelSize = decoded
        } else {
            self.modelSize = .model1_7B
        }

        // Load auto-launch enabled (default: false)
        self.autoLaunchEnabled = UserDefaults.standard.object(forKey: Keys.autoLaunchEnabled) as? Bool ?? false

        // Load text polish enabled (default: false)
        self.textPolishEnabled = UserDefaults.standard.isTextPolishEnabled

        NSLog("[SettingsManager] Initialized with hotkeyEnabled=\(hotkeyEnabled), modelSize=\(modelSize.rawValue), autoLaunchEnabled=\(autoLaunchEnabled), textPolishEnabled=\(textPolishEnabled)")

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
