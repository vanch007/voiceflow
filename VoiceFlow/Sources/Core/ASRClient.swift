import Foundation

private enum ASRMessageType: String, Decodable {
    case final
    case partial
}

private struct ASRMessage: Decodable {
    let type: ASRMessageType
    let text: String
    let original_text: String?
}

final class ASRClient {
    var onTranscriptionResult: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?  // 实时部分结果回调
    var onOriginalTextReceived: ((String) -> Void)?  // 原始文本回调
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onErrorStateChanged: ((Bool, String?) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession = URLSession(configuration: .default)
    private var reconnectTask: Task<Void, Never>?
    private let serverURL = URL(string: "ws://localhost:9876")!
    private var isConnected = false
    private let reconnectInterval: TimeInterval = 3.0
    private let maxReconnectInterval: TimeInterval = 30.0
    private var currentReconnectInterval: TimeInterval = 3.0
    private var shouldReconnect = true
    private var currentLanguage: String = SettingsManager.shared.voiceLanguage
    private var lastErrorMessage: String?

    // 引用 SettingsManager 获取配置
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager

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
        shouldReconnect = true
        currentReconnectInterval = reconnectInterval
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()
        listenForMessages()

        webSocketTask?.sendPing { [weak self] error in
            guard let self = self else { return }
            if let error {
                print("[ASRClient] Ping failed after connect: \(error)")
                self.handleDisconnect(error: error)
                return
            }
            self.isConnected = true
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(true)
                self?.lastErrorMessage = nil
                self?.onErrorStateChanged?(false, nil)
            }
            print("[ASRClient] Connected to \(self.serverURL)")
            self.reconnectTask?.cancel()
            self.reconnectTask = nil
        }
    }

    func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if isConnected {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(false)
            }
        }
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func sendStart() {
        let enablePolish = settingsManager.textPolishEnabled
        let modelId = settingsManager.modelSize.modelId
        let language = settingsManager.asrLanguage.rawValue
        sendJSON([
            "type": "start",
            "enable_polish": enablePolish ? "true" : "false",
            "model_id": modelId,
            "language": language
        ])
    }

    func sendStop() {
        sendJSON(["type": "stop"])
    }

    func sendDictionaryUpdate(_ words: [String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["type": "update_dictionary", "words": words]),
              let str = String(data: data, encoding: .utf8) else {
            print("[ASRClient] Failed to serialize dictionary update")
            return
        }
        let message = URLSessionWebSocketTask.Message.string(str)
        webSocketTask?.send(message) { error in
            if let error {
                print("[ASRClient] Send dictionary update error: \(error)")
            } else {
                print("[ASRClient] Dictionary updated with \(words.count) words")
            }
        }
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
                self.handleDisconnect(error: error)
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

        guard let decoded = try? JSONDecoder().decode(ASRMessage.self, from: data) else { return }
        NSLog("[ASRClient] Received: type=\(decoded.type), text=\(decoded.text), original_text=\(decoded.original_text ?? "nil")")

        switch decoded.type {
        case .final:
            DispatchQueue.main.async { [weak self] in
                self?.onTranscriptionResult?(decoded.text)
                if let original = decoded.original_text { self?.onOriginalTextReceived?(original) }
            }
        case .partial:
            DispatchQueue.main.async { [weak self] in
                self?.onPartialResult?(decoded.text)
            }
        }
    }

    private func isRecoverable(_ error: Error?) -> Bool {
        guard let error = error else { return true }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet, .resourceUnavailable:
                return true
            case .badURL, .unsupportedURL:
                return false
            default:
                return true
            }
        }
        return true
    }

    private func handleDisconnect(error: Error?) {
        let message = (error as NSError?)?.localizedDescription ?? "Connection lost"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isConnected = false
            self.onConnectionStatusChanged?(false)
            self.lastErrorMessage = message
            self.onErrorStateChanged?(true, self.lastErrorMessage)
        }

        // Respect manual disconnect
        guard shouldReconnect else { return }

        // Stop reconnecting for unrecoverable errors
        if !isRecoverable(error) {
            shouldReconnect = false
            return
        }

        // Start or restart reconnect task with exponential backoff
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            var delay = self.currentReconnectInterval
            while !Task.isCancelled && self.shouldReconnect {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                print("[ASRClient] Attempting reconnect after \(delay)s...")
                self.connect()
                if self.isConnected { break }
                // Exponential backoff up to a maximum
                delay = min(self.maxReconnectInterval, delay * 2)
                self.currentReconnectInterval = delay
            }
        }
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
        reconnectTask?.cancel()
        disconnect()
    }
}

