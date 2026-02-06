# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceFlow is a macOS menu bar app for voice-to-text transcription. It captures audio via AVCaptureSession, sends it to a local WebSocket ASR server (Qwen3-ASR on MLX), and injects transcription results into the active application.

**Key Features:**
- Option key long-press or Control double-tap to start/stop recording
- Real-time audio capture with 16kHz resampling
- MLX-accelerated Qwen3-ASR for Apple Silicon
- WebSocket connection to local ASR server with auto-reconnect
- Text polish feature with AI enhancement
- Plugin system for extensible post-ASR processing

## Build & Run

```bash
# Quick start (build + run with logs)
./run.sh

# Build only using xcodebuild
cd VoiceFlow && xcodebuild -scheme VoiceFlow -configuration Debug build

# Open in Xcode for development
open VoiceFlow/VoiceFlow.xcodeproj

# Python environment setup (first time)
scripts/setup.sh

# Build and bundle app
scripts/build.sh

# Start ASR server only
scripts/start-server.sh
```

**Requirements:**
- macOS 14.0+ (Sonoma)
- Xcode 16+ with Command Line Tools
- Python 3.11+
- Accessibility permissions (for global hotkey monitoring)
- Microphone permissions (for audio recording)

## Testing

```bash
# Python server tests
cd server && pytest tests/

# Swift tests (via Xcode)
cd VoiceFlow && xcodebuild test -scheme VoiceFlow -destination 'platform=macOS'
```

## Architecture

### Swift App (`VoiceFlow/Sources/`)

**App Layer** (`App/`)
- `VoiceFlowApp.swift`: SwiftUI app entry point
- `AppDelegate.swift`: Coordinates all managers, spawns Python ASR server

**Core Services** (`Core/`)
- `HotkeyManager.swift`: Global hotkey detection (Option long-press, Control double-tap) via CGEvent tap
- `AudioRecorder.swift`: AVCaptureSession-based audio capture with format conversion
- `ASRClient.swift`: WebSocket client for ASR server communication
- `TextInjector.swift`: CGEvent-based text injection into active apps
- `SettingsManager.swift`: User preferences management
- `ReplacementRule.swift` / `ReplacementStorage.swift`: Text replacement rules
- `LLMSettings.swift`: LLM configuration with Keychain storage for API keys
- `HistoryAnalysisResult.swift`: Recording history analysis result model

**UI Layer** (`UI/`)
- `StatusBarController.swift`: Menu bar item and status management
- `OverlayPanel.swift`: Visual recording indicator (bottom of screen)
- `SettingsWindow.swift`: Settings UI
- `LLMSettingsView.swift`: LLM configuration interface
- `HistoryAnalysisView.swift`: Recording history analysis results display

### Python ASR Server (`server/`)

