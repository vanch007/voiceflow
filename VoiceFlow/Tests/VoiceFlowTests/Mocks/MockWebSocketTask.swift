import Foundation
@testable import VoiceFlow

/// Mock implementation of WebSocketTaskProtocol for testing ASRClient WebSocket logic
///
/// This mock allows tests to:
/// - Track method calls (resume, cancel, send, receive, sendPing)
/// - Inject custom responses for receive operations
/// - Simulate errors for send/receive operations
/// - Verify WebSocket lifecycle without real network connections
final class MockWebSocketTask: WebSocketTaskProtocol {

    // MARK: - Call Tracking Properties

    /// Tracks whether resume() was called
    var resumeCalled = false

    /// Tracks whether cancel() was called
    var cancelCalled = false

    /// Tracks the close code used in cancel()
    var cancelCloseCode: URLSessionWebSocketTask.CloseCode?

    /// Tracks the reason data used in cancel()
    var cancelReason: Data?

    /// Tracks whether sendPing() was called
    var sendPingCalled = false

    /// Number of times send() was called
    var sendCallCount = 0

    /// Number of times receive() was called
    var receiveCallCount = 0

    /// All messages sent via send()
    var sentMessages: [URLSessionWebSocketTask.Message] = []

    // MARK: - Behavior Configuration Properties

    /// Error to return from send() (nil = success)
    var sendError: Error?

    /// Error to return from sendPing() (nil = success)
    var pingError: Error?

    /// Messages to return from receive() calls (FIFO queue)
    var messagesToReceive: [URLSessionWebSocketTask.Message] = []

    /// Error to return from receive() (overrides messagesToReceive if set)
    var receiveError: Error?

    /// Delay in seconds before calling receive completion handler (for testing async behavior)
    var receiveDelay: TimeInterval = 0.0

    /// Delay in seconds before calling send completion handler
    var sendDelay: TimeInterval = 0.0

    /// Delay in seconds before calling ping completion handler
    var pingDelay: TimeInterval = 0.0

    // MARK: - WebSocketTaskProtocol Implementation

    func resume() {
        resumeCalled = true
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        cancelCalled = true
        cancelCloseCode = closeCode
        cancelReason = reason
    }

    func sendPing(pongReceiveHandler: @escaping (Error?) -> Void) {
        sendPingCalled = true

        if pingDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + pingDelay) {
                pongReceiveHandler(self.pingError)
            }
        } else {
            pongReceiveHandler(pingError)
        }
    }

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        sendCallCount += 1
        sentMessages.append(message)

        if sendDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + sendDelay) {
                completionHandler(self.sendError)
            }
        } else {
            completionHandler(sendError)
        }
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        receiveCallCount += 1

        let executeCompletion = {
            // If receiveError is set, return error
            if let error = self.receiveError {
                completionHandler(.failure(error))
                return
            }

            // If messagesToReceive is not empty, return next message
            if !self.messagesToReceive.isEmpty {
                let message = self.messagesToReceive.removeFirst()
                completionHandler(.success(message))
                return
            }

            // Otherwise, return a generic error (no message available)
            let error = NSError(
                domain: "MockWebSocketTask",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No messages available in mock queue"]
            )
            completionHandler(.failure(error))
        }

        if receiveDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + receiveDelay) {
                executeCompletion()
            }
        } else {
            executeCompletion()
        }
    }

    // MARK: - Helper Methods for Testing

    /// Reset all tracking properties (useful in setUp/tearDown)
    func reset() {
        resumeCalled = false
        cancelCalled = false
        cancelCloseCode = nil
        cancelReason = nil
        sendPingCalled = false
        sendCallCount = 0
        receiveCallCount = 0
        sentMessages.removeAll()

        sendError = nil
        pingError = nil
        messagesToReceive.removeAll()
        receiveError = nil
        receiveDelay = 0.0
        sendDelay = 0.0
        pingDelay = 0.0
    }

    /// Enqueue a text message to be returned by the next receive() call
    /// - Parameter text: The text content of the message
    func enqueueMessage(text: String) {
        messagesToReceive.append(.string(text))
    }

    /// Enqueue a data message to be returned by the next receive() call
    /// - Parameter data: The binary data content of the message
    func enqueueMessage(data: Data) {
        messagesToReceive.append(.data(data))
    }

    /// Get all sent text messages (filters out data messages)
    /// - Returns: Array of sent text strings
    func getSentTextMessages() -> [String] {
        return sentMessages.compactMap { message in
            if case .string(let text) = message {
                return text
            }
            return nil
        }
    }

    /// Get all sent data messages (filters out text messages)
    /// - Returns: Array of sent Data objects
    func getSentDataMessages() -> [Data] {
        return sentMessages.compactMap { message in
            if case .data(let data) = message {
                return data
            }
            return nil
        }
    }
}
