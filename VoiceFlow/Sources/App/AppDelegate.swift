import AppKit
import AudioToolbox
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Cache paths on first access to avoid recalculation issues during runtime
    private static var _cachedPythonPath: String?
    private static var _cachedServerScriptPath: String?

    /// Resolve paths relative to the app bundle's parent directory (project root).
    /// e.g. /path/to/voiceflow/VoiceFlow.app → /path/to/voiceflow
    private static var projectRoot: String {
        let bundlePath = Bundle.main.bundlePath
        return (bundlePath as NSString).deletingLastPathComponent
    }

    private static var pythonPath: String {
        // Return cached path if available
        if let cached = _cachedPythonPath {
            return cached
        }

        // Priority 1: Environment variable (set by run.sh or Xcode scheme)
        if let envPath = ProcessInfo.processInfo.environment["VOICEFLOW_PYTHON"] {
            _cachedPythonPath = envPath
            return envPath
        }

        // Priority 2: Search upwards from bundle path for .venv directory
        var searchPath = projectRoot
        for _ in 0..<6 {  // Search up to 6 levels (increased from 3)
            let venvPath = (searchPath as NSString).appendingPathComponent(".venv/bin/python3")
            if FileManager.default.fileExists(atPath: venvPath) {
                _cachedPythonPath = venvPath
                return venvPath
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }

        // Priority 3: Fallback to projectRoot calculation
        let fallbackPath = (projectRoot as NSString).appendingPathComponent(".venv/bin/python3")
        _cachedPythonPath = fallbackPath
        return fallbackPath
    }

    private static var serverScriptPath: String {
        // Return cached path if available
        if let cached = _cachedServerScriptPath {
            return cached
        }

        // Priority 1: Environment variable VOICEFLOW_PROJECT_ROOT
        if let envRoot = ProcessInfo.processInfo.environment["VOICEFLOW_PROJECT_ROOT"] {
            let scriptPath = (envRoot as NSString).appendingPathComponent("server/main.py")
            if FileManager.default.fileExists(atPath: scriptPath) {
                _cachedServerScriptPath = scriptPath
                return scriptPath
            }
        }

        // Priority 2: Check common locations relative to home directory
        let homeDir = NSHomeDirectory()
        let commonPaths = [
            "\(homeDir)/voiceflow/server/main.py",
            "\(homeDir)/VoiceFlow/server/main.py",
            "\(homeDir)/Projects/voiceflow/server/main.py"
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                _cachedServerScriptPath = path
                return path
            }
        }

        // Priority 3: Search upwards from bundle path for server/main.py
        var searchPath = projectRoot
        for _ in 0..<6 {
            let scriptPath = (searchPath as NSString).appendingPathComponent("server/main.py")
            if FileManager.default.fileExists(atPath: scriptPath) {
                _cachedServerScriptPath = scriptPath
                return scriptPath
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }

        // Fallback to projectRoot calculation
        let fallbackPath = (projectRoot as NSString).appendingPathComponent("server/main.py")
        _cachedServerScriptPath = fallbackPath
        return fallbackPath
    }

    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController!
    private var hotkeyManager: HotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var asrClient: ASRClient!
    private var textInjector: TextInjector!
    private var overlayPanel: OverlayPanel!
    private var settingsManager: SettingsManager!
    private var recordingHistory: RecordingHistory!
    private var historyWindowController: HistoryWindowController!
    private var replacementStorage: ReplacementStorage!
    private var replacementEngine: TextReplacementEngine!
    private var isRecording = false
    private var asrServerProcess: Process?
    private var recordingStartTime: Date?

    private var startSoundID: SystemSoundID = 0
    private var stopSoundID: SystemSoundID = 0
    private var cancellables = Set<AnyCancellable>()

    /// Store the last original (unpolished) transcription for potential future comparison UI
    private var lastOriginalText: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching called!")
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup signal handlers to terminate Python subprocess on Ctrl+C
        setupSignalHandlers()

        // Launch ASR server
        startASRServer()

        // Load sounds via AudioServices (bypasses AVCaptureSession output blocking)
        loadSounds()

        // Initialize settings manager and text replacement engine
        settingsManager = SettingsManager.shared
        replacementStorage = ReplacementStorage()
        replacementEngine = TextReplacementEngine(storage: replacementStorage)
        settingsWindowController = SettingsWindowController(
            settingsManager: settingsManager,
            replacementStorage: replacementStorage
        )

        overlayPanel = OverlayPanel()
        textInjector = TextInjector()

        asrClient = ASRClient()
        recordingHistory = RecordingHistory()
        historyWindowController = HistoryWindowController(recordingHistory: recordingHistory)
        audioRecorder = AudioRecorder()
        audioRecorder.onAudioChunk = { [weak self] data in
            self?.asrClient.sendAudioChunk(data)
        }
        audioRecorder.onVolumeLevel = { [weak self] volume in
            DispatchQueue.main.async {
                self?.overlayPanel.updateVolume(Double(volume))
            }
        }

        asrClient.onTranscriptionResult = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                // Apply text replacement rules
                let processedText = self.replacementEngine.applyReplacements(to: text)

                self.overlayPanel.showDone()
                if !processedText.isEmpty {
                    self.textInjector.inject(text: processedText)
                }

                // Add to recording history with processed text
                if let startTime = self.recordingStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    self.recordingHistory.addEntry(text: processedText, duration: duration)
                    self.recordingStartTime = nil
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.overlayPanel.hide()
                }
            }
        }

        asrClient.onPartialResult = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                // 实时更新悬浮窗显示的文字
                self.overlayPanel.updateRecordingText(text)
            }
        }

        asrClient.onOriginalTextReceived = { [weak self] originalText in
            guard let self else { return }
            self.lastOriginalText = originalText
            NSLog("[AppDelegate] Original text stored: %@", originalText)
        }

        asrClient.onConnectionStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.statusBarController.updateConnectionStatus(connected: connected)
            }
        }

        statusBarController = StatusBarController()
        statusBarController.onQuit = {
            NSApp.terminate(nil)
        }
        statusBarController.onSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.onShowHistory = { [weak self] in
            self?.historyWindowController.showWindow()
        }
        statusBarController.onTextReplacement = { [weak self] in
            self?.settingsWindowController.show()
        }

        hotkeyManager = HotkeyManager()
        hotkeyManager.onLongPress = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager.onLongPressEnd = { [weak self] in
            self?.stopRecording()
        }
        hotkeyManager.start()

        // Observe hotkey enabled setting
        settingsManager.$hotkeyEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.hotkeyManager.enable()
                } else {
                    self?.hotkeyManager.disable()
                }
            }
            .store(in: &cancellables)

        audioRecorder.prepare()

        // Wait briefly for ASR server to start, then connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.asrClient.connect()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopASRServer()
    }

    // MARK: - ASR Server Management

    private func startASRServer() {
        // TODO: Pass selected model size (settingsManager.modelSize) to ASR server
        // This will be implemented in a future task when server supports model selection

        // Log paths for debugging
        NSLog("[ASRServer] Project root: %@", Self.projectRoot)
        NSLog("[ASRServer] Python path: %@", Self.pythonPath)
        NSLog("[ASRServer] Server script: %@", Self.serverScriptPath)

        // Verify python executable exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: Self.pythonPath) else {
            NSLog("[ASRServer] ERROR: Python executable not found at: %@", Self.pythonPath)
            NSLog("[ASRServer] Please ensure virtual environment is activated or VOICEFLOW_PYTHON is set")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.pythonPath)
        process.arguments = [Self.serverScriptPath]

        // Capture stderr to see error messages
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        // Read errors asynchronously
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                NSLog("[ASRServer] stderr: %@", output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        do {
            try process.run()
            asrServerProcess = process
            NSLog("[ASRServer] Started (PID: %d)", process.processIdentifier)

            // Monitor process termination
            process.terminationHandler = { proc in
                NSLog("[ASRServer] Process terminated with code: %d", proc.terminationStatus)
            }
        } catch {
            NSLog("[ASRServer] Failed to start: %@", error.localizedDescription)
        }
    }

    private func stopASRServer() {
        guard let process = asrServerProcess, process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
        NSLog("[ASRServer] Stopped")
        asrServerProcess = nil
    }

    private func setupSignalHandlers() {
        // Handle SIGINT (Ctrl+C) and SIGTERM to properly terminate Python subprocess
        let signalCallback: @convention(c) (Int32) -> Void = { signal in
            // Terminate Python process
            if let process = (NSApp.delegate as? AppDelegate)?.asrServerProcess, process.isRunning {
                process.terminate()
            }
            // Exit the app
            exit(0)
        }

        signal(SIGINT, signalCallback)
        signal(SIGTERM, signalCallback)
    }

    // MARK: - Sounds

    private func loadSounds() {
        let startURL = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        let stopURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")

        var status = AudioServicesCreateSystemSoundID(startURL as CFURL, &startSoundID)
        if status == noErr {
            NSLog("[Audio] startSound loaded via AudioServices (ID: %d)", startSoundID)
        } else {
            NSLog("[Audio] ERROR: Failed to load startSound (status: %d)", status)
        }

        status = AudioServicesCreateSystemSoundID(stopURL as CFURL, &stopSoundID)
        if status == noErr {
            NSLog("[Audio] stopSound loaded via AudioServices (ID: %d)", stopSoundID)
        } else {
            NSLog("[Audio] ERROR: Failed to load stopSound (status: %d)", status)
        }
    }

    private func playSound(_ soundID: SystemSoundID, name: String) {
        guard soundID != 0 else {
            NSLog("[Audio] WARNING: %@ not loaded, cannot play", name)
            return
        }
        AudioServicesPlaySystemSound(soundID)
        NSLog("[Audio] %@ played via AudioServices", name)
    }

    // MARK: - Recording

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordingStartTime = Date()
        NSLog("[Recording] Starting recording, playing start sound")
        playSound(startSoundID, name: "startSound")
        overlayPanel.showRecording()
        statusBarController.updateRecordingStatus(recording: true)
        asrClient.sendStart()
        audioRecorder.startRecording()
    }

    private func stopRecording() {
        isRecording = false
        NSLog("[Recording] Stopping recording, playing stop sound")
        playSound(stopSoundID, name: "stopSound")
        audioRecorder.stopRecording()
        overlayPanel.showProcessing()
        statusBarController.updateRecordingStatus(recording: false)
        asrClient.sendStop()
    }
}
