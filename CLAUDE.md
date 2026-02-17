# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceFlow is a macOS menu bar app for voice-to-text transcription. It captures audio via AVCaptureSession, sends it to a local ASR backend (either Native MLX-based Qwen3-ASR or WebSocket Python server), and injects transcription results into the active application. It also supports system audio capture for real-time subtitle display.

**Key Features:**
- Option key long-press to start/stop microphone recording
- Control key double-tap to toggle system audio subtitle mode
- Real-time audio capture with 16kHz resampling
- **Dual ASR Backends**: Native MLX-based Qwen3-ASR (Apple Silicon) or WebSocket Python server
- WebSocket connection with auto-reconnect
- Text polish feature with AI enhancement
- Plugin system for extensible post-ASR processing
- System audio capture via BlackHole virtual audio device with subtitle overlay

## Build & Run

```bash
# Quick start (builds if needed, then launches from /Applications/)
./run.sh

# Build and install to /Applications/VoiceFlow.app (using Swift Package Manager)
scripts/build-spm.sh

# Python environment setup (first time)
scripts/setup.sh

# Start ASR server only
scripts/start-server.sh
```

**Important:**
- `run.sh` automatically calls `build-spm.sh` on first run if app doesn't exist
- `run.sh` uses `open` command to launch from `/Applications/` (ensures TCC permissions work)
- Environment variables are passed via `launchctl setenv`
- Project uses **Swift Package Manager (SPM)** for building (migrated Feb 16, 2026)

**Requirements:**
- macOS 14.0+ (Sonoma)
- Xcode 16+ with Command Line Tools
- Python 3.11+
- Accessibility permissions (for global hotkey monitoring)
- Microphone permissions (for audio recording)
- Screen capture permissions (for system audio recording, optional)

## Build System Details

### Build Scripts

| Script | Purpose | Details |
|--------|---------|---------|
| `run.sh` | Quick start with auto-build | Checks if app exists in `/Applications/`, builds if missing, then launches via `open` command |
| `scripts/build-spm.sh` | Build with SPM & install | Builds with `swift build -c debug`, creates app bundle, handles MLX metallib files |
| `scripts/setup.sh` | Python environment setup | Creates `.venv` and installs server dependencies (`requirements.txt`) |
| `scripts/start-server.sh` | Start ASR server only | Activates venv and runs `server/main.py` |

**Migration Note:** Project migrated from Xcode `xcodebuild` to **Swift Package Manager (SPM)** on Feb 16, 2026. The old `xcodebuild` approach is deprecated.

## Testing

```bash
# Python server tests (all)
cd server && pytest tests/

# Python single test
cd server && pytest tests/test_file.py::test_function -v

# Swift tests (via SPM)
cd VoiceFlow && swift test
```

## Architecture

### Swift App (`VoiceFlow/Sources/`)

**App Layer** (`App/`)
- `VoiceFlowApp.swift`: SwiftUI app entry point
- `AppDelegate.swift`: Coordinates all managers, spawns Python ASR server, manages both microphone and system audio recording lifecycles

**Core Services** (`Core/`)
- `HotkeyManager.swift`: Global hotkey detection via CGEvent tap, delegates to `HotkeyConfig` for trigger behavior
- `HotkeyConfig.swift`: Hotkey configuration (trigger type: doubleTap/longPress/freeSpeak, keyCode, modifiers, interval) with preset collections for voice input and system audio
- `AudioRecorder.swift`: AVCaptureSession-based microphone audio capture with format conversion
- `SystemAudioRecorder.swift`: System audio capture via BlackHole virtual audio device
- `ASRClient.swift`: WebSocket client for ASR server communication, supports `voice_input` and `subtitle` modes
- `ASRBackend.swift`: ASR backend protocol and backend type enum (native/websocket)
- `ASRManager.swift`: ASR backend switching and management, coordinates between Native and WebSocket backends
- `NativeASREngine.swift`: Native MLX-based Qwen3-ASR implementation using qwen3-asr-swift package
- `TextInjector.swift`: CGEvent-based text injection into active apps
- `TextReplacementEngine.swift`: Applies scene-aware text replacement rules from ReplacementStorage and converts Chinese numbers to Arabic numbers
- `SettingsManager.swift`: User preferences management
- `SystemAudioSettings.swift`: Subtitle style and transcript storage configuration
- `TranscriptStorage.swift`: Persistent transcript file storage for system audio recordings
- `PermissionPoller.swift`: Polls permission status every second, auto-callback on grant
- `ScreenCapturePermission.swift`: ScreenCaptureKit permission management
- `ReplacementRule.swift` / `ReplacementStorage.swift`: Text replacement rules with scene filtering
- `PromptManager.swift`: Scene prompt management (fetches from server)
- `LLMSettings.swift`: LLM configuration with Keychain storage for API keys

