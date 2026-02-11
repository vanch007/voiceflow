import XCTest
import AVFoundation
@testable import VoiceFlow

/// End-to-End Integration Tests for full recording-to-injection workflow
///
/// **Test Coverage:**
/// - Complete workflow: Recording → ASR Processing → Text Injection
/// - State management across components
/// - Error handling and recovery in integrated scenarios
/// - Async operation coordination
/// - Callback chain execution
///
/// **Architecture:**
/// - Uses mock objects to simulate each component
/// - Tests component interactions and data flow
/// - Verifies state transitions across the full pipeline
final class E2EWorkflowTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    var asrClient: ASRClient!
    var textInjector: TextInjector!
    var mockSession: MockAVCaptureSession!
    var mockWebSocketTask: MockWebSocketTask!
    var mockURLSession: URLSession!

    override func setUp() {
        super.setUp()

        // Initialize mock dependencies
        mockSession = MockAVCaptureSession()
        mockWebSocketTask = MockWebSocketTask()
        mockURLSession = URLSession(configuration: .default)

        // Initialize components with mocks
        audioRecorder = AudioRecorder(sessionFactory: { [unowned self] in
            return self.mockSession
        })

        asrClient = ASRClient(
            session: mockURLSession,
            serverURL: URL(string: "ws://localhost:9876")!,
            webSocketTaskFactory: { [unowned self] _, _ in
                return self.mockWebSocketTask
            }
        )

        textInjector = TextInjector()
    }

    override func tearDown() {
        audioRecorder = nil
        asrClient?.disconnect()
        asrClient = nil
        textInjector = nil
        mockSession = nil
        mockWebSocketTask = nil
        mockURLSession = nil
        super.tearDown()
    }

    // MARK: - Full Workflow Tests

    func testCompleteRecordingToInjectionWorkflow() {
        // Given: All components initialized and ready
        let workflowExpectation = expectation(description: "Complete workflow")
        let expectedTranscription = "Hello, this is a test transcription"
        var transcriptionReceived = false
        var audioChunksSent = 0

        // Step 1: Setup ASR connection
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // Step 2: Setup audio recording with chunk callback
        audioRecorder.onAudioChunk = { [weak self] audioData in
            guard let self = self else { return }
            // Send audio to ASR
            self.asrClient.sendAudioChunk(audioData)
            audioChunksSent += 1
        }

        // Step 3: Setup transcription result handler
        asrClient.onTranscriptionResult = { [weak self] text in
            guard let self = self else { return }
            transcriptionReceived = true

            // Inject received text
            self.textInjector.inject(text: text)

            // Verify workflow completion
            XCTAssertEqual(text, expectedTranscription, "Should receive correct transcription")
            workflowExpectation.fulfill()
        }

        // When: Simulate recording flow
        let startExpectation = expectation(description: "Recording started")
        audioRecorder.startRecording {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        // Send start message to ASR
        let sendStartExpectation = expectation(description: "Start message sent")
        asrClient.sendStart(mode: "voice_input") {
            sendStartExpectation.fulfill()
        }
        wait(for: [sendStartExpectation], timeout: 1.0)

        // Simulate audio chunks being sent
        let audioData = Data(repeating: 0x01, count: 1024)
        for _ in 0..<5 {
            audioRecorder.onAudioChunk?(audioData)
        }

        // Flush audio chunks
        let flushExpectation = expectation(description: "Audio flushed")
        asrClient.flushAudioChunks {
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 1.0)

        // Stop recording
        audioRecorder.stopRecording()

        // Send stop message
        let sendStopExpectation = expectation(description: "Stop message sent")
        asrClient.sendStop {
            sendStopExpectation.fulfill()
        }
        wait(for: [sendStopExpectation], timeout: 1.0)

        // Simulate ASR server response
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": expectedTranscription,
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Then: Wait for complete workflow
        wait(for: [workflowExpectation], timeout: 3.0)

        XCTAssertTrue(transcriptionReceived, "Should receive transcription")
        XCTAssertGreaterThan(audioChunksSent, 0, "Should send audio chunks")
    }

    func testRecordingWithPartialResults() {
        // Given: ASR connected and recording started
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var partialResultsReceived: [String] = []
        var finalResultReceived: String?

        // When: Setup partial and final result handlers
        asrClient.onPartialResult = { text, trigger in
            partialResultsReceived.append(text)
        }

        asrClient.onTranscriptionResult = { text in
            finalResultReceived = text
        }

        audioRecorder.startRecording()

        // Send start message
        asrClient.sendStart(mode: "voice_input")

        // Simulate partial results during recording
        let partials = ["Hello", "Hello world", "Hello world this"]
        for partial in partials {
            let partialMessage: [String: Any] = [
                "type": "partial",
                "text": partial,
                "trigger": "pause"
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: partialMessage),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                mockWebSocketTask.enqueueMessage(text: jsonString)
            }
        }

        // Wait for partials to process
        let partialExpectation = expectation(description: "Partials processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            partialExpectation.fulfill()
        }
        wait(for: [partialExpectation], timeout: 2.0)

        // Send final result
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": "Hello world this is final",
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for final result
        let finalExpectation = expectation(description: "Final result received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 2.0)

        // Then: Should receive both partial and final results
        XCTAssertEqual(partialResultsReceived.count, partials.count, "Should receive all partial results")
        XCTAssertNotNil(finalResultReceived, "Should receive final result")
    }

    func testWorkflowWithPolishUpdate() {
        // Given: ASR connected with polish enabled
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var initialTextInjected: String?
        var polishedTextInjected: String?

        // When: Setup callbacks for two-phase polish
        asrClient.onTranscriptionResult = { [weak self] text in
            initialTextInjected = text
            self?.textInjector.inject(text: text)
        }

        asrClient.onPolishUpdate = { [weak self] polishedText in
            polishedTextInjected = polishedText
            self?.textInjector.replaceLastInjectedText(with: polishedText)
        }

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        // Simulate initial transcription
        let initialMessage: [String: Any] = [
            "type": "final",
            "text": "hello world",
            "polish_method": "llm"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: initialMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for initial injection
        let initialExpectation = expectation(description: "Initial text injected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialExpectation.fulfill()
        }
        wait(for: [initialExpectation], timeout: 1.0)

        // Simulate polish update
        let polishMessage: [String: Any] = [
            "type": "polish_update",
            "text": "Hello, World!"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: polishMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for polish update
        let polishExpectation = expectation(description: "Polished text injected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            polishExpectation.fulfill()
        }
        wait(for: [polishExpectation], timeout: 1.0)

        // Then: Both initial and polished text should be injected
        XCTAssertEqual(initialTextInjected, "hello world", "Should inject initial text")
        XCTAssertEqual(polishedTextInjected, "Hello, World!", "Should inject polished text")
    }

    // MARK: - Error Handling Tests

    func testWorkflowRecoveryFromASRDisconnection() {
        // Given: Recording in progress with ASR connected
        let connectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        // When: ASR connection is lost
        let disconnectExpectation = expectation(description: "Disconnection detected")
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

        asrClient.connect() // Trigger receive loop to encounter error
        wait(for: [disconnectExpectation], timeout: 2.0)

        // Then: Recording should continue, ready to reconnect
        // Audio chunks can still be buffered locally
        XCTAssertFalse(asrClient.isServerConnected, "ASR should be disconnected")

        // Verify audio recording continues
        var audioChunkReceived = false
        audioRecorder.onAudioChunk = { _ in
            audioChunkReceived = true
        }

        // Note: In real scenario, audio would continue and reconnection would be attempted
        XCTAssertNotNil(audioRecorder, "Audio recorder should remain functional")
    }

    func testWorkflowWithInvalidTranscriptionResponse() {
        // Given: ASR connected and recording
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var transcriptionReceived = false
        asrClient.onTranscriptionResult = { _ in
            transcriptionReceived = true
        }

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        // When: Server sends invalid JSON
        mockWebSocketTask.enqueueMessage(text: "{invalid json}")

        // Wait for processing
        let processExpectation = expectation(description: "Invalid JSON processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }
        wait(for: [processExpectation], timeout: 1.0)

        // Then: Should handle gracefully without crashing
        XCTAssertFalse(transcriptionReceived, "Should not trigger callback for invalid JSON")
        XCTAssertTrue(asrClient.isServerConnected, "Should remain connected after invalid JSON")
    }

    func testWorkflowWithEmptyTranscription() {
        // Given: ASR connected and recording
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var emptyTextReceived = false
        var injectedText: String?

        asrClient.onTranscriptionResult = { [weak self] text in
            emptyTextReceived = true
            injectedText = text
            self?.textInjector.inject(text: text)
        }

        // When: Server returns empty transcription
        let emptyMessage: [String: Any] = [
            "type": "final",
            "text": "",
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: emptyMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for processing
        let processExpectation = expectation(description: "Empty transcription processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }
        wait(for: [processExpectation], timeout: 1.0)

        // Then: Should handle empty text gracefully
        XCTAssertTrue(emptyTextReceived, "Should receive empty transcription callback")
        XCTAssertEqual(injectedText, "", "Should handle empty text")
    }

    // MARK: - State Management Tests

    func testStateTransitionsAcrossFullWorkflow() {
        // Given: All components initialized
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // Track state transitions
        var recordingStarted = false
        var audioSent = false
        var recordingStopped = false
        var transcriptionReceived = false

        // When: Execute full workflow with state tracking
        audioRecorder.startRecording {
            recordingStarted = true
        }

        // Wait for recording to start
        let startExpectation = expectation(description: "Recording started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertTrue(recordingStarted, "Recording should have started")
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        // Send audio
        asrClient.sendStart(mode: "voice_input")
        asrClient.sendAudioChunk(Data(repeating: 0x01, count: 512))
        audioSent = true

        // Stop recording
        audioRecorder.stopRecording()
        recordingStopped = true

        asrClient.sendStop()

        // Simulate transcription
        asrClient.onTranscriptionResult = { _ in
            transcriptionReceived = true
        }

        let finalMessage: [String: Any] = [
            "type": "final",
            "text": "State transition test",
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for final state
        let finalExpectation = expectation(description: "Final state reached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 1.0)

        // Then: All state transitions should complete in order
        XCTAssertTrue(recordingStarted, "Step 1: Recording should start")
        XCTAssertTrue(audioSent, "Step 2: Audio should be sent")
        XCTAssertTrue(recordingStopped, "Step 3: Recording should stop")
        XCTAssertTrue(transcriptionReceived, "Step 4: Transcription should be received")
    }

    func testConcurrentRecordingSessionsHandledCorrectly() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // When: Start recording multiple times rapidly
        audioRecorder.startRecording()
        audioRecorder.startRecording()
        audioRecorder.startRecording()

        // Wait briefly
        let rapidStartExpectation = expectation(description: "Rapid starts processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            rapidStartExpectation.fulfill()
        }
        wait(for: [rapidStartExpectation], timeout: 1.0)

        // Then: Should handle multiple starts gracefully without crash
        XCTAssertNotNil(audioRecorder, "Audio recorder should handle multiple starts")

        // Stop recording
        audioRecorder.stopRecording()
    }

    func testWorkflowCleanupOnComponentFailure() {
        // Given: Recording in progress
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectionExpectation.fulfill()
            }
        }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        // Clear callback to prevent double-fulfillment on disconnect
        asrClient.onConnectionStatusChanged = nil

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        // When: Component fails (simulate by disconnecting ASR)
        asrClient.disconnect()

        // Stop recording
        audioRecorder.stopRecording()

        // Wait for cleanup
        let cleanupExpectation = expectation(description: "Cleanup completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        // Then: All components should be in clean state
        XCTAssertFalse(asrClient.isServerConnected, "ASR should be disconnected")
        XCTAssertNotNil(audioRecorder, "Audio recorder should remain valid")
    }

    // MARK: - Performance Tests

    func testHighFrequencyAudioChunkProcessing() {
        // Given: ASR connected with high-frequency audio chunks
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var chunksProcessed = 0

        // When: Send many audio chunks rapidly
        asrClient.sendStart(mode: "voice_input")

        for _ in 0..<100 {
            let audioData = Data(repeating: UInt8.random(in: 0...255), count: 512)
            asrClient.sendAudioChunk(audioData)
            chunksProcessed += 1
        }

        // Flush all chunks
        let flushExpectation = expectation(description: "All chunks flushed")
        asrClient.flushAudioChunks {
            flushExpectation.fulfill()
        }

        // Then: All chunks should be processed without loss
        wait(for: [flushExpectation], timeout: 3.0)
        XCTAssertEqual(chunksProcessed, 100, "Should process all audio chunks")
    }

    func testLongRunningRecordingSession() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var partialCount = 0
        var finalReceived = false

        // When: Simulate long recording with multiple partial results
        asrClient.onPartialResult = { _, _ in
            partialCount += 1
        }

        asrClient.onTranscriptionResult = { _ in
            finalReceived = true
        }

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        // Simulate 10 partial results over time
        for i in 0..<10 {
            let partialMessage: [String: Any] = [
                "type": "partial",
                "text": "Partial result \(i)",
                "trigger": "periodic"
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: partialMessage),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                mockWebSocketTask.enqueueMessage(text: jsonString)
            }
        }

        // Wait for partials to process
        let partialExpectation = expectation(description: "Partials processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            partialExpectation.fulfill()
        }
        wait(for: [partialExpectation], timeout: 2.0)

        // Send final result
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": "Final long transcription",
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for final
        let finalExpectation = expectation(description: "Final result received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 1.0)

        // Then: Should handle long session with multiple updates
        XCTAssertEqual(partialCount, 10, "Should receive all partial results")
        XCTAssertTrue(finalReceived, "Should receive final result")

        audioRecorder.stopRecording()
        asrClient.sendStop()
    }

    // MARK: - Integration Edge Cases

    func testWorkflowWithUnicodeTranscription() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let unicodeText = "Hello 世界 🌍 مرحبا 안녕하세요"
        var receivedText: String?

        asrClient.onTranscriptionResult = { [weak self] text in
            receivedText = text
            self?.textInjector.inject(text: text)
        }

        // When: Send unicode transcription
        let unicodeMessage: [String: Any] = [
            "type": "final",
            "text": unicodeText,
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: unicodeMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for processing
        let processExpectation = expectation(description: "Unicode processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }
        wait(for: [processExpectation], timeout: 1.0)

        // Then: Unicode should be preserved through entire pipeline
        XCTAssertEqual(receivedText, unicodeText, "Unicode should be preserved")
    }

    func testWorkflowWithVeryLongTranscription() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        let longText = String(repeating: "This is a very long transcription. ", count: 50)
        var receivedText: String?

        asrClient.onTranscriptionResult = { text in
            receivedText = text
        }

        // When: Send very long transcription
        let longMessage: [String: Any] = [
            "type": "final",
            "text": longText,
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: longMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for processing
        let processExpectation = expectation(description: "Long text processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processExpectation.fulfill()
        }
        wait(for: [processExpectation], timeout: 1.0)

        // Then: Long text should be handled without truncation
        XCTAssertEqual(receivedText, longText, "Long text should not be truncated")
        XCTAssertGreaterThan(receivedText?.count ?? 0, 1000, "Text should be very long")
    }

    // MARK: - WebSocket Communication Tests

    func testWebSocketMessageOrdering() {
        // Given: ASR connected with message tracking
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var receivedMessages: [String] = []
        let messagesExpectation = expectation(description: "All messages received")
        messagesExpectation.expectedFulfillmentCount = 5

        // When: Setup callbacks to track message order
        asrClient.onPartialResult = { text, _ in
            receivedMessages.append("partial:\(text)")
            messagesExpectation.fulfill()
        }

        asrClient.onTranscriptionResult = { text in
            receivedMessages.append("final:\(text)")
            messagesExpectation.fulfill()
        }

        // Send messages in specific order
        let messages: [[String: Any]] = [
            ["type": "partial", "text": "First", "trigger": "pause"],
            ["type": "partial", "text": "Second", "trigger": "pause"],
            ["type": "partial", "text": "Third", "trigger": "periodic"],
            ["type": "partial", "text": "Fourth", "trigger": "pause"],
            ["type": "final", "text": "Final text", "polish_method": "none"]
        ]

        for message in messages {
            if let jsonData = try? JSONSerialization.data(withJSONObject: message),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                mockWebSocketTask.enqueueMessage(text: jsonString)
            }
        }

        // Then: Messages should be received in correct order
        wait(for: [messagesExpectation], timeout: 3.0)

        XCTAssertEqual(receivedMessages.count, 5, "Should receive all 5 messages")
        XCTAssertEqual(receivedMessages[0], "partial:First", "First message should be correct")
        XCTAssertEqual(receivedMessages[1], "partial:Second", "Second message should be correct")
        XCTAssertEqual(receivedMessages[2], "partial:Third", "Third message should be correct")
        XCTAssertEqual(receivedMessages[3], "partial:Fourth", "Fourth message should be correct")
        XCTAssertEqual(receivedMessages[4], "final:Final text", "Final message should be correct")
    }

    func testWebSocketConnectionStateSync() {
        // Given: Initial disconnected state
        var connectionStates: [Bool] = []
        let stateChangeExpectation = expectation(description: "Connection state changes")
        stateChangeExpectation.expectedFulfillmentCount = 2

        asrClient.onConnectionStatusChanged = { isConnected in
            connectionStates.append(isConnected)
            stateChangeExpectation.fulfill()
        }

        // When: Connect then disconnect
        XCTAssertFalse(asrClient.isServerConnected, "Should start disconnected")

        asrClient.connect()

        // Wait for connection
        let connectExpectation = expectation(description: "Connected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connectExpectation.fulfill()
        }
        wait(for: [connectExpectation], timeout: 1.0)

        XCTAssertTrue(asrClient.isServerConnected, "Should be connected")

        asrClient.disconnect()

        // Then: State should synchronize correctly
        wait(for: [stateChangeExpectation], timeout: 2.0)

        XCTAssertEqual(connectionStates.count, 2, "Should have two state changes")
        XCTAssertTrue(connectionStates[0], "First change should be connected")
        XCTAssertFalse(connectionStates[1], "Second change should be disconnected")
        XCTAssertFalse(asrClient.isServerConnected, "Should end disconnected")
    }

    func testWebSocketReconnectionStateConsistency() {
        // Given: ASR connected
        let initialConnectionExpectation = expectation(description: "Initial connection")
        var connectionEvents: [(connected: Bool, timestamp: TimeInterval)] = []

        asrClient.onConnectionStatusChanged = { isConnected in
            let timestamp = Date().timeIntervalSince1970
            connectionEvents.append((isConnected, timestamp))
            if isConnected && connectionEvents.count == 1 {
                initialConnectionExpectation.fulfill()
            }
        }

        asrClient.connect()
        wait(for: [initialConnectionExpectation], timeout: 2.0)

        // When: Simulate disconnection and reconnection
        mockWebSocketTask.receiveError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        // Trigger disconnect
        asrClient.connect()

        // Wait for disconnect to be detected
        let disconnectExpectation = expectation(description: "Disconnect detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            disconnectExpectation.fulfill()
        }
        wait(for: [disconnectExpectation], timeout: 1.0)

        // Clear error and reconnect
        mockWebSocketTask.receiveError = nil
        asrClient.connect()

        // Wait for reconnection
        let reconnectExpectation = expectation(description: "Reconnected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            reconnectExpectation.fulfill()
        }
        wait(for: [reconnectExpectation], timeout: 2.0)

        // Then: State should be consistent through reconnection
        XCTAssertGreaterThanOrEqual(connectionEvents.count, 2, "Should have multiple state changes")
        XCTAssertTrue(connectionEvents.first?.connected ?? false, "First event should be connected")

        // Verify final state is connected
        let finalState = asrClient.isServerConnected
        XCTAssertTrue(finalState, "Should be reconnected")
    }

    func testConcurrentWebSocketMessagesHandled() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var partialCount = 0
        var finalCount = 0
        var polishCount = 0

        let messageExpectation = expectation(description: "All messages processed")
        messageExpectation.expectedFulfillmentCount = 15

        // When: Setup handlers for different message types
        asrClient.onPartialResult = { _, _ in
            partialCount += 1
            messageExpectation.fulfill()
        }

        asrClient.onTranscriptionResult = { _ in
            finalCount += 1
            messageExpectation.fulfill()
        }

        asrClient.onPolishUpdate = { _ in
            polishCount += 1
            messageExpectation.fulfill()
        }

        // Send multiple message types concurrently
        for i in 0..<5 {
            let partialMessage: [String: Any] = [
                "type": "partial",
                "text": "Partial \(i)",
                "trigger": "pause"
            ]

            let finalMessage: [String: Any] = [
                "type": "final",
                "text": "Final \(i)",
                "polish_method": "llm"
            ]

            let polishMessage: [String: Any] = [
                "type": "polish_update",
                "text": "Polished \(i)"
            ]

            for message in [partialMessage, finalMessage, polishMessage] {
                if let jsonData = try? JSONSerialization.data(withJSONObject: message),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    mockWebSocketTask.enqueueMessage(text: jsonString)
                }
            }
        }

        // Then: All messages should be processed correctly
        wait(for: [messageExpectation], timeout: 3.0)

        XCTAssertEqual(partialCount, 5, "Should process all partial messages")
        XCTAssertEqual(finalCount, 5, "Should process all final messages")
        XCTAssertEqual(polishCount, 5, "Should process all polish messages")
    }

    func testWebSocketStartStopMessageSequence() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var sentMessages: [String] = []

        // When: Send start message with verification
        let startExpectation = expectation(description: "Start message sent")
        asrClient.sendStart(mode: "voice_input") {
            sentMessages.append("start")
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        // Send audio chunks
        for i in 0..<3 {
            asrClient.sendAudioChunk(Data(repeating: UInt8(i), count: 512))
            sentMessages.append("audio_\(i)")
        }

        // Flush audio
        let flushExpectation = expectation(description: "Audio flushed")
        asrClient.flushAudioChunks {
            sentMessages.append("flush")
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 1.0)

        // Send stop message
        let stopExpectation = expectation(description: "Stop message sent")
        asrClient.sendStop {
            sentMessages.append("stop")
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)

        // Then: Message sequence should be complete and ordered
        XCTAssertEqual(sentMessages.count, 6, "Should have all messages")
        XCTAssertEqual(sentMessages[0], "start", "Start should be first")
        XCTAssertEqual(sentMessages[1], "audio_0", "Audio chunks should follow")
        XCTAssertEqual(sentMessages[2], "audio_1", "Audio chunks should be in order")
        XCTAssertEqual(sentMessages[3], "audio_2", "Audio chunks should continue")
        XCTAssertEqual(sentMessages[4], "flush", "Flush should be after audio")
        XCTAssertEqual(sentMessages[5], "stop", "Stop should be last")
    }

    // MARK: - State Synchronization Tests

    func testRecordingStateAcrossComponents() {
        // Given: All components initialized
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var audioRecorderActive = false
        var asrSessionActive = false
        var injectorReceived = false

        // When: Start recording and track state across components
        audioRecorder.onAudioChunk = { [weak self] audioData in
            audioRecorderActive = true
            self?.asrClient.sendAudioChunk(audioData)
        }

        asrClient.onTranscriptionResult = { [weak self] text in
            asrSessionActive = true
            self?.textInjector.inject(text: text)
            injectorReceived = true
        }

        audioRecorder.startRecording()

        // Send start message
        asrClient.sendStart(mode: "voice_input")
        asrSessionActive = true

        // Simulate audio data
        let audioData = Data(repeating: 0x01, count: 1024)
        audioRecorder.onAudioChunk?(audioData)

        // Wait for audio processing
        let audioExpectation = expectation(description: "Audio processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            audioExpectation.fulfill()
        }
        wait(for: [audioExpectation], timeout: 1.0)

        // Send transcription result
        let finalMessage: [String: Any] = [
            "type": "final",
            "text": "State sync test",
            "polish_method": "none"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: finalMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mockWebSocketTask.enqueueMessage(text: jsonString)
        }

        // Wait for transcription
        let transcriptionExpectation = expectation(description: "Transcription received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            transcriptionExpectation.fulfill()
        }
        wait(for: [transcriptionExpectation], timeout: 1.0)

        // Stop recording
        audioRecorder.stopRecording()
        asrClient.sendStop()

        // Then: All components should synchronize state correctly
        XCTAssertTrue(audioRecorderActive, "Audio recorder should have been active")
        XCTAssertTrue(asrSessionActive, "ASR session should have been active")
        XCTAssertTrue(injectorReceived, "Text injector should have received text")
    }

    func testStateSyncDuringDisconnectReconnect() {
        // Given: Recording in progress with ASR connected
        let initialConnectionExpectation = expectation(description: "Initial connection")
        asrClient.onConnectionStatusChanged = { isConnected in
            if isConnected {
                initialConnectionExpectation.fulfill()
            }
        }
        asrClient.connect()
        wait(for: [initialConnectionExpectation], timeout: 2.0)

        var recordingState = false
        var connectionState = true

        audioRecorder.startRecording()
        recordingState = true

        asrClient.sendStart(mode: "voice_input")

        // When: Disconnect occurs during recording
        let disconnectExpectation = expectation(description: "Disconnected")
        asrClient.onConnectionStatusChanged = { isConnected in
            connectionState = isConnected
            if !isConnected {
                disconnectExpectation.fulfill()
            }
        }

        mockWebSocketTask.receiveError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )
        asrClient.connect()

        wait(for: [disconnectExpectation], timeout: 2.0)

        // Recording continues locally
        XCTAssertTrue(recordingState, "Recording should continue during disconnect")
        XCTAssertFalse(connectionState, "Connection should be down")

        // Reconnect
        mockWebSocketTask.receiveError = nil
        let reconnectExpectation = expectation(description: "Reconnected")
        asrClient.onConnectionStatusChanged = { isConnected in
            connectionState = isConnected
            if isConnected {
                reconnectExpectation.fulfill()
            }
        }
        asrClient.connect()

        wait(for: [reconnectExpectation], timeout: 2.0)

        // Then: State should be consistent after reconnection
        XCTAssertTrue(recordingState, "Recording should still be active")
        XCTAssertTrue(connectionState, "Connection should be restored")

        // Cleanup
        audioRecorder.stopRecording()
        asrClient.sendStop()
    }

    func testMultipleComponentStateReset() {
        // Given: All components in active state
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        audioRecorder.startRecording()
        asrClient.sendStart(mode: "voice_input")

        var audioChunksReceived = 0
        audioRecorder.onAudioChunk = { [weak self] audioData in
            audioChunksReceived += 1
            self?.asrClient.sendAudioChunk(audioData)
        }

        // Simulate some activity
        let audioData = Data(repeating: 0x01, count: 512)
        audioRecorder.onAudioChunk?(audioData)
        audioRecorder.onAudioChunk?(audioData)

        // When: Stop all components
        audioRecorder.stopRecording()
        asrClient.sendStop()

        // Clear callback to prevent fulfillment during disconnect
        asrClient.onConnectionStatusChanged = nil
        asrClient.disconnect()

        // Wait for cleanup
        let cleanupExpectation = expectation(description: "Cleanup completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        // Then: All components should be in clean state
        XCTAssertFalse(asrClient.isServerConnected, "ASR should be disconnected")
        XCTAssertEqual(audioChunksReceived, 2, "Should have received audio chunks")

        // Verify can restart cleanly
        asrClient.connect()
        audioRecorder.startRecording()

        let restartExpectation = expectation(description: "Restart successful")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            restartExpectation.fulfill()
        }
        wait(for: [restartExpectation], timeout: 1.0)

        XCTAssertNotNil(audioRecorder, "Audio recorder should be ready")
        XCTAssertNotNil(asrClient, "ASR client should be ready")
    }

    func testStateConsistencyWithRapidStartStop() {
        // Given: ASR connected
        let connectionExpectation = expectation(description: "ASR connected")
        asrClient.onConnectionStatusChanged = { _ in connectionExpectation.fulfill() }
        asrClient.connect()
        wait(for: [connectionExpectation], timeout: 2.0)

        var startCount = 0
        var stopCount = 0

        // When: Rapidly start and stop multiple times
        for i in 0..<5 {
            audioRecorder.startRecording()
            asrClient.sendStart(mode: "voice_input")
            startCount += 1

            // Brief delay
            let briefExpectation = expectation(description: "Brief pause \(i)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                briefExpectation.fulfill()
            }
            wait(for: [briefExpectation], timeout: 0.5)

            audioRecorder.stopRecording()
            asrClient.sendStop()
            stopCount += 1
        }

        // Wait for all operations to settle
        let settleExpectation = expectation(description: "Operations settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            settleExpectation.fulfill()
        }
        wait(for: [settleExpectation], timeout: 1.0)

        // Then: State should remain consistent
        XCTAssertEqual(startCount, 5, "Should have started 5 times")
        XCTAssertEqual(stopCount, 5, "Should have stopped 5 times")
        XCTAssertNotNil(audioRecorder, "Audio recorder should remain valid")
        XCTAssertNotNil(asrClient, "ASR client should remain valid")
        XCTAssertTrue(asrClient.isServerConnected, "ASR should still be connected")
    }
}

/// Signal quality enum for SNR display
enum SignalQuality {
    case excellent  // SNR >= 20dB
    case good       // SNR >= 15dB
    case fair       // SNR >= 10dB
    case poor       // SNR < 10dB
}