- `main.py`: WebSocket server (ws://localhost:9876), handles audio streaming and transcription
- `mlx_asr.py`: MLX-based Qwen3-ASR wrapper for Apple Silicon GPU acceleration
- `text_polisher.py`: AI text enhancement using LLM
- `llm_client.py`: OpenAI-compatible LLM client (supports Ollama, vLLM, OpenAI)
- `llm_polisher.py`: LLM-based text polisher with rule fallback
- `history_analyzer.py`: Recording history analysis for keyword extraction

### Plugin System (`Plugins/`)

Extensible post-ASR processing plugins. Each plugin has a `manifest.json` describing its capabilities.
- `ChinesePunctuationPlugin`: Chinese punctuation normalization
- `Examples/`: Sample plugins (PunctuationPlugin, UppercasePlugin)

### Data Flow

```
User long-presses Option key
  ↓
HotkeyManager triggers recording
  ↓
AudioRecorder captures mic input → resamples to 16kHz Float32
  ↓
ASRClient sends audio chunks via WebSocket
  ↓
Python server transcribes with Qwen3-ASR (MLX)
  ↓
Optional: Text polish with LLM + Plugin processing
  ↓
TextInjector pastes text into active app
```

### WebSocket Protocol

**Client → Server:**
- `{"type": "start", "model": "...", "language": "...", "polish": true/false}` - Start session
- `{"type": "stop"}` - End session
- Binary audio data (Float32, 16kHz, mono)

**Server → Client:**
- `{"type": "final", "text": "...", "polish_method": "llm"|"rules"|"none"}` - Final transcription result
- `{"type": "partial", "text": "..."}` - Partial result during recording
- `{"type": "test_llm_connection_result", "success": bool, "latency_ms": int}` - LLM connection test
- `{"type": "analysis_result", "result": {...}}` - History analysis result

**LLM Configuration Messages:**
- `{"type": "config_llm", "config": {...}}` - Configure LLM connection (Client → Server)
- `{"type": "test_llm_connection"}` - Test LLM service availability (Client → Server)
- `{"type": "analyze_history", "entries": [...], "app_name": "..."}` - Analyze recording history (Client → Server)

## Recent Features

### Two-Phase Polish Strategy
文本润色采用两阶段响应策略减少感知延迟：
1. 第一阶段：快速返回基础润色结果
2. 第二阶段：通过 `polish_update` 消息推送 LLM 增强结果

相关文件：`ASRClient.swift` (onPolishUpdate)、`server/main.py`、`TextInjector.swift`

### FreeSpeak Mode
切换式录音模式（区别于按住触发），支持：
- `HotkeyConfig.swift` 中的 `freeSpeak` 触发类型
- 静音检测自动停止录音（`AudioRecorder.swift` 中的 silence detection）
- `OverlayPanel` 显示静音倒计时

### Context-Aware Polishing
根据活跃应用自动选择润色场景：
- `ASRClient` 在 start 消息中发送 `active_app` 上下文
- `LLMPolisher` 根据应用名称映射到对应场景
- `server/main.py` 合并应用上下文到会话场景

### Scene Profiles (`Core/Scene/`)
- `SceneProfile.swift`: 场景配置模型
- 场景可配置：语言（支持跟随全局设置）、润色规则、LLM 提示词

### Audio Processing Advanced Features
- **VAD Pre-filtering**: 语音活动检测过滤静音段
- **Audio Compression**: Int16 压缩减少传输带宽
- **Adaptive Noise Floor**: 自适应噪声底部追踪
- **SNR Monitoring**: 实时信噪比监测，OverlayPanel 显示信号质量

### Chinese Dialect Support
`server/main.py` 的 `LANGUAGE_MAP` 支持中文方言选项传递给 Qwen3-ASR。

## Key Files for Common Tasks

| Task | Files |
|------|-------|
| Modify hotkey behavior | `VoiceFlow/Sources/Core/HotkeyManager.swift` |
| Change audio processing | `VoiceFlow/Sources/Core/AudioRecorder.swift` |
| Adjust WebSocket protocol | `VoiceFlow/Sources/Core/ASRClient.swift` + `server/main.py` |
| Add UI elements | `VoiceFlow/Sources/UI/StatusBarController.swift` |
| Modify ASR model | `server/mlx_asr.py` |
| Add text post-processing | `server/text_polisher.py` or create new plugin |
| Configure LLM polish | `VoiceFlow/Sources/Core/LLMSettings.swift` + `server/llm_client.py` |
| Add history analysis | `server/history_analyzer.py` + `VoiceFlow/Sources/UI/HistoryAnalysisView.swift` |

## Debugging

### Audio Capture
```
[AudioRecorder] Audio device: MacBook Pro Microphone
[AudioRecorder] Recording started.
```

### WebSocket Connection
Auto-reconnects every 3 seconds on disconnect:
```
[ASRClient] Connected to ws://localhost:9876
[ASRClient] Attempting reconnect...
```

### Hotkey Issues
Verify Accessibility permissions in System Settings → Privacy & Security → Accessibility:
```
[HotkeyManager] FAILED to create event tap! Check permissions.
```

**Important:** Toggle accessibility permission off→on after each rebuild (code signature changes).

### ASR Server
Check Python server logs for transcription errors:
```
[ASRServer] stderr: 2026-02-02 [INFO] 🎤 开始录音
[ASRServer] stderr: 2026-02-02 [INFO] ✅ 转录完成
```

## Code Guidelines

- Use `NSLog()` for important events (connection status, errors)
- Use `Logger` (os.log) for detailed debug info in HotkeyManager
- All audio processing happens on `sessionQueue` background thread
- UI updates must dispatch to `DispatchQueue.main`
- WebSocket reconnection is automatic - don't manually retry in UI code
- When `language` is set to "auto", pass `None` to MLX model (don't pass the parameter)

## Permissions Required

1. **Microphone Access**: Required for `AudioRecorder` to capture audio
2. **Accessibility Access**: Required for `HotkeyManager` global event monitoring and `TextInjector` text injection

Both are requested automatically on first launch.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VOICEFLOW_PYTHON` | Python interpreter path | `<project_root>/.venv/bin/python3` |

## Known Issues & Solutions

### WebSocket Connection Race Condition
ASRClient 的 WebSocket 连接可能出现 `NSURLErrorDomain Code=-999 "cancelled"` 错误。原因是 `URLSessionWebSocketTask.resume()` 后立即发送 ping，此时握手可能尚未完成。

**解决方案**（已在代码中实现）：
- 在 ping 前添加 500ms 延迟等待握手完成
- 使用 `===` 身份检查确保异步回调操作的是当前连接
- 取消旧的重连任务防止并发冲突
- `handleDisconnect()` 仅在状态从已连接变为断开时发送通知

### Plugin System

**插件位置：**
- 内置插件: `Plugins/` 目录（随项目分发）
- 用户插件: `~/Library/Application Support/VoiceFlow/Plugins/`

**自动安装：** ASR 服务器启动时会自动将 `ChinesePunctuationPlugin` 从内置目录复制到用户目录。

**manifest.json 必需字段：**
```json
{
  "name": "PluginName",
  "version": "1.0.0",
  "platform": ["python"],
  "entry_point": "plugin.py"
}
```

**插件生命周期：**
1. 服务器启动时加载所有插件 (`plugin_loader.py`)
2. 每个插件实现 `process(text)` 方法处理转录文本
3. 插件按顺序执行，前一个插件的输出作为下一个的输入