**Scene System** (`Core/Scene/`)
- `SceneManager.swift`: Detects active app via NSWorkspace observer, auto-switches transcription context (e.g., coding → social → writing)
- `SceneProfile.swift`: Scene configuration profiles — language, polish rules, LLM prompts per scene
- `SceneType.swift`: 9 domain-specific scene types (general, social, coding, writing, medical, legal, technical, finance, engineering) with localized names and icons
- `SceneRule.swift`: Maps app bundle IDs to scene types with built-in rules (e.g., WeChat→social, Xcode→coding, Obsidian→writing)

**UI Layer** (`UI/`)
- `StatusBarController.swift`: Menu bar item, status management, system audio toggle menu
- `OverlayPanel.swift`: Visual recording indicator (bottom of screen, for mic recording)
- `SubtitlePanel.swift`: Real-time subtitle overlay for system audio (auto-splits by punctuation, adaptive width)
- `SettingsWindow.swift`: Settings UI wrapper
- `SettingsWindowController.swift`: NSWindowController bridging AppKit window to SwiftUI SettingsContentView with tab navigation
- `HotkeySettingsWindow.swift`: Dedicated hotkey configuration UI with preset radio buttons and conflict warning
- `LLMSettingsView.swift`: LLM connection configuration UI (API key, endpoint, model selection)
- `PluginSettingsView.swift`: Plugin management UI
- `SceneSettingsView.swift`: Scene configuration UI (profile editing, rule management, prompt customization)
- `OnboardingWindow.swift`: First-launch permission setup (auto-skips granted permissions)
- `OnboardingSteps/HotkeyPracticeView.swift`: Onboarding step for hotkey detection practice
- `PermissionAlertWindow.swift`: Permission alert with auto-detect and restart button

### Python ASR Server (`server/`)

