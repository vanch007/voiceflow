import AppKit
import AudioToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Resolve paths relative to the app bundle's parent directory (project root).
    /// e.g. /path/to/voiceflow/VoiceFlow.app → /path/to/voiceflow
    private static var projectRoot: String {
        let bundlePath = Bundle.main.bundlePath
        return (bundlePath as NSString).deletingLastPathComponent
    }

    private static var pythonPath: String {
        if let envPath = ProcessInfo.processInfo.environment["VOICEFLOW_PYTHON"] {
            return envPath
        }
        return (projectRoot as NSString).appendingPathComponent(".venv/bin/python3")
    }

    private static var serverScriptPath: String {
        return (projectRoot as NSString).appendingPathComponent("server/main.py")
    }

    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var asrClient: ASRClient!
    private var dictionaryManager: DictionaryManager!
    private var textInjector: TextInjector!
    private var overlayPanel: OverlayPanel!
    private var isRecording = false
    private var asrServerProcess: Process?

    private var startSoundID: SystemSoundID = 0
    private var stopSoundID: SystemSoundID = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching called!")
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Launch ASR server
        startASRServer()

        // Load sounds via AudioServices (bypasses AVCaptureSession output blocking)
        loadSounds()

        overlayPanel = OverlayPanel()
        textInjector = TextInjector()
        asrClient = ASRClient()
        dictionaryManager = DictionaryManager()
        audioRecorder = AudioRecorder()
        audioRecorder.onAudioChunk = { [weak self] data in
            self?.asrClient.sendAudioChunk(data)
        }

        // Wire DictionaryManager to ASRClient for real-time updates
        dictionaryManager.onDictionaryChanged = { [weak self] words in
            self?.asrClient.sendDictionaryUpdate(words)
        }

        asrClient.onTranscriptionResult = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                self.overlayPanel.showDone()
                if !text.isEmpty {
                    self.textInjector.inject(text: text)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.overlayPanel.hide()
                }
            }
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
        statusBarController.onDeviceSelected = { [weak self] deviceID in
            self?.audioRecorder.selectDevice(id: deviceID)
        }
        audioRecorder.onDeviceChanged = { [weak self] name in
            self?.statusBarController.updateActiveDevice(name: name)
        }

        hotkeyManager = HotkeyManager()
        hotkeyManager.onDoubleTap = { [weak self] in
            self?.toggleRecording()
        }
        hotkeyManager.start()

        // Restore saved device selection
        if let savedDeviceID = UserDefaults.standard.string(forKey: "selectedAudioDevice") {
            audioRecorder.selectDevice(id: savedDeviceID)
        } else {
            audioRecorder.prepare()
        }

        // Wait briefly for ASR server to start, then connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.asrClient.connect()
            // Send initial dictionary to server after connection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let words = self.dictionaryManager.getWords()
                if !words.isEmpty {
                    self.asrClient.sendDictionaryUpdate(words)
                    NSLog("[AppDelegate] Sent initial dictionary with \(words.count) words to ASR server")
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopASRServer()
    }

    // MARK: - ASR Server Management

    private func startASRServer() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.pythonPath)
        process.arguments = [Self.serverScriptPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            asrServerProcess = process
            NSLog("[ASRServer] Started (PID: %d)", process.processIdentifier)
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
