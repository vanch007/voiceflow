import Foundation
import Combine
import AppKit

/// 场景管理器 - 负责检测当前场景并管理场景配置
final class SceneManager: ObservableObject {
    static let shared = SceneManager()

    // MARK: - Published Properties

    @Published private(set) var currentScene: SceneType = .general
    @Published var isAutoDetectEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoDetectEnabled, forKey: Keys.autoDetectEnabled)
            NSLog("[SceneManager] Auto-detect enabled: \(isAutoDetectEnabled)")
            if isAutoDetectEnabled {
                manualOverride = nil
                detectCurrentScene()
            }
        }
    }
    @Published var manualOverride: SceneType? {
        didSet {
            if let scene = manualOverride {
                currentScene = scene
                NSLog("[SceneManager] Manual override set to: \(scene.rawValue)")
            } else if isAutoDetectEnabled {
                detectCurrentScene()
            }
        }
    }

    // MARK: - Private Properties

    private var profiles: [SceneType: SceneProfile] = [:]
    private var customRules: [SceneRule] = []
    private var workspaceObserver: Any?

    private enum Keys {
        static let autoDetectEnabled = "scene.autoDetectEnabled"
        static let profiles = "scene.profiles"
        static let customRules = "scene.customRules"
    }

    // MARK: - Initialization

    private init() {
        // 加载设置
        self.isAutoDetectEnabled = UserDefaults.standard.object(forKey: Keys.autoDetectEnabled) as? Bool ?? true
        loadProfiles()
        loadCustomRules()

        // 开始监听前台应用变化
        startObservingFrontmostApp()

        // 初始检测
        detectCurrentScene()

        NSLog("[SceneManager] Initialized. Auto-detect: \(isAutoDetectEnabled), Current scene: \(currentScene.rawValue)")
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// 获取当前有效的场景配置
    func getEffectiveProfile() -> SceneProfile {
        let scene = manualOverride ?? currentScene
        return profiles[scene] ?? SceneProfile.defaultProfile(for: scene)
    }

    /// 设置手动场景（nil 表示恢复自动检测）
    func setManualScene(_ scene: SceneType?) {
        if let scene = scene {
            isAutoDetectEnabled = false
            manualOverride = scene
        } else {
            manualOverride = nil
            isAutoDetectEnabled = true
        }
    }

    /// 查找指定 Bundle ID 对应的场景
    func findScene(for bundleID: String) -> SceneType {
        // 先检查自定义规则
        if let rule = customRules.first(where: { $0.bundleID == bundleID }) {
            return rule.sceneType
        }
        // 再检查内置规则
        if let rule = SceneRule.builtinRules.first(where: { $0.bundleID == bundleID }) {
            return rule.sceneType
        }
        return .general
    }

    /// 更新场景配置
    func updateProfile(_ profile: SceneProfile) {
        profiles[profile.sceneType] = profile
        saveProfiles()
        NSLog("[SceneManager] Profile updated for: \(profile.sceneType.rawValue)")
    }

    /// 获取场景配置
    func getProfile(for sceneType: SceneType) -> SceneProfile {
        return profiles[sceneType] ?? SceneProfile.defaultProfile(for: sceneType)
    }

    /// 添加自定义规则
    func addRule(_ rule: SceneRule) {
        // 如果已存在，先移除
        customRules.removeAll { $0.bundleID == rule.bundleID }
        customRules.append(rule)
        saveCustomRules()
        NSLog("[SceneManager] Added rule: \(rule.appName) -> \(rule.sceneType.rawValue)")

        // 如果是当前应用，重新检测
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == rule.bundleID {
            detectCurrentScene()
        }
    }

    /// 移除自定义规则
    func removeRule(bundleID: String) {
        customRules.removeAll { $0.bundleID == bundleID }
        saveCustomRules()
        NSLog("[SceneManager] Removed rule for: \(bundleID)")
    }

    /// 获取所有规则（内置 + 自定义）
    func getAllRules() -> [SceneRule] {
        var allRules = SceneRule.builtinRules
        // 自定义规则覆盖内置规则
        for customRule in customRules {
            allRules.removeAll { $0.bundleID == customRule.bundleID }
            allRules.append(customRule)
        }
        return allRules.sorted { $0.appName < $1.appName }
    }

    /// 获取自定义规则
    func getCustomRules() -> [SceneRule] {
        return customRules
    }

    // MARK: - Private Methods

    private func startObservingFrontmostApp() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    private func handleAppActivation(_ notification: Notification) {
        guard isAutoDetectEnabled, manualOverride == nil else { return }
        detectCurrentScene()
    }

    private func detectCurrentScene() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmostApp.bundleIdentifier else {
            currentScene = .general
            return
        }

        let newScene = findScene(for: bundleID)
        if newScene != currentScene {
            currentScene = newScene
            NSLog("[SceneManager] Scene changed to: \(newScene.rawValue) (app: \(frontmostApp.localizedName ?? bundleID))")
        }
    }

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: Keys.profiles),
              let decoded = try? JSONDecoder().decode([SceneType: SceneProfile].self, from: data) else {
            // 初始化默认配置
            for sceneType in SceneType.allCases {
                profiles[sceneType] = SceneProfile.defaultProfile(for: sceneType)
            }
            return
        }
        profiles = decoded
    }

    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: Keys.profiles)
        }
    }

    private func loadCustomRules() {
        guard let data = UserDefaults.standard.data(forKey: Keys.customRules),
              let decoded = try? JSONDecoder().decode([SceneRule].self, from: data) else {
            return
        }
        customRules = decoded
    }

    private func saveCustomRules() {
        if let encoded = try? JSONEncoder().encode(customRules) {
            UserDefaults.standard.set(encoded, forKey: Keys.customRules)
        }
    }
}
