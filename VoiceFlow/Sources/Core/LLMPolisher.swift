import Foundation

/// Swift 原生 LLM 润色器
/// 直接调用 OpenAI 兼容 API（Ollama, vLLM, OpenAI 等），无需 Python 服务器
final class LLMPolisher {
    static let shared = LLMPolisher()

    private let session = URLSession(configuration: .default)
    private let textPolisher = TextPolisher.shared
    private let timeout: TimeInterval = 15.0

    // MARK: - 场景提示词（移植自 server/llm_polisher.py）

    static let defaultPolishPrompts: [String: String] = [
        "general": """
            修正语音识别错误。只输出修正后的文本，不要解释。

            示例1:
            输入: 他门在那里
            输出: 他们在那里

            示例2:
            输入: 我想要在试一下
            输出: 我想要再试一下

            示例3:
            输入: 嗯嗯那个就是说我觉得
            输出: 我觉得

            现在修正以下文本：
            """,
        "coding": """
            修正语音识别错误，识别编程术语。只输出修正后的文本，不要解释。

            术语对照：派森→Python、克劳德→Claude、阿派→API、吉特→Git

            示例1:
            输入: 我用派森写代码
            输出: 我用Python写代码

            示例2:
            输入: 调用克劳德的阿派
            输出: 调用Claude的API

            现在修正以下文本：
            """,
        "writing": """
            修正语音识别错误，优化标点。只输出修正后的文本，不要解释。

            示例1:
            输入: 他门去了那里然后又回来了
            输出: 他们去了那里，然后又回来了。

            现在修正以下文本：
            """,
        "social": """
            修正语音识别错误。只输出修正后的文本，不要解释，不要改变原意。

            示例1:
            输入: 他门好厉害
            输出: 他们好厉害

            示例2:
            输入: 在见啊
            输出: 再见啊

            现在修正以下文本：
            """,
        "medical": """
            修正语音识别错误，正确识别医学专业术语。只输出修正后的文本。
            术语：西踢→CT、核磁→MRI、心电→ECG、彩超→B超
            直接输出修正后的文本：
            """,
        "legal": """
            修正语音识别错误，正确识别法律专业术语。只输出修正后的文本。
            直接输出修正后的文本：
            """,
        "technical": """
            修正语音识别错误，正确识别技术标准和硬件术语。只输出修正后的文本。
            直接输出修正后的文本：
            """,
        "finance": """
            修正语音识别错误，正确识别金融专业术语。只输出修正后的文本。
            直接输出修正后的文本：
            """,
        "engineering": """
            修正语音识别错误，正确识别工程专业术语。只输出修正后的文本。
            直接输出修正后的文本：
            """,
    ]

    // MARK: - Public API

    /// 异步 LLM 润色
    /// - Returns: (polished_text, method: "llm"/"rules"/"none")
    func polishAsync(
        text: String,
        scene: SceneSessionInfo?,
        useLLM: Bool,
        llmSettings: LLMSettings
    ) async -> (String, String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (text, "none")
        }

        // 尝试 LLM 润色
        if useLLM && llmSettings.isEnabled && !llmSettings.apiURL.isEmpty {
            do {
                let prompt = getPrompt(scene: scene)
                let polished = try await callLLMAPI(
                    text: text,
                    prompt: prompt,
                    settings: llmSettings
                )
                if !polished.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NSLog("[LLMPolisher] LLM polish success: '%@' -> '%@'",
                          String(text.prefix(30)), String(polished.prefix(30)))
                    return (polished, "llm")
                }
            } catch {
                NSLog("[LLMPolisher] LLM polish failed, falling back to rules: %@", error.localizedDescription)
            }
        }

        // 降级到规则润色
        let polished = textPolisher.polish(text)
        return (polished, "rules")
    }

    /// 测试 LLM 连接
    func testConnection(settings: LLMSettings) async -> (Bool, Int?) {
        let startTime = Date()
        do {
            _ = try await callLLMAPI(
                text: "测试",
                prompt: "回复OK",
                settings: settings
            )
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return (true, latency)
        } catch {
            return (false, nil)
        }
    }

    // MARK: - Private

    private func getPrompt(scene: SceneSessionInfo?) -> String {
        if let customPrompt = scene?.customPrompt, !customPrompt.isEmpty {
            return customPrompt
        }
        let sceneType = scene?.type ?? "general"
        return Self.defaultPolishPrompts[sceneType] ?? Self.defaultPolishPrompts["general"]!
    }

    /// 调用 OpenAI 兼容 API
    private func callLLMAPI(text: String, prompt: String, settings: LLMSettings) async throws -> String {
        guard let url = URL(string: settings.apiURL + "/v1/chat/completions") else {
            throw LLMPolisherError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = timeout

        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 1024,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMPolisherError.httpError(statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMPolisherError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LLMPolisherError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid LLM API URL"
        case .httpError(let code): return "LLM API returned HTTP \(code)"
        case .invalidResponse: return "Invalid response from LLM API"
        }
    }
}
