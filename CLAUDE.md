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

**UI Layer** (`UI/`)
- `StatusBarController.swift`: Menu bar item and status management
- `OverlayPanel.swift`: Visual recording indicator (bottom of screen)
- `SettingsWindow.swift`: Settings UI

### Python ASR Server (`server/`)

- `main.py`: WebSocket server (ws://localhost:9876), handles audio streaming and transcription
- `mlx_asr.py`: MLX-based Qwen3-ASR wrapper for Apple Silicon GPU acceleration
- `text_polisher.py`: AI text enhancement using LLM

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
- `{"type": "final", "text": "..."}` - Final transcription result
- `{"type": "partial", "text": "..."}` - Partial result during recording

## Key Files for Common Tasks

| Task | Files |
|------|-------|
| Modify hotkey behavior | `VoiceFlow/Sources/Core/HotkeyManager.swift` |
| Change audio processing | `VoiceFlow/Sources/Core/AudioRecorder.swift` |
| Adjust WebSocket protocol | `VoiceFlow/Sources/Core/ASRClient.swift` + `server/main.py` |
| Add UI elements | `VoiceFlow/Sources/UI/StatusBarController.swift` |
| Modify ASR model | `server/mlx_asr.py` |
| Add text post-processing | `server/text_polisher.py` or create new plugin |

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
