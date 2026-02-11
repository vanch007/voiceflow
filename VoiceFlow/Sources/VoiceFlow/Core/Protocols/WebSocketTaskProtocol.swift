import Foundation

/// Protocol abstraction for URLSessionWebSocketTask to enable testing
protocol WebSocketTaskProtocol {
    /// Resume the WebSocket task
    func resume()

    /// Cancel the WebSocket task
    /// - Parameters:
    ///   - closeCode: The close code to send
    ///   - reason: Optional reason data
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)

    /// Send a ping frame
    /// - Parameter pongReceiveHandler: Completion handler called when pong is received
    func sendPing(pongReceiveHandler: @escaping (Error?) -> Void)

    /// Send a WebSocket message
    /// - Parameters:
    ///   - message: The message to send
    ///   - completionHandler: Completion handler called when send completes
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void)

    /// Receive a WebSocket message
    /// - Parameter completionHandler: Completion handler called when a message is received
    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

/// Extension to make URLSessionWebSocketTask conform to the protocol
extension URLSessionWebSocketTask: WebSocketTaskProtocol {}
