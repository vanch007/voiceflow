import XCTest
@testable import VoiceFlow

/// Unit tests for TermLearner frequency analysis and suggestion workflow
final class TermLearnerTests: XCTestCase {
    var termLearner: TermLearner!
    var recordingHistory: RecordingHistory!

    override func setUp() {
        super.setUp()
        termLearner = TermLearner()
        recordingHistory = RecordingHistory()

        // Clear any existing data
        let clearExpectation = expectation(description: "Clear all terms")
        termLearner.clearAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 1.0)
    }

    override func tearDown() {
        termLearner = nil
        recordingHistory = nil
        super.tearDown()
    }

    // MARK: - Frequency Analysis Tests

    func testFrequencyAnalysisAccuracy() {
        // Given: Sample transcription history with repeated terms
        let sampleTexts = [
            "MLX framework is powerful for machine learning",
            "Using MLX for neural networks on Mac",
            "MLX provides efficient computation",
            "The framework integrates well with Swift",
            "MLX and Swift work together seamlessly"
        ]

        // Add entries to history
        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Analyze frequency
        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Then: MLX should appear with frequency of 5
        let mlxSuggestion = termLearner.suggestions.first { $0.term.lowercased() == "mlx" }
        XCTAssertNotNil(mlxSuggestion, "MLX should be suggested")
        XCTAssertEqual(mlxSuggestion?.frequency, 5, "MLX frequency should be 5")

        // Swift should appear with frequency of 2
        let swiftSuggestion = termLearner.suggestions.first { $0.term.lowercased() == "swift" }
        XCTAssertNotNil(swiftSuggestion, "Swift should be suggested")
        XCTAssertEqual(swiftSuggestion?.frequency, 2, "Swift frequency should be 2 (appears twice)")

        // Framework should appear with frequency of 3
        let frameworkSuggestion = termLearner.suggestions.first { $0.term.lowercased() == "framework" }
        XCTAssertNotNil(frameworkSuggestion, "Framework should be suggested")
        XCTAssertEqual(frameworkSuggestion?.frequency, 3, "Framework frequency should be 3")
    }

    func testStopWordFiltering() {
        // Given: Sample text with many stop-words
        let sampleTexts = [
            "The quick brown fox jumps over the lazy dog",
            "This is a test of the stop word filtering system",
            "Can we filter out common words like and or but",
            "Testing the filtering system for common words",
            "The system should work correctly with this test"
        ]

        // Add entries to history
        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Analyze frequency
        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Then: Common stop-words should NOT appear in suggestions
        let stopWords = ["the", "and", "is", "a", "of", "to", "in", "for", "on", "with", "this", "or"]
        for stopWord in stopWords {
            let found = termLearner.suggestions.contains { $0.term.lowercased() == stopWord }
            XCTAssertFalse(found, "\(stopWord) should be filtered out as stop-word")
        }

        // Content words with sufficient frequency should appear
        let contentWords = ["filtering", "system", "test"]
        for word in contentWords {
            let found = termLearner.suggestions.contains { $0.term.lowercased() == word }
            XCTAssertTrue(found, "\(word) should appear in suggestions")
        }
    }

    func testChineseStopWordFiltering() {
        // Given: Sample Chinese text with stop-words
        let sampleTexts = [
            "这是一个测试系统",
            "我们的系统运行良好",
            "系统可以过滤常见词汇",
            "测试结果显示系统正常"
        ]

        // Add entries to history
        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Analyze frequency
        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Then: Chinese stop-words should be filtered
        let chineseStopWords = ["这", "是", "的", "我", "一个", "可以"]
        for stopWord in chineseStopWords {
            let found = termLearner.suggestions.contains { $0.term == stopWord }
            XCTAssertFalse(found, "\(stopWord) should be filtered out as Chinese stop-word")
        }

        // "系统" should appear (frequency >= 3)
        let systemSuggestion = termLearner.suggestions.first { $0.term == "系统" }
        XCTAssertNotNil(systemSuggestion, "系统 should be suggested")
    }

    // MARK: - Deduplication Tests

    func testTermDeduplication() {
        // Given: A suggestion already exists
        let sampleTexts = [
            "MLX framework for machine learning",
            "MLX provides efficient computation",
            "Using MLX on macOS devices"
        ]

        // Add entries and generate suggestions
        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Get MLX suggestion ID
        guard let mlxSuggestion = termLearner.suggestions.first(where: { $0.term.lowercased() == "mlx" }) else {
            XCTFail("MLX suggestion should exist")
            return
        }

        // When: Approve the suggestion
        let approveExpectation = expectation(description: "Approve suggestion")
        termLearner.approveSuggestion(id: mlxSuggestion.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            approveExpectation.fulfill()
        }
        wait(for: [approveExpectation], timeout: 2.0)

        // Then: MLX should not appear in suggestions again
        let mlxStillInSuggestions = termLearner.suggestions.contains { $0.term.lowercased() == "mlx" }
        XCTAssertFalse(mlxStillInSuggestions, "MLX should not appear in suggestions after approval")

        // And: MLX should be in approved terms
        let mlxInApproved = termLearner.approvedTerms.contains { $0.term.lowercased() == "mlx" }
        XCTAssertTrue(mlxInApproved, "MLX should be in approved terms")

        // When: Re-analyze with same history
        let reanalyzeExpectation = expectation(description: "Re-analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reanalyzeExpectation.fulfill()
        }
        wait(for: [reanalyzeExpectation], timeout: 2.0)

        // Then: MLX should still not appear in suggestions (deduplication works)
        let mlxAfterReanalysis = termLearner.suggestions.contains { $0.term.lowercased() == "mlx" }
        XCTAssertFalse(mlxAfterReanalysis, "MLX should not reappear after re-analysis")
    }

    // MARK: - Export/Import Tests

    func testExportFormatWithMetadata() {
        // Given: Approved terms with different sources
        let addExpectation = expectation(description: "Add terms")

        // Add manual correction term
        termLearner.addManualCorrection(term: "TensorFlow", frequency: 3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Export terms
        guard let exportData = termLearner.exportTerms() else {
            XCTFail("Export should return data")
            return
        }

        // Then: Parse and validate JSON structure
        guard let jsonObject = try? JSONSerialization.jsonObject(with: exportData) as? [[String: Any]] else {
            XCTFail("Export should be valid JSON array")
            return
        }

        XCTAssertGreaterThan(jsonObject.count, 0, "Export should contain terms")

        // Verify metadata fields are present
        for termDict in jsonObject {
            XCTAssertNotNil(termDict["id"], "Term should have id field")
            XCTAssertNotNil(termDict["term"], "Term should have term field")
            XCTAssertNotNil(termDict["frequency"], "Term should have frequency field")
            XCTAssertNotNil(termDict["source"], "Term should have source field")
            XCTAssertNotNil(termDict["timestamp"], "Term should have timestamp field")
            XCTAssertNotNil(termDict["isApproved"], "Term should have isApproved field")

            // Verify source is valid enum value
            if let source = termDict["source"] as? String {
                XCTAssertTrue(source == "auto" || source == "correction", "Source should be 'auto' or 'correction'")
            }
        }
    }

    func testImportMergeWithoutDuplicates() {
        // Given: Existing approved term "MLX"
        let sampleTexts = [
            "MLX framework for machine learning",
            "MLX provides efficient computation",
            "Using MLX on macOS devices"
        ]

        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Approve MLX
        guard let mlxSuggestion = termLearner.suggestions.first(where: { $0.term.lowercased() == "mlx" }) else {
            XCTFail("MLX suggestion should exist")
            return
        }

        let approveExpectation = expectation(description: "Approve MLX")
        termLearner.approveSuggestion(id: mlxSuggestion.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            approveExpectation.fulfill()
        }
        wait(for: [approveExpectation], timeout: 2.0)

        // When: Import data containing duplicate "MLX" and new term "TensorFlow"
        let importTerms = [
            LearnedTerm(term: "MLX", frequency: 10, source: .autoLearned, isApproved: true),
            LearnedTerm(term: "TensorFlow", frequency: 7, source: .autoLearned, isApproved: true),
            LearnedTerm(term: "PyTorch", frequency: 5, source: .manualCorrection, isApproved: true)
        ]

        guard let importData = try? JSONEncoder().encode(importTerms) else {
            XCTFail("Failed to encode import data")
            return
        }

        let importExpectation = expectation(description: "Import terms")
        termLearner.importTerms(from: importData)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            importExpectation.fulfill()
        }
        wait(for: [importExpectation], timeout: 2.0)

        // Then: Should have exactly 3 unique terms (MLX not duplicated)
        let approvedCount = termLearner.approvedTerms.count
        XCTAssertEqual(approvedCount, 3, "Should have 3 unique terms after import")

        // Verify MLX appears only once
        let mlxCount = termLearner.approvedTerms.filter { $0.term.lowercased() == "mlx" }.count
        XCTAssertEqual(mlxCount, 1, "MLX should appear only once (no duplicates)")

        // Verify new terms were imported
        let hasTensorFlow = termLearner.approvedTerms.contains { $0.term == "TensorFlow" }
        XCTAssertTrue(hasTensorFlow, "TensorFlow should be imported")

        let hasPyTorch = termLearner.approvedTerms.contains { $0.term == "PyTorch" }
        XCTAssertTrue(hasPyTorch, "PyTorch should be imported")
    }

    // MARK: - Minimum Frequency Tests

    func testMinimumFrequencyThreshold() {
        // Given: Terms with varying frequencies
        let sampleTexts = [
            "Alpha is mentioned once",
            "Beta appears twice in this text and Beta appears again",
            "Gamma shows up three times here and Gamma is also here and Gamma appears again"
        ]

        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Analyze frequency
        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Then: Only terms with frequency >= 3 should appear
        let alphaFound = termLearner.suggestions.contains { $0.term.lowercased() == "alpha" }
        XCTAssertFalse(alphaFound, "Alpha (freq=1) should not be suggested")

        let betaFound = termLearner.suggestions.contains { $0.term.lowercased() == "beta" }
        XCTAssertFalse(betaFound, "Beta (freq=2) should not be suggested")

        let gammaFound = termLearner.suggestions.contains { $0.term.lowercased() == "gamma" }
        XCTAssertTrue(gammaFound, "Gamma (freq=3) should be suggested")
    }

    // MARK: - Rejection Tests

    func testRejectedTermsNotResuggested() {
        // Given: Terms in history
        let sampleTexts = [
            "Framework is used for development",
            "This framework provides good features",
            "The framework works well with Swift"
        ]

        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // When: Reject "framework" suggestion
        guard let frameworkSuggestion = termLearner.suggestions.first(where: { $0.term.lowercased() == "framework" }) else {
            XCTFail("Framework suggestion should exist")
            return
        }

        let rejectExpectation = expectation(description: "Reject suggestion")
        termLearner.rejectSuggestion(id: frameworkSuggestion.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            rejectExpectation.fulfill()
        }
        wait(for: [rejectExpectation], timeout: 2.0)

        // Then: Re-analyze should not suggest "framework" again
        let reanalyzeExpectation = expectation(description: "Re-analyze")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reanalyzeExpectation.fulfill()
        }
        wait(for: [reanalyzeExpectation], timeout: 2.0)

        let frameworkAfterReject = termLearner.suggestions.contains { $0.term.lowercased() == "framework" }
        XCTAssertFalse(frameworkAfterReject, "Rejected term should not be re-suggested")
    }

    // MARK: - Sorting Tests

    func testSuggestionsSortedByFrequency() {
        // Given: Terms with different frequencies
        let sampleTexts = [
            "Alpha Alpha Alpha Alpha Alpha",
            "Beta Beta Beta",
            "Gamma Gamma Gamma Gamma"
        ]

        let addExpectation = expectation(description: "Add entries")
        for text in sampleTexts {
            recordingHistory.addEntry(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)

        // When: Analyze frequency
        let analyzeExpectation = expectation(description: "Analyze frequency")
        termLearner.analyzeAndRefresh(from: recordingHistory)

        termLearner.onSuggestionsChanged = {
            analyzeExpectation.fulfill()
        }

        wait(for: [analyzeExpectation], timeout: 3.0)

        // Then: Suggestions should be sorted by frequency (descending)
        XCTAssertGreaterThan(termLearner.suggestions.count, 0, "Should have suggestions")

        for i in 0..<(termLearner.suggestions.count - 1) {
            let current = termLearner.suggestions[i]
            let next = termLearner.suggestions[i + 1]

            // If frequencies differ, current should be >= next
            if current.frequency != next.frequency {
                XCTAssertGreaterThanOrEqual(current.frequency, next.frequency,
                    "Suggestions should be sorted by frequency descending")
            } else {
                // If frequencies match, should be sorted alphabetically
                XCTAssertLessThanOrEqual(current.term, next.term,
                    "Suggestions with same frequency should be sorted alphabetically")
            }
        }
    }
}
