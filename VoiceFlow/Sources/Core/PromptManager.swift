import Foundation
import Combine

/// 提示词管理器，负责从服务器获取和管理场景提示词
final class PromptManager: ObservableObject {
    static let shared = PromptManager()

    @Published var defaultPrompts: [String: String] = [:]
    @Published var customPrompts: [String: String] = [:]
    @Published var isLoading: Bool = false

    private weak var asrClient: ASRClient?

    private init() {}

    /// 配置 ASRClient 并设置回调
    func configure(with client: ASRClient) {
        self.asrClient = client
        setupCallbacks()
    }

    private func setupCallbacks() {
        asrClient?.onDefaultPromptsReceived = { [weak self] (prompts: [String: String]) in
            DispatchQueue.main.async {
                self?.defaultPrompts = prompts
                self?.isLoading = false
                NSLog("[PromptManager] Default prompts loaded: %d scenes", prompts.count)
            }
        }

        asrClient?.onCustomPromptsReceived = { [weak self] (prompts: [String: String]) in
            DispatchQueue.main.async {
                self?.customPrompts = prompts
                NSLog("[PromptManager] Custom prompts loaded: %d scenes", prompts.count)
            }
        }

        asrClient?.onPromptSaved = { [weak self] (sceneType: String, success: Bool) in
            NSLog("[PromptManager] Prompt saved for %@: %@", sceneType, success ? "success" : "failed")
            if success {
                // 刷新自定义提示词
                self?.asrClient?.requestCustomPrompts()
            }
        }
    }

    /// 从服务器加载所有提示词
    func loadPrompts() {
        isLoading = true
        asrClient?.requestDefaultPrompts()
        asrClient?.requestCustomPrompts()
    }

    /// 获取指定场景的有效提示词（优先自定义，否则默认）
    func getEffectivePrompt(for sceneType: String) -> String {
        return customPrompts[sceneType] ?? defaultPrompts[sceneType] ?? ""
    }

    /// 检查指定场景是否使用自定义提示词
    func isUsingCustomPrompt(for sceneType: String) -> Bool {
        return customPrompts[sceneType] != nil
    }

    /// 保存自定义提示词
    func saveCustomPrompt(for sceneType: String, prompt: String) {
        asrClient?.saveCustomPrompt(sceneType: sceneType, prompt: prompt, useDefault: false)
    }

    /// 重置为默认提示词
    func resetToDefault(for sceneType: String) {
        asrClient?.saveCustomPrompt(sceneType: sceneType, prompt: "", useDefault: true)
        // 立即从本地移除自定义提示词
        DispatchQueue.main.async { [weak self] in
            self?.customPrompts.removeValue(forKey: sceneType)
        }
    }
}
