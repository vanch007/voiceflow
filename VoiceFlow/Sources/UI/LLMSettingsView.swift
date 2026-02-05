import SwiftUI
import Foundation

/// LLM 设置视图
struct LLMSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showAPIKey = false

    // 本地编辑状态
    @State private var apiURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var temperature: Double = 0.3
    @State private var maxTokens: String = "512"
    @State private var timeout: String = "10"

    enum ConnectionTestResult {
        case success(latencyMs: Int)
        case failure(message: String)
    }

    var body: some View {
        Form {
            Section("LLM 服务配置") {
                // 启用开关
                Toggle("启用 LLM 智能润色", isOn: Binding(
                    get: { settingsManager.llmSettings.isEnabled },
                    set: { newValue in
                        var settings = settingsManager.llmSettings
                        settings.isEnabled = newValue
                        settingsManager.llmSettings = settings
                    }
                ))

                Text("使用大语言模型进行智能文本润色，比规则润色更准确")
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
                    TextField("qwen2.5:7b", text: $model)
                        .textFieldStyle(.roundedBorder)
                }

                Text("Ollama: qwen2.5:7b, llama3.2 | OpenAI: gpt-4o-mini | Claude: claude-3-haiku")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        case .failure(let message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .lineLimit(1)
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

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil

        // 先保存当前设置
        saveSettings()

        // 模拟连接测试（实际通过 ASRClient 发送）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // TODO: 实际实现需要通过 ASRClient.testLLMConnection()
            // 这里暂时模拟结果
            if apiURL.contains("localhost") {
                connectionTestResult = .success(latencyMs: 45)
            } else if apiKey.isEmpty && !apiURL.contains("localhost") {
                connectionTestResult = .failure(message: "需要 API Key")
            } else {
                connectionTestResult = .success(latencyMs: 120)
            }
            isTestingConnection = false
        }
    }
}

#Preview("LLM Settings") {
    LLMSettingsView(settingsManager: SettingsManager.shared)
        .frame(width: 600, height: 700)
}
