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
        self.isAutoDetectEnabled = UserDefaults.standard.object(forKey: Keys.autoDetectEnabled) as? Bool ?? true
        loadProfiles()
        loadCustomRules()
        startObservingFrontmostApp()
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
        if let rule = customRules.first(where: { $0.bundleID == bundleID }) {
            return rule.sceneType
        }
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
        customRules.removeAll { $0.bundleID == rule.bundleID }
        customRules.append(rule)
        saveCustomRules()
        NSLog("[SceneManager] Added rule: \(rule.appName) -> \(rule.sceneType.rawValue)")

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

    // MARK: - Import/Export

    /// Export a scene profile to a file
    func exportScene(sceneType: SceneType, toPath: String) -> Bool {
        let profile = getProfile(for: sceneType)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(profile)
            let url = URL(fileURLWithPath: toPath)
            try data.write(to: url, options: .atomic)
            NSLog("[SceneManager] Successfully exported \(sceneType.rawValue) scene to \(toPath)")
            return true
        } catch {
            NSLog("[SceneManager] Failed to export scene: \(error.localizedDescription)")
            return false
        }
    }

    /// Import a scene profile from a file
    func importScene(fromPath: String) -> Result<SceneProfile, Error> {
        let url = URL(fileURLWithPath: fromPath)

        do {
            let data = try Data(contentsOf: url)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(SceneImportError.invalidJSON)
            }

            guard json["sceneType"] != nil else {
                return .failure(SceneImportError.missingRequiredField("sceneType"))
            }
            guard json["glossary"] != nil else {
                return .failure(SceneImportError.missingRequiredField("glossary"))
            }
            guard json["enablePolish"] != nil else {
                return .failure(SceneImportError.missingRequiredField("enablePolish"))
            }
            guard json["polishStyle"] != nil else {
                return .failure(SceneImportError.missingRequiredField("polishStyle"))
            }

            let decoder = JSONDecoder()
            let profile = try decoder.decode(SceneProfile.self, from: data)

            NSLog("[SceneManager] Successfully imported scene: \(profile.sceneType.rawValue)")
            return .success(profile)

        } catch let error as DecodingError {
            NSLog("[SceneManager] Failed to decode scene profile: \(error)")
            return .failure(SceneImportError.decodingFailed(error))
        } catch {
            NSLog("[SceneManager] Failed to import scene: \(error.localizedDescription)")
            return .failure(error)
        }
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

/// Errors that can occur during scene import
enum SceneImportError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The file does not contain valid JSON data"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .decodingFailed(let error):
            return "Failed to decode scene profile: \(error.localizedDescription)"
        }
    }
}
