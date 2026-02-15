import Foundation

/// ASR 后端类型
enum ASRBackendType: String, Codable, CaseIterable {
    case native = "native"       // qwen3-asr-swift 原生
    case websocket = "websocket" // Python WebSocket 服务器

    var displayName: String {
        switch self {
        case .native: return "本地引擎 (Native)"
        case .websocket: return "WebSocket 服务器"
        }
    }
}

/// 原生模型 ID
enum NativeModelID: String, Codable, CaseIterable {
    case qwen3_0_6B_4bit = "mlx-community/Qwen3-ASR-0.6B-4bit"
    case qwen3_0_6B_8bit = "mlx-community/Qwen3-ASR-0.6B-8bit"
    case qwen3_1_7B_4bit = "mlx-community/Qwen3-ASR-1.7B-4bit"
    case qwen3_1_7B_8bit = "mlx-community/Qwen3-ASR-1.7B-8bit"

    var displayName: String {
        switch self {
        case .qwen3_0_6B_4bit: return "Qwen3-ASR 0.6B (4-bit)"
        case .qwen3_0_6B_8bit: return "Qwen3-ASR 0.6B (8-bit)"
        case .qwen3_1_7B_4bit: return "Qwen3-ASR 1.7B (4-bit)"
        case .qwen3_1_7B_8bit: return "Qwen3-ASR 1.7B (8-bit)"
        }
    }

    var modelSize: String {
        switch self {
        case .qwen3_0_6B_4bit: return "~400MB"
        case .qwen3_0_6B_8bit: return "~800MB"
        case .qwen3_1_7B_4bit: return "~1.3GB"
        case .qwen3_1_7B_8bit: return "~2.5GB"
        }
    }

    var estimatedRAM: String {
        switch self {
        case .qwen3_0_6B_4bit: return "~800MB"
        case .qwen3_0_6B_8bit: return "~1.2GB"
        case .qwen3_1_7B_4bit: return "~2GB"
        case .qwen3_1_7B_8bit: return "~3.5GB"
        }
    }

    var parameterCount: String {
        switch self {
        case .qwen3_0_6B_4bit, .qwen3_0_6B_8bit: return "0.6B"
        case .qwen3_1_7B_4bit, .qwen3_1_7B_8bit: return "1.7B"
        }
    }

    var quantization: String {
        switch self {
        case .qwen3_0_6B_4bit, .qwen3_1_7B_4bit: return "4-bit"
        case .qwen3_0_6B_8bit, .qwen3_1_7B_8bit: return "8-bit"
        }
    }
}

/// ASR 录音模式
enum ASRMode: String {
    case voiceInput = "voice_input"
    case subtitle = "subtitle"
}

/// ASR 会话配置
struct ASRSessionConfig {
    let mode: ASRMode
    let language: ASRLanguage
    let enablePolish: Bool
    let useLLMPolish: Bool
    let modelId: String
    let hotwords: [String]
    let scene: SceneSessionInfo?
    let useTimestamps: Bool
    let enableDenoise: Bool
    let activeApp: [String: String]
}

/// 场景会话信息
struct SceneSessionInfo {
    let type: String
    let polishStyle: String
    let customPrompt: String?
}

/// ASR 后端协议
protocol ASRBackend: AnyObject {
    /// 转录完成回调
    var onTranscriptionResult: ((String) -> Void)? { get set }
    /// 实时部分结果回调 (text, trigger)
    var onPartialResult: ((String, String) -> Void)? { get set }
    /// LLM 润色更新回调
    var onPolishUpdate: ((String) -> Void)? { get set }
    /// 连接状态变化回调
    var onConnectionStatusChanged: ((Bool) -> Void)? { get set }
    /// 错误状态变化回调
    var onErrorStateChanged: ((Bool, String?) -> Void)? { get set }
    /// 原始文本回调
    var onOriginalTextReceived: ((String) -> Void)? { get set }
    /// 润色方法回调
    var onPolishMethodReceived: ((String) -> Void)? { get set }

    /// 是否已连接/就绪
    var isReady: Bool { get }

    /// 连接/初始化
    func connect()
    /// 断开/清理
    func disconnect()
    /// 开始 ASR 会话
    func startSession(config: ASRSessionConfig, completion: @escaping () -> Void)
    /// 停止 ASR 会话
    func stopSession(completion: @escaping () -> Void)
    /// 喂入音频数据
    func feedAudioChunk(_ data: Data)
    /// 等待音频发送完成后停止
    func flushAndStop(completion: @escaping () -> Void)
}

/// ASRBackend 默认实现
extension ASRBackend {
    func startSession(config: ASRSessionConfig) {
        startSession(config: config, completion: {})
    }

    func stopSession() {
        stopSession(completion: {})
    }
}