- `main.py`: WebSocket server (ws://localhost:9876), handles audio streaming, VAD transcription, and subtitle mode with periodic transcription
- `mlx_asr.py`: MLX-based Qwen3-ASR wrapper for Apple Silicon GPU acceleration
- `audio_denoiser.py`: Audio preprocessing and noise reduction before transcription
- `text_polisher.py`: AI text enhancement using LLM and rule-based polishing
- `scene_polisher.py`: Scene-aware context application (applies scene-specific text transformations)
- `llm_client.py`: OpenAI-compatible LLM client (supports Ollama, vLLM, OpenAI)
- `llm_polisher.py`: LLM-based text polisher with rule fallback and app-aware context
- `prompt_config.py`: User custom prompt persistence
- `history_analyzer.py`: Recording history analysis for keyword extraction
- `plugin_loader.py`: Dynamic plugin loading system (`importlib`-based)
- `plugin_api.py`: Plugin interface and execution API

### Plugin System (`Plugins/`)

Extensible post-ASR processing plugins. Each plugin has a `manifest.json` describing its capabilities.
- `ChinesePunctuationPlugin`: Chinese punctuation normalization
- `Examples/`: Sample plugins (PunctuationPlugin, UppercasePlugin)

### Data Flow

**Microphone Recording (Option long-press):**
```
HotkeyManager triggers recording
  → AudioRecorder captures mic input → resamples to 16kHz Float32
  → ASRClient sends audio chunks via WebSocket (mode: "voice_input")
  → Python server:
    - audio_denoiser: Preprocesses audio (noise reduction)
    - mlx_asr: Transcribes with Qwen3-ASR (MLX)
    - scene_polisher: Applies scene-aware transformations
    - text_polisher: Optional LLM enhancement + rule-based polish
    - Plugins: Sequential plugin pipeline processing
  → TextInjector pastes final text into active app
```

**System Audio Subtitle (Control double-tap):**
```
HotkeyManager detects double-tap Control
  → SystemAudioRecorder captures via BlackHole virtual device
  → ASRClient sends audio chunks via WebSocket (mode: "subtitle")
  → Python server:
    - Sliding window (6s) + periodic trigger (1.5s)
    - audio_denoiser: Preprocesses audio
    - mlx_asr: Real-time transcription
    - scene_polisher + text_polisher: Polish (if enabled)
  → SubtitlePanel displays real-time subtitle overlay
  → TranscriptStorage saves transcript to disk
```

### WebSocket Protocol

**Client → Server:**
- `{"type": "start", "mode": "voice_input"|"subtitle", "model": "...", "language": "...", "enable_polish": "true"|"false"}` - Start session
- `{"type": "stop"}` - End session
- Binary audio data (Float32, 16kHz, mono)

**Server → Client:**
- `{"type": "final", "text": "...", "polish_method": "llm"|"rules"|"none"}` - Final transcription result
- `{"type": "partial", "text": "...", "trigger": "pause"|"periodic"}` - Partial result during recording
- `{"type": "test_llm_connection_result", "success": bool, "latency_ms": int}` - LLM connection test
- `{"type": "analysis_result", "result": {...}}` - History analysis result

**LLM Configuration Messages:**
- `{"type": "config_llm", "config": {...}}` - Configure LLM connection (Client → Server)
- `{"type": "test_llm_connection"}` - Test LLM service availability (Client → Server)
- `{"type": "analyze_history", "entries": [...], "app_name": "..."}` - Analyze recording history (Client → Server)

## Key Features Detail

| Feature | Description | Key Files |
|---------|-------------|-----------|
| Two-Phase Polish | 快速返回基础结果，异步推送 LLM 增强结果 | `ASRClient.swift`, `server/main.py` |
| FreeSpeak Mode | 切换式录音，静音检测自动停止 | `HotkeyConfig.swift`, `AudioRecorder.swift` |
| Context-Aware Polish | 根据活跃应用自动选择润色场景 | `ASRClient.swift`, `llm_polisher.py` |
| Scene Profiles | 场景配置：语言、润色规则、LLM 提示词 | `Core/Scene/SceneProfile.swift` |
| Text Replacement | 场景感知替换规则，支持大小写敏感 | `ReplacementRule.swift`, `ReplacementStorage.swift` |
| VAD Transcription | 基于停顿检测触发转录（300ms 静音阈值） | `AudioRecorder.swift` |
| System Audio Subtitle | 系统音频实时字幕，定时转录+滑动窗口 | `SystemAudioRecorder.swift`, `SubtitlePanel.swift`, `server/main.py` |
| Permission Auto-Detect | 权限轮询自动检测，授权后自动继续 | `PermissionPoller.swift`, `OnboardingWindow.swift` |

## Key Files for Common Tasks

| Task | Files |
|------|-------|
| Modify hotkey behavior | `VoiceFlow/Sources/Core/HotkeyManager.swift` + `HotkeyConfig.swift` |
| Configure hotkey presets | `VoiceFlow/Sources/Core/HotkeyConfig.swift` + `UI/HotkeySettingsWindow.swift` |
| Change mic audio processing | `VoiceFlow/Sources/Core/AudioRecorder.swift` |
| Change system audio capture | `VoiceFlow/Sources/Core/SystemAudioRecorder.swift` |
| Switch ASR backend (Native/WebSocket) | `VoiceFlow/Sources/Core/ASRBackend.swift` + `ASRManager.swift` + `NativeASREngine.swift` |
| Adjust WebSocket protocol | `VoiceFlow/Sources/Core/ASRClient.swift` + `server/main.py` |
| Add UI elements to menu bar | `VoiceFlow/Sources/UI/StatusBarController.swift` |
| Modify subtitle display | `VoiceFlow/Sources/UI/SubtitlePanel.swift` |
| Modify Native ASR model | `VoiceFlow/Sources/Core/NativeASREngine.swift` (via qwen3-asr-swift) |
| Modify Python ASR model | `server/mlx_asr.py` |
| Audio denoising & preprocessing | `server/audio_denoiser.py` |
| Add text post-processing | `server/text_polisher.py` or create new plugin |
| Scene-aware text transformation | `server/scene_polisher.py` |
| Configure LLM polish | `VoiceFlow/Sources/Core/LLMSettings.swift` + `server/llm_client.py` + `UI/LLMSettingsView.swift` |
| Modify text replacement | `VoiceFlow/Sources/Core/TextReplacementEngine.swift` + `ReplacementRule.swift` |
| Add/modify scene types | `VoiceFlow/Sources/Core/Scene/SceneType.swift` + `SceneRule.swift` |
| Scene detection logic | `VoiceFlow/Sources/Core/Scene/SceneManager.swift` |
| Settings UI tabs | `VoiceFlow/Sources/UI/SettingsWindowController.swift` |
| System audio settings | `VoiceFlow/Sources/Core/SystemAudioSettings.swift` + `VoiceFlow/Sources/UI/SettingsWindow.swift` |
| Plugin loading & management | `server/plugin_loader.py` + `server/plugin_api.py` |

## Debugging

### Audio Capture
```
[AudioRecorder] Audio device: MacBook Pro Microphone
[AudioRecorder] Recording started.
```

### System Audio
System audio debug logs are written to `~/Library/Application Support/VoiceFlow/system_audio.log` (NSLog may be filtered by the system).

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

**Important:** After each rebuild with `scripts/build-spm.sh`, accessibility permissions need re-authorization: System Settings → Privacy & Security → Accessibility → remove VoiceFlow (- button) → re-add (+ button).

### ASR Server
Check Python server logs for transcription errors:
```
[ASRServer] stderr: 2026-02-02 [INFO] 🎤 开始录音
[ASRServer] stderr: 2026-02-02 [INFO] ✅ 转录完成
```

## Code Guidelines

- Use `NSLog()` for important events, `Logger` (os.log) for detailed debug
- Audio processing on `sessionQueue` / `processingQueue` background threads; UI updates on `DispatchQueue.main`
- WebSocket reconnection is automatic - don't manually retry in UI code
- When `language` is "auto", pass `None` to MLX model
- System audio recording state (`isSystemAudioRecording`) must wait for ASR `final` result before resetting — don't reset on stop, or `onTranscriptionResult` will discard the result
- SubtitlePanel uses single `fullText` source, splits into two lines at render time by punctuation — never maintain two independent line states
- Text replacement uses only `TextReplacementEngine` (not `ReplacementStorage.applyReplacements`). The engine supports fuzzy matching by stripping trailing punctuation when exact match fails
- Python server uses Python 3.9+ built-in generics (`list[str]`, `dict[str, Any]`) — do NOT use `typing.List`, `typing.Dict` etc.

## Permissions Required

1. **Microphone Access**: Required for `AudioRecorder` to capture audio
2. **Accessibility Access**: Required for `HotkeyManager` global event monitoring and `TextInjector` text injection
3. **Screen Capture Access** (optional): Required for `SystemAudioRecorder` to capture system audio via BlackHole

Permissions 1 and 2 are requested automatically on first launch. Permission 3 is requested when system audio recording is first triggered.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VOICEFLOW_PYTHON` | Python interpreter path | `<project_root>/.venv/bin/python3` |
| `VOICEFLOW_PROJECT_ROOT` | Project root directory | Set by `run.sh` via `launchctl setenv` |

## Known Issues & Solutions

### WebSocket Connection Race Condition
ASRClient 的 WebSocket 连接可能出现 `NSURLErrorDomain Code=-999 "cancelled"` 错误。原因是 `URLSessionWebSocketTask.resume()` 后立即发送 ping，此时握手可能尚未完成。

**解决方案**（已在代码中实现）：
- 在 ping 前添加 500ms 延迟等待握手完成
- 使用 `===` 身份检查确保异步回调操作的是当前连接
- 取消旧的重连任务防止并发冲突
- `handleDisconnect()` 仅在状态从已连接变为断开时发送通知

### System Audio Recording Setup
系统音频录制需要 BlackHole 虚拟音频设备。用户需要在「音频 MIDI 设置」中创建「多输出设备」，将音频同时输出到扬声器和 BlackHole。

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
