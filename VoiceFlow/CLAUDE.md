# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceFlow is a macOS menu bar app for voice-to-text transcription. It captures audio via AVCaptureSession, sends it to a local WebSocket ASR server (ws://localhost:9876), and injects transcription results into the active application.

**Key Features:**
- Double-tap Control key to start/stop recording
- Real-time audio capture with 16kHz resampling
- WebSocket connection to local ASR server with auto-reconnect
- Automatic output volume restoration after recording
- Status bar UI with connection/recording indicators

## Build & Run

```bash
# Build using Swift Package Manager
swift build

# Run in Xcode (recommended for development)
open VoiceFlow.xcodeproj

# Build for release
swift build -c release
```

**Requirements:**
- macOS 14.0+
- Swift 5.9+
- Accessibility permissions (for global hotkey monitoring)
- Microphone permissions (for audio recording)

## Architecture

### Core Components

**App Layer** (`Sources/App/`)
- `VoiceFlowApp.swift`: SwiftUI app entry point
- `AppDelegate.swift`: Coordinates all managers, handles app lifecycle

**Core Services** (`Sources/Core/`)
- `HotkeyManager.swift`: Global Control key double-tap detection via CGEvent tap
- `AudioRecorder.swift`: AVCaptureSession-based audio capture with format conversion
- `ASRClient.swift`: WebSocket client for ASR server communication
- `TextInjector.swift`: CGEvent-based text injection into active apps

**UI Layer** (`Sources/UI/`)
- `StatusBarController.swift`: Menu bar item and status management
- `OverlayPanel.swift`: Visual recording indicator window

### Data Flow

```
User double-taps Control
  ↓
HotkeyManager triggers recording
  ↓
AudioRecorder captures mic input → resamples to 16kHz Float32
  ↓
ASRClient sends audio chunks via WebSocket
  ↓
Server responds with transcription
  ↓
TextInjector pastes text into active app
```

### WebSocket Protocol

**Client → Server:**
- `{"type": "start"}` - Start transcription session
- `{"type": "stop"}` - End transcription session
- Binary audio data (Float32, 16kHz, mono)

**Server → Client:**
- `{"type": "final", "text": "..."}` - Final transcription result
- `{"type": "partial", "text": "..."}` - Partial result (not yet implemented)

## Common Development Tasks

### Testing Audio Capture
Check console logs for device detection and format info:
```
[AudioRecorder] Audio device: MacBook Pro Microphone
[AudioRecorder] Capture session started (standby).
```

### Debugging WebSocket Connection
The ASRClient auto-reconnects every 3 seconds on disconnect. Check logs:
```
[ASRClient] Connected to ws://localhost:9876
[ASRClient] Attempting reconnect...
```

### Hotkey Not Working
Verify Accessibility permissions in System Settings → Privacy & Security → Accessibility. Check logs:
```
[HotkeyManager] FAILED to create event tap! Check permissions.
```

### Audio Format Issues
AudioRecorder handles Float32, Int16, and Int32 formats with mono/stereo conversion. Ensure input device uses standard formats.

## Code Guidelines

- Use `NSLog()` for important events (connection status, errors)
- Use `Logger` (os.log) for detailed debug info in HotkeyManager
- All audio processing happens on `sessionQueue` background thread
- UI updates must dispatch to `DispatchQueue.main`
- WebSocket reconnection is automatic - don't manually retry in UI code

## Permissions Required

1. **Microphone Access**: Required for `AudioRecorder` to capture audio
2. **Accessibility Access**: Required for `HotkeyManager` global event monitoring and `TextInjector` text injection

Both are requested automatically on first launch.

## Known Limitations

- Hotkey is hardcoded to Control key double-tap (keyCode 59/62)
- ASR server URL is hardcoded to `ws://localhost:9876`
- Audio resampling uses simple linear interpolation (not production-quality)
- Partial transcription results are received but not yet utilized
