import Foundation

final class ASRClient {
    var onTranscriptionResult: ((String) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = URL(string: "ws://localhost:9876")!
    private var isConnected = false
    private var reconnectTimer: Timer?
    private let reconnectInterval: TimeInterval = 3.0
    private var currentLanguage: String = SettingsManager.shared.voiceLanguage

    init() {
        // Observe voice settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    func connect() {
        disconnect()
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        listenForMessages()
        isConnected = true
        onConnectionStatusChanged?(true)
        print("[ASRClient] Connected to \(serverURL)")
        stopReconnectTimer()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if isConnected {
            isConnected = false
            onConnectionStatusChanged?(false)
        }
    }

    func sendStart() {
        // Send start message with current language setting
        sendJSON(["type": "start", "language": currentLanguage])
    }

    func sendStop() {
        sendJSON(["type": "stop"])
    }

    func sendAudioChunk(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error {
                print("[ASRClient] Send audio error: \(error)")
            }
        }
    }

    // MARK: - Private

    private func sendJSON(_ dict: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        let message = URLSessionWebSocketTask.Message.string(str)
        webSocketTask?.send(message) { error in
            if let error {
                print("[ASRClient] Send JSON error: \(error)")
            }
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.listenForMessages()
            case .failure(let error):
                print("[ASRClient] Receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              let text = json["text"] as? String else { return }

        NSLog("[ASRClient] Received: type=\(type), text=\(text)")
        if type == "final" {
            onTranscriptionResult?(text)
        }
        // partial results can be handled here in the future
    }

    private func handleDisconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isConnected = false
            self.onConnectionStatusChanged?(false)
            self.startReconnectTimer()
        }
    }

    private func startReconnectTimer() {
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            print("[ASRClient] Attempting reconnect...")
            self?.connect()
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Settings Observer

    @objc private func handleSettingsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String,
              let key = userInfo["key"] as? String else {
            return
        }

        // Update language when voice language setting changes
        if category == "voice" && key == "language" {
            if let language = userInfo["value"] as? String {
                currentLanguage = language
                NSLog("[ASRClient] Voice language changed to: \(language)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopReconnectTimer()
        disconnect()
    }
}
