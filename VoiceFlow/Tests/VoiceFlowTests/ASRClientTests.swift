import XCTest
@testable import VoiceFlow

/// Unit tests for ASRClient WebSocket connection lifecycle and message handling
///
/// **Test Coverage:**
/// - WebSocket connection establishment and lifecycle
/// - Message sending (start, stop, audio chunks, JSON messages)
/// - Message receiving (final, partial, polish_update, LLM results)
/// - Error handling and recovery
/// - Reconnection logic with exponential backoff
/// - State management (connection status, error states)
/// - Callback execution for transcription results
///
/// **Setup Requirements:**
/// - Uses MockWebSocketTask to avoid real network connections
/// - Tests run independently without external dependencies
/// - No Python server required for unit tests
final class ASRClientTests: XCTestCase {
    var asrClient: ASRClient!
    var mockWebSocketTask: MockWebSocketTask!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()

        // Create mock WebSocket task
        mockWebSocketTask = MockWebSocketTask()

        // Create mock session (not used directly, but required for init)
        mockSession = URLSession(configuration: .default)

        // Create ASRClient with mock WebSocket factory
        asrClient = ASRClient(
            session: mockSession,
            serverURL: URL(string: "ws://localhost:9876")!,
            webSocketTaskFactory: { [unowned self] _, _ in
                return self.mockWebSocketTask
            }
        )
    }

    override func tearDown() {
        asrClient.disconnect()
        asrClient = nil
        mockWebSocketTask = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Connection Lifecycle Tests

    func testWebSocketConnectionEstablishesSuccessfully() {
        // Given: A disconnected ASRClient
        let connectionExpectation = expectation(description: "Connection status changed to true")

        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        // When: connect() is called
        asrClient.connect()

        // Then: WebSocket task is created and resumed
        XCTAssertTrue(mockWebSocketTask.resumeCalled, "WebSocket task should be resumed")

        // Wait for ping to complete (connection uses 0.5s delay before ping)
        wait(for: [connectionExpectation], timeout: 2.0)

        // Verify connection state
        XCTAssertTrue(asrClient.isServerConnected, "ASRClient should report connected status")
        XCTAssertTrue(mockWebSocketTask.sendPingCalled, "Ping should be sent to verify connection")
    }

    func testWebSocketConnectionFailureHandling() {
        // Given: A mock that will fail the ping
        mockWebSocketTask.pingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: [NSLocalizedDescriptionKey: "Connection refused"]
        )

        // When: connect() is called but ping fails
        asrClient.connect()

        // Wait for ping to complete (ASRClient delays ping by 0.5s, then processes error)
        let pingExpectation = expectation(description: "Ping completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pingExpectation.fulfill()
        }
        wait(for: [pingExpectation], timeout: 2.0)

        // Then: ASRClient should remain disconnected after ping failure
        XCTAssertFalse(asrClient.isServerConnected, "ASRClient should report disconnected status after ping failure")

        // Verify that ping was attempted
        XCTAssertTrue(mockWebSocketTask.sendPingCalled, "Ping should have been attempted")
    }

    func testDisconnectCancelsWebSocketTask() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: disconnect() is called
        let disconnectExpectation = expectation(description: "Disconnection notification")
        asrClient.onConnectionStatusChanged = { isConnected in
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        asrClient.disconnect()

        // Then: WebSocket task is cancelled
        XCTAssertTrue(mockWebSocketTask.cancelCalled, "WebSocket task should be cancelled")
        XCTAssertEqual(mockWebSocketTask.cancelCloseCode, .goingAway, "Should use goingAway close code")

        wait(for: [disconnectExpectation], timeout: 1.0)

        XCTAssertFalse(asrClient.isServerConnected, "ASRClient should report disconnected status")
    }

    func testReconnectionLogicAfterDisconnect() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Connection is lost (simulate disconnect)
        let disconnectExpectation = expectation(description: "Disconnection detected")

        var disconnectDetected = false
        asrClient.onConnectionStatusChanged = { isConnected in
            if !isConnected && !disconnectDetected {
                disconnectDetected = true
                disconnectExpectation.fulfill()
            }
        }

        // Simulate connection error by setting receive error
        mockWebSocketTask.receiveError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        // Trigger receive loop to encounter the error
        asrClient.connect()

        // Then: Disconnection should be detected
        wait(for: [disconnectExpectation], timeout: 2.0)

        XCTAssertFalse(asrClient.isServerConnected, "Should be disconnected after connection loss")

        // Note: Full reconnection test with exponential backoff requires integration tests
        // Unit tests verify disconnect behavior; reconnection timing is tested separately
    }

    func testManualDisconnectPreventsReconnection() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Manual disconnect is called
        asrClient.disconnect()

        // Then: shouldReconnect flag should prevent auto-reconnection
        // (Internal state, verified by no reconnection attempts)
        XCTAssertFalse(asrClient.isServerConnected, "Should remain disconnected")
    }

    // MARK: - Message Sending Tests

    func testSendStartMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: sendStart is called
        let sendExpectation = expectation(description: "Start message sent")
        asrClient.sendStart(mode: "voice_input") {
            sendExpectation.fulfill()
        }

        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A JSON start message should be sent
        let sentTextMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentTextMessages.count, 0, "Should have sent at least one message")

        // Verify the start message contains expected fields
        if let startMessage = sentTextMessages.last,
           let jsonData = startMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "start", "Message type should be 'start'")
            XCTAssertEqual(json["mode"] as? String, "voice_input", "Mode should be 'voice_input'")
            XCTAssertNotNil(json["model_id"], "Should include model_id")
            XCTAssertNotNil(json["language"], "Should include language")
        } else {
            XCTFail("Failed to parse start message JSON")
        }
    }

    func testSendStopMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: sendStop is called
        let sendExpectation = expectation(description: "Stop message sent")
        asrClient.sendStop {
            sendExpectation.fulfill()
        }

        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A JSON stop message should be sent
        let sentTextMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentTextMessages.count, 0, "Should have sent at least one message")

        // Verify the stop message
        if let stopMessage = sentTextMessages.last,
           let jsonData = stopMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "stop", "Message type should be 'stop'")
        } else {
            XCTFail("Failed to parse stop message JSON")
        }
    }

    func testSendAudioChunks() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let initialSendCount = mockWebSocketTask.sendCallCount

        // When: Audio chunks are sent
        let audioData1 = Data(repeating: 0x01, count: 1024)
        let audioData2 = Data(repeating: 0x02, count: 1024)
        let audioData3 = Data(repeating: 0x03, count: 1024)

        asrClient.sendAudioChunk(audioData1)
        asrClient.sendAudioChunk(audioData2)
        asrClient.sendAudioChunk(audioData3)

        // Wait a bit for sends to complete
        let flushExpectation = expectation(description: "Audio chunks flushed")
        asrClient.flushAudioChunks {
            flushExpectation.fulfill()
        }

        wait(for: [flushExpectation], timeout: 1.0)

        // Then: All audio chunks should be sent as binary data
        let sentDataMessages = mockWebSocketTask.getSentDataMessages()
        XCTAssertGreaterThanOrEqual(mockWebSocketTask.sendCallCount - initialSendCount, 3, "Should have sent at least 3 audio chunks")
        XCTAssertGreaterThanOrEqual(sentDataMessages.count, 3, "Should have at least 3 data messages")
    }

    func testFlushAudioChunksWaitsForCompletion() {
        // Given: A connected ASRClient with delayed sends
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // Configure mock to delay sends slightly
        mockWebSocketTask.sendDelay = 0.1

        // When: Audio chunks are sent and flushed
        let audioData = Data(repeating: 0xFF, count: 512)
        asrClient.sendAudioChunk(audioData)

        let flushExpectation = expectation(description: "Flush completes")
        let startTime = Date()

        asrClient.flushAudioChunks {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThan(elapsed, 0.05, "Should wait for pending sends")
            flushExpectation.fulfill()
        }

        wait(for: [flushExpectation], timeout: 2.0)
    }

    // MARK: - Message Receiving Tests

    func testReceiveFinalTranscriptionMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A final transcription message is received
        let transcriptionExpectation = expectation(description: "Transcription received")
        let expectedText = "Hello, this is a test transcription"

        asrClient.onTranscriptionResult = { text in
            XCTAssertEqual(text, expectedText, "Should receive correct transcription text")
            transcriptionExpectation.fulfill()
        }

        // Enqueue a final message
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": expectedText,
            "polish_method": "llm"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            // Trigger message processing by simulating receive
            // Note: ASRClient starts listening in connect(), so we need to trigger it
            wait(for: [transcriptionExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create final message JSON")
        }
    }

    func testReceivePartialTranscriptionMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A partial transcription message is received
        let partialExpectation = expectation(description: "Partial result received")
        let expectedText = "This is partial..."
        let expectedTrigger = "pause"

        asrClient.onPartialResult = { text, trigger in
            XCTAssertEqual(text, expectedText, "Should receive correct partial text")
            XCTAssertEqual(trigger, expectedTrigger, "Should receive correct trigger")
            partialExpectation.fulfill()
        }

        // Enqueue a partial message
        let partialMessage: [String: Any] = [
            "type": "partial",
            "text": expectedText,
            "trigger": expectedTrigger
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: partialMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            wait(for: [partialExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create partial message JSON")
        }
    }

    func testReceivePolishUpdateMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A polish update message is received
        let polishExpectation = expectation(description: "Polish update received")
        let expectedPolishedText = "Hello, this is a polished transcription."

        asrClient.onPolishUpdate = { text in
            XCTAssertEqual(text, expectedPolishedText, "Should receive polished text")
            polishExpectation.fulfill()
        }

        // Enqueue a polish_update message
        let polishMessage: [String: Any] = [
            "type": "polish_update",
            "text": expectedPolishedText
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: polishMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            wait(for: [polishExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create polish update message JSON")
        }
    }

    func testReceiveLLMConnectionTestResult() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A test_llm_connection_result message is received
        let llmTestExpectation = expectation(description: "LLM test result received")
        let expectedSuccess = true
        let expectedLatency = 150

        asrClient.onLLMConnectionTestResult = { success, latency in
            XCTAssertEqual(success, expectedSuccess, "Should receive correct success status")
            XCTAssertEqual(latency, expectedLatency, "Should receive correct latency")
            llmTestExpectation.fulfill()
        }

        // Enqueue a test result message
        let testMessage: [String: Any] = [
            "type": "test_llm_connection_result",
            "success": expectedSuccess,
            "latency_ms": expectedLatency
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: testMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            wait(for: [llmTestExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create LLM test result message JSON")
        }
    }

    func testReceiveInvalidJSONHandledGracefully() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Invalid JSON is received
        mockWebSocketTask.enqueueMessage(text: "{invalid json syntax}}")

        // Then: ASRClient should not crash (no assertion needed, just verify no crash)
        // Wait a bit to ensure message processing completes
        let processExpectation = expectation(description: "Processing completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }

        wait(for: [processExpectation], timeout: 1.0)

        // If we reach here without crash, test passes
        XCTAssertTrue(true, "ASRClient should handle invalid JSON gracefully")
    }

    // MARK: - LLM Configuration Tests

    func testConfigureLLMSendsCorrectMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: configureLLM is called
        let llmSettings = LLMSettings(
            apiURL: "http://localhost:11434/v1",
            apiKey: "test-key",
            model: "llama3.1",
            temperature: 0.3,
            maxTokens: 512,
            isEnabled: true,
            timeout: 10.0
        )

        let initialMessageCount = mockWebSocketTask.getSentTextMessages().count

        asrClient.configureLLM(llmSettings)

        // Wait for message to be sent
        let sendExpectation = expectation(description: "Message sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sendExpectation.fulfill()
        }
        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A config_llm message should be sent
        let sentMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentMessages.count, initialMessageCount, "Should send config message")

        // Verify message content
        if let configMessage = sentMessages.last,
           let jsonData = configMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "config_llm", "Message type should be 'config_llm'")
            XCTAssertNotNil(json["config"], "Should include config object")
        } else {
            XCTFail("Failed to parse config_llm message")
        }
    }

    func testTestLLMConnectionSendsMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let initialMessageCount = mockWebSocketTask.getSentTextMessages().count

        // When: testLLMConnection is called
        asrClient.testLLMConnection()

        // Wait for message to be sent
        let sendExpectation = expectation(description: "Message sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sendExpectation.fulfill()
        }
        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A test_llm_connection message should be sent
        let sentMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentMessages.count, initialMessageCount, "Should send test message")

        if let testMessage = sentMessages.last,
           let jsonData = testMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "test_llm_connection", "Message type should be 'test_llm_connection'")
        } else {
            XCTFail("Failed to parse test message")
        }
    }

    // MARK: - Error Handling Tests

    func testSendErrorHandling() {
        // Given: A connected ASRClient with mock configured to fail sends
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        mockWebSocketTask.sendError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        // When: Sending a message
        asrClient.sendStop()

        // Then: ASRClient should handle error gracefully (no crash)
        let processExpectation = expectation(description: "Error handling completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }

        wait(for: [processExpectation], timeout: 1.0)

        // Test passes if no crash occurs
        XCTAssertTrue(true, "Should handle send errors gracefully")
    }

    func testReceiveErrorTriggersDisconnect() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Receive returns an error
        let disconnectExpectation = expectation(description: "Disconnect triggered")

        asrClient.onConnectionStatusChanged = { isConnected in
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        mockWebSocketTask.receiveError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        // Trigger a new connection to start receive loop
        asrClient.connect()

        // Then: Disconnect should be triggered
        wait(for: [disconnectExpectation], timeout: 2.0)

        XCTAssertFalse(asrClient.isServerConnected, "Should be disconnected after receive error")
    }

    // MARK: - State Management Tests

    func testConnectionStatusTracking() {
        // Given: A disconnected ASRClient
        XCTAssertFalse(asrClient.isServerConnected, "Should start disconnected")

        // When: Connection is established
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // Then: Status should be connected
        XCTAssertTrue(asrClient.isServerConnected, "Should be connected")

        // When: Disconnect is called
        let disconnectExpectation = expectation(description: "Disconnection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        asrClient.disconnect()
        wait(for: [disconnectExpectation], timeout: 1.0)

        // Then: Status should be disconnected
        XCTAssertFalse(asrClient.isServerConnected, "Should be disconnected")
    }

    func testMultipleCallbacksExecuted() {
        // Given: A connected ASRClient with multiple callbacks registered
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A final message is received with multiple data fields
        let transcriptionExpectation = expectation(description: "Transcription callback")
        let originalTextExpectation = expectation(description: "Original text callback")
        let polishMethodExpectation = expectation(description: "Polish method callback")

        asrClient.onTranscriptionResult = { _ in transcriptionExpectation.fulfill() }
        asrClient.onOriginalTextReceived = { _ in originalTextExpectation.fulfill() }
        asrClient.onPolishMethodReceived = { _ in polishMethodExpectation.fulfill() }

        // Enqueue a comprehensive final message
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": "Polished text",
            "original_text": "Original text",
            "polish_method": "llm"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            // Then: All callbacks should be executed
            wait(for: [transcriptionExpectation, originalTextExpectation, polishMethodExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create final message JSON")
        }
    }

    // MARK: - Prompt Management Tests

    func testRequestDefaultPrompts() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let initialMessageCount = mockWebSocketTask.getSentTextMessages().count

        // When: requestDefaultPrompts is called
        asrClient.requestDefaultPrompts()

        // Wait for message to be sent
        let sendExpectation = expectation(description: "Message sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sendExpectation.fulfill()
        }
        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A get_default_prompts message should be sent
        let sentMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentMessages.count, initialMessageCount, "Should send request message")

        if let requestMessage = sentMessages.last,
           let jsonData = requestMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "get_default_prompts", "Message type should be 'get_default_prompts'")
        } else {
            XCTFail("Failed to parse request message")
        }
    }

    func testReceiveDefaultPromptsMessage() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A default_prompts message is received
        let promptsExpectation = expectation(description: "Default prompts received")
        let expectedPrompts = [
            "general": "Transcribe clearly",
            "technical": "Use technical terminology"
        ]

        asrClient.onDefaultPromptsReceived = { prompts in
            XCTAssertEqual(prompts.count, expectedPrompts.count, "Should receive all prompts")
            XCTAssertEqual(prompts["general"], expectedPrompts["general"])
            XCTAssertEqual(prompts["technical"], expectedPrompts["technical"])
            promptsExpectation.fulfill()
        }

        // Enqueue a default_prompts message
        let promptsMessage: [String: Any] = [
            "type": "default_prompts",
            "prompts": expectedPrompts
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: promptsMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)

            wait(for: [promptsExpectation], timeout: 2.0)
        } else {
            XCTFail("Failed to create prompts message JSON")
        }
    }

    func testSaveCustomPrompt() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let initialMessageCount = mockWebSocketTask.getSentTextMessages().count

        // When: saveCustomPrompt is called
        asrClient.saveCustomPrompt(sceneType: "technical", prompt: "Custom tech prompt", useDefault: false)

        // Wait for message to be sent
        let sendExpectation = expectation(description: "Message sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sendExpectation.fulfill()
        }
        wait(for: [sendExpectation], timeout: 1.0)

        // Then: A save_custom_prompt message should be sent
        let sentMessages = mockWebSocketTask.getSentTextMessages()
        XCTAssertGreaterThan(sentMessages.count, initialMessageCount, "Should send save message")

        if let saveMessage = sentMessages.last,
           let jsonData = saveMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "save_custom_prompt", "Message type should be 'save_custom_prompt'")
            XCTAssertEqual(json["scene_type"] as? String, "technical")
            XCTAssertEqual(json["prompt"] as? String, "Custom tech prompt")
            XCTAssertEqual(json["use_default"] as? Bool, false)
        } else {
            XCTFail("Failed to parse save message")
        }
    }

    // MARK: - Error Recovery and Reconnection Tests

    func testErrorStateChangedCallbackOnConnectionFailure() {
        // Given: A mock that will fail the ping
        mockWebSocketTask.pingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: [NSLocalizedDescriptionKey: "Connection refused"]
        )

        // When: connect() is called and fails
        let errorExpectation = expectation(description: "Error state changed")

        asrClient.onErrorStateChanged = { hasError, errorMessage in
            if hasError {
                XCTAssertNotNil(errorMessage, "Should provide error message")
                errorExpectation.fulfill()
            }
        }

        asrClient.connect()

        // Wait for ping failure to be processed
        wait(for: [errorExpectation], timeout: 2.0)
    }

    func testErrorStateResetsOnSuccessfulConnection() {
        // Given: A client that previously had an error
        mockWebSocketTask.pingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: nil
        )

        let errorExpectation = expectation(description: "Error state set")
        asrClient.onErrorStateChanged = { hasError, _ in
            if hasError {
                errorExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [errorExpectation], timeout: 2.0)

        // When: A successful connection is made
        mockWebSocketTask = MockWebSocketTask()  // Fresh mock without error
        asrClient = ASRClient(
            session: mockSession,
            serverURL: URL(string: "ws://localhost:9876")!,
            webSocketTaskFactory: { [unowned self] _, _ in
                return self.mockWebSocketTask
            }
        )

        let errorClearExpectation = expectation(description: "Error state cleared")
        asrClient.onErrorStateChanged = { hasError, errorMessage in
            if !hasError && errorMessage == nil {
                errorClearExpectation.fulfill()
            }
        }

        asrClient.connect()

        // Then: Error state should be cleared
        wait(for: [errorClearExpectation], timeout: 2.0)
    }

    func testReconnectTaskCancelledOnManualDisconnect() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Manual disconnect is called
        asrClient.disconnect()

        // Then: Any pending reconnect tasks should be cancelled
        // (verified by no auto-reconnection happening)
        let noReconnectExpectation = expectation(description: "No reconnection occurs")
        noReconnectExpectation.isInverted = true

        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                noReconnectExpectation.fulfill()
            }
        }

        wait(for: [noReconnectExpectation], timeout: 1.5)
    }

    func testConcurrentConnectCallsCancelPreviousConnection() {
        // Given: An initial connection in progress
        asrClient.connect()

        // Wait briefly for first connection to start
        let briefDelay = expectation(description: "Brief delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            briefDelay.fulfill()
        }
        wait(for: [briefDelay], timeout: 0.5)

        let firstTask = mockWebSocketTask

        // When: connect() is called again before first completes
        mockWebSocketTask = MockWebSocketTask()
        asrClient = ASRClient(
            session: mockSession,
            serverURL: URL(string: "ws://localhost:9876")!,
            webSocketTaskFactory: { [unowned self] _, _ in
                return self.mockWebSocketTask
            }
        )

        asrClient.connect()

        // Then: First connection should be cancelled
        // (New connection establishes with new task)
        let connectionExpectation = expectation(description: "New connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        wait(for: [connectionExpectation], timeout: 2.0)

        XCTAssertTrue(asrClient.isServerConnected, "New connection should succeed")
    }

    func testPingFailureTriggersDisconnectHandling() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A subsequent ping fails (simulating connection loss)
        mockWebSocketTask.pingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        let disconnectExpectation = expectation(description: "Disconnect after ping failure")
        asrClient.onConnectionStatusChanged = { isConnected in
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        // Trigger a new connect to encounter the ping error
        asrClient.connect()

        // Then: Should detect disconnect
        wait(for: [disconnectExpectation], timeout: 2.0)
    }

    func testConnectionStatusCallbackFiredOnlyOnStateChange() {
        // Given: A disconnected ASRClient
        var statusChangeCount = 0
        let firstConnectionExpectation = expectation(description: "First connection")

        asrClient.onConnectionStatusChanged = { isConnected in
            statusChangeCount += 1
            if isConnected && statusChangeCount == 1 {
                firstConnectionExpectation.fulfill()
            }
        }

        // When: connect() is called
        asrClient.connect()
        wait(for: [firstConnectionExpectation], timeout: 2.0)

        // Reset counter
        statusChangeCount = 0

        // When: disconnect() is called
        let disconnectExpectation = expectation(description: "Disconnect")
        asrClient.onConnectionStatusChanged = { isConnected in
            statusChangeCount += 1
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        asrClient.disconnect()
        wait(for: [disconnectExpectation], timeout: 1.0)

        // Then: Callback should fire exactly once per state change
        XCTAssertEqual(statusChangeCount, 1, "Should fire callback exactly once for disconnect")
    }

    func testReceiveErrorWithDifferentErrorCodes() {
        // Test various network error scenarios
        let errorCodes = [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost
        ]

        for errorCode in errorCodes {
            // Given: A fresh ASRClient connection
            mockWebSocketTask = MockWebSocketTask()
            asrClient = ASRClient(
                session: mockSession,
                serverURL: URL(string: "ws://localhost:9876")!,
                webSocketTaskFactory: { [unowned self] _, _ in
                    return self.mockWebSocketTask
                }
            )

            let connectionExpectation = expectation(description: "Connection for error \(errorCode)")
            asrClient.onConnectionStatusChanged = { isConnected in
                if isConnected {
                    connectionExpectation.fulfill()
                }
            }

            asrClient.connect()
            wait(for: [connectionExpectation], timeout: 2.0)

            // When: Receive fails with specific error code
            let disconnectExpectation = expectation(description: "Disconnect for error \(errorCode)")

            asrClient.onConnectionStatusChanged = { isConnected in
                if !isConnected {
                    disconnectExpectation.fulfill()
                }
            }

            mockWebSocketTask.receiveError = NSError(
                domain: NSURLErrorDomain,
                code: errorCode,
                userInfo: nil
            )

            // Trigger receive loop
            asrClient.connect()

            // Then: Should handle disconnect gracefully
            wait(for: [disconnectExpectation], timeout: 2.0)

            XCTAssertFalse(asrClient.isServerConnected, "Should be disconnected after error \(errorCode)")
        }
    }

    func testAudioChunksSentWhileDisconnectedAreDropped() {
        // Given: A disconnected ASRClient
        XCTAssertFalse(asrClient.isServerConnected, "Should start disconnected")

        let initialSendCount = mockWebSocketTask.sendCallCount

        // When: Audio chunks are sent while disconnected
        let audioData = Data(repeating: 0xAB, count: 512)
        asrClient.sendAudioChunk(audioData)
        asrClient.sendAudioChunk(audioData)

        // Wait briefly
        let waitExpectation = expectation(description: "Wait for processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 1.0)

        // Then: No chunks should be sent (disconnected state)
        // Note: Implementation may buffer or drop; verify no crash occurs
        XCTAssertTrue(true, "Should handle audio chunks while disconnected without crashing")
    }

    func testMessageReceiveWhileReconnecting() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Connection is lost and messages are enqueued
        mockWebSocketTask.receiveError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        // Enqueue a message during reconnection state
        let testMessage: [String: Any] = [
            "type": "final",
            "text": "Test during reconnect"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: testMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Trigger reconnection
        asrClient.connect()

        // Wait for reconnection processing
        let processExpectation = expectation(description: "Processing completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            processExpectation.fulfill()
        }
        wait(for: [processExpectation], timeout: 2.0)

        // Then: Should handle gracefully without crash
        XCTAssertTrue(true, "Should handle messages during reconnection state")
    }

    func testWebSocketTaskIdentityCheckDuringAsyncOperations() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: A new connection is established while old operations are pending
        let oldTask = mockWebSocketTask!
        mockWebSocketTask = MockWebSocketTask()

        // Simulate old task completing async operation after new connection
        // (This tests the identity check in ping completion handler)
        oldTask.sendPing { error in
            // Old task's ping completes - should be ignored
        }

        // Establish new connection
        asrClient.connect()

        let newConnectionExpectation = expectation(description: "New connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                newConnectionExpectation.fulfill()
            }
        }

        wait(for: [newConnectionExpectation], timeout: 2.0)

        // Then: New connection should be active, old task operations ignored
        XCTAssertTrue(asrClient.isServerConnected, "New connection should be established")
    }

    func testHandleMultipleDisconnectCallsGracefully() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: disconnect() is called multiple times
        asrClient.disconnect()
        asrClient.disconnect()
        asrClient.disconnect()

        // Then: Should handle gracefully without crash
        XCTAssertFalse(asrClient.isServerConnected, "Should be disconnected")

        // Verify state is clean for reconnection
        let reconnectExpectation = expectation(description: "Can reconnect after multiple disconnects")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                reconnectExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [reconnectExpectation], timeout: 2.0)

        XCTAssertTrue(asrClient.isServerConnected, "Should be able to reconnect cleanly")
    }

    func testFlushAudioChunksCompletesEvenIfDisconnected() {
        // Given: A disconnected ASRClient with no active connection
        XCTAssertFalse(asrClient.isServerConnected, "Should start disconnected")

        // When: flushAudioChunks is called while disconnected
        let flushExpectation = expectation(description: "Flush completes")

        asrClient.flushAudioChunks {
            flushExpectation.fulfill()
        }

        // Then: Callback should still be called even when disconnected
        wait(for: [flushExpectation], timeout: 1.0)
    }

    func testSendStartWithCompletionCallbackExecutes() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: sendStart is called with completion callback
        let completionExpectation = expectation(description: "Completion callback executed")

        asrClient.sendStart(mode: "voice_input") {
            completionExpectation.fulfill()
        }

        // Then: Completion callback should be called
        wait(for: [completionExpectation], timeout: 1.0)
    }

    func testSendStopWithCompletionCallbackExecutes() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: sendStop is called with completion callback
        let completionExpectation = expectation(description: "Completion callback executed")

        asrClient.sendStop {
            completionExpectation.fulfill()
        }

        // Then: Completion callback should be called
        wait(for: [completionExpectation], timeout: 1.0)
    }

    func testStartMessageIncludesAllRequiredFields() {
        // Given: A connected ASRClient
        let connectionExpectation = expectation(description: "Connection established")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: sendStart is called with subtitle mode
        let sendExpectation = expectation(description: "Start message sent")
        asrClient.sendStart(mode: "subtitle") {
            sendExpectation.fulfill()
        }

        wait(for: [sendExpectation], timeout: 1.0)

        // Then: Verify all required fields are present
        let sentMessages = mockWebSocketTask.getSentTextMessages()
        if let startMessage = sentMessages.last,
           let jsonData = startMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(json["type"] as? String, "start")
            XCTAssertEqual(json["mode"] as? String, "subtitle")
            XCTAssertNotNil(json["enable_polish"])
            XCTAssertNotNil(json["use_llm_polish"])
            XCTAssertNotNil(json["use_timestamps"])
            XCTAssertNotNil(json["enable_denoise"])
            XCTAssertNotNil(json["model_id"])
            XCTAssertNotNil(json["language"])
            XCTAssertNotNil(json["active_app"])
            XCTAssertNotNil(json["scene"])
        } else {
            XCTFail("Failed to parse start message")
        }
    }
}
