import SwiftUI
import Foundation

/// LLM 设置视图
struct LLMSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    let asrClient: ASRClient
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showAPIKey = false
    @State private var isLoadingModels = false

    // 本地编辑状态
    @State private var apiURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var temperature: Double = 0.3
    @State private var maxTokens: String = "512"
    @State private var timeout: String = "10"
    @State private var availableModels: [String] = []

    enum ConnectionTestResult {
        case success(latencyMs: Int)
        case failure(message: String, suggestion: String? = nil)
    }

    var body: some View {
        Form {
            Section("AI 纠错") {
                // 启用开关
                Toggle("启用 AI 纠错", isOn: Binding(
                    get: { settingsManager.llmSettings.isEnabled },
                    set: { newValue in
                        var settings = settingsManager.llmSettings
                        settings.isEnabled = newValue
                        settingsManager.llmSettings = settings
                    }
                ))

                Text("使用 AI 自动纠正语音识别错误（同音字、语气词、断句等）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("API 设置") {
                // API URL
                HStack {
                    Text("API 地址")
                        .frame(width: 80, alignment: .leading)
                    TextField("http://localhost:11434/v1", text: $apiURL)
                        .textFieldStyle(.roundedBorder)
                }

                // API Key
                HStack {
                    Text("API Key")
                        .frame(width: 80, alignment: .leading)
                    if showAPIKey {
                        TextField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                Text("使用 Ollama 本地服务时无需填写 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 模型名称
                HStack {
                    Text("模型")
                        .frame(width: 80, alignment: .leading)

                    if availableModels.isEmpty {
                        TextField("qwen2.5:7b", text: $model)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: $model) {
                            ForEach(availableModels, id: \.self) { modelName in
                                Text(modelName).tag(modelName)
                            }
                        }
                        .labelsHidden()
                    }

                    Button(action: refreshModels) {
                        HStack(spacing: 4) {
                            if isLoadingModels {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoadingModels)
                    .help("刷新可用模型列表")
                }

                if availableModels.isEmpty {
                    Text("Ollama: qwen2.5:7b, llama3.2 | OpenAI: gpt-4o-mini | Claude: claude-3-haiku")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("已发现 \(availableModels.count) 个可用模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("高级设置") {
                // 温度
                HStack {
                    Text("温度")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                    Text(String(format: "%.1f", temperature))
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                }

                Text("较低温度 (0.1-0.3) 输出更稳定，较高温度 (0.7-1.0) 更有创意")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Max Tokens
                HStack {
                    Text("最大长度")
                        .frame(width: 80, alignment: .leading)
                    TextField("512", text: $maxTokens)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("tokens")
                        .foregroundColor(.secondary)
                }

                // Timeout
                HStack {
                    Text("超时时间")
                        .frame(width: 80, alignment: .leading)
                    TextField("10", text: $timeout)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("秒")
                        .foregroundColor(.secondary)
                }
            }

            Section("连接测试") {
                HStack {
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text("测试连接")
                        }
                    }
                    .disabled(isTestingConnection)

                    Spacer()

                    if let result = connectionTestResult {
                        connectionResultView(result)
                    }
                }

                Button("保存设置") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("重置为默认") {
                    resetToDefaults()
                }
                .foregroundColor(.secondary)
            }

            Section("预设配置") {
                HStack(spacing: 12) {
                    presetButton("Ollama (本地)", url: "http://localhost:11434/v1", model: "qwen2.5:7b")
                    presetButton("vLLM", url: "http://localhost:8000/v1", model: "Qwen/Qwen2.5-7B-Instruct")
                    presetButton("OpenAI", url: "https://api.openai.com/v1", model: "gpt-4o-mini")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadCurrentSettings()
            setupASRClientCallbacks()
        }
    }

    @ViewBuilder
    private func connectionResultView(_ result: ConnectionTestResult) -> some View {
        switch result {
        case .success(let latencyMs):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("连接成功 (\(latencyMs)ms)")
                    .foregroundColor(.green)
            }
        case .failure(let message, let suggestion):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .foregroundColor(.red)
                }

                if let suggestion = suggestion {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func presetButton(_ title: String, url: String, model: String) -> some View {
        Button(title) {
            self.apiURL = url
            self.model = model
            if url.contains("localhost") {
                self.apiKey = ""
            }
        }
        .buttonStyle(.bordered)
    }

    private func loadCurrentSettings() {
        let settings = settingsManager.llmSettings
        apiURL = settings.apiURL
        apiKey = settings.apiKey
        model = settings.model
        temperature = settings.temperature
        maxTokens = String(settings.maxTokens)
        timeout = String(Int(settings.timeout))
    }

    private func saveSettings() {
        var settings = settingsManager.llmSettings
        settings.apiURL = apiURL
        settings.apiKey = apiKey
        settings.model = model
        settings.temperature = temperature
        settings.maxTokens = Int(maxTokens) ?? 512
        settings.timeout = TimeInterval(Int(timeout) ?? 10)
        settingsManager.llmSettings = settings

        // 通知 ASRClient 更新配置
        NotificationCenter.default.post(
            name: SettingsManager.settingsDidChangeNotification,
            object: settingsManager,
            userInfo: ["category": "llm", "key": "settings", "value": settings.isEnabled]
        )
    }

    private func resetToDefaults() {
        let defaults = LLMSettings.default
        apiURL = defaults.apiURL
        apiKey = defaults.apiKey
        model = defaults.model
        temperature = defaults.temperature
        maxTokens = String(defaults.maxTokens)
        timeout = String(Int(defaults.timeout))
    }

    private func setupASRClientCallbacks() {
        // 设置 LLM 连接测试结果回调
        asrClient.onLLMConnectionTestResult = { [self] success, latency in
            DispatchQueue.main.async {
                self.isTestingConnection = false
                if success {
                    self.connectionTestResult = .success(latencyMs: latency ?? 0)
                } else {
                    let suggestion = self.getConnectionFailureSuggestion()
                    self.connectionTestResult = .failure(message: "连接失败", suggestion: suggestion)
                }
            }
        }

        // 设置模型列表回调
        asrClient.onModelListReceived = { [self] models in
            DispatchQueue.main.async {
                self.isLoadingModels = false
                self.availableModels = models

                // 如果当前模型不在列表中且列表不为空，选择第一个
                if !models.isEmpty && !models.contains(self.model) {
                    self.model = models[0]
                }
            }
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        // 先保存当前设置
        saveSettings()

        // 使用 ASRClient 测试 LLM 连接
        Task {
            // 等待一下让设置保存生效
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            DispatchQueue.main.async {
                asrClient.testLLMConnection()
            }

            // 设置超时保护
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s timeout

            DispatchQueue.main.async {
                if self.isTestingConnection {
                    self.isTestingConnection = false
                    let suggestion = self.getTimeoutSuggestion()
                    self.connectionTestResult = .failure(message: "连接超时", suggestion: suggestion)
                }
            }
        }
    }

    private func getConnectionFailureSuggestion() -> String {
        let backend = detectBackend(from: apiURL)

        switch backend {
        case "ollama":
            return "请确保 Ollama 已启动: ollama serve"
        case "vllm":
            return "请检查 vLLM 服务是否运行在 \(apiURL)"
        case "openai":
            if apiURL.contains("openai.com") {
                return "请检查 API Key 是否有效且有余额"
            } else {
                return "请确保 API 服务正在运行"
            }
        case "anthropic":
            return "请检查 API Key 是否有效"
        default:
            return "请检查 API 地址和密钥是否正确"
        }
    }

    private func getTimeoutSuggestion() -> String {
        let backend = detectBackend(from: apiURL)

        switch backend {
        case "ollama":
            return "Ollama 可能未启动，运行: ollama serve"
        case "vllm":
            return "检查模型是否已加载完成"
        case "openai", "anthropic":
            return "检查网络连接或增加超时时间"
        default:
            return "检查服务状态或增加超时时间"
        }
    }

    private func refreshModels() {
        isLoadingModels = true

        // 检测 backend 类型
        let backend = detectBackend(from: apiURL)

        // 请求模型列表
        asrClient.listAvailableModels(backend: backend)

        // 设置超时保护
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s timeout

            DispatchQueue.main.async {
                if self.isLoadingModels {
                    self.isLoadingModels = false
                    self.availableModels = []
                }
            }
        }
    }

    private func detectBackend(from url: String) -> String {
        let lowercased = url.lowercased()
        if lowercased.contains("openai") {
            return "openai"
        } else if lowercased.contains("anthropic") || lowercased.contains("claude") {
            return "anthropic"
        } else if lowercased.contains("11434") {
            return "ollama"
        } else if lowercased.contains("8000") {
            return "vllm"
        } else if lowercased.contains("localhost") {
            return "ollama"  // 默认本地服务为 ollama
        } else {
            return "openai"  // 默认使用 OpenAI 兼容格式
        }
    }
}

#Preview("LLM Settings") {
    LLMSettingsView(settingsManager: SettingsManager.shared, asrClient: ASRClient())
        .frame(width: 600, height: 700)
}
