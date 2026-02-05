import Foundation

/// Manages terminology learning from transcription history with intelligent filtering
final class TermLearner {
    var onSuggestionsChanged: (() -> Void)?

    private(set) var suggestions: [LearnedTerm] = []
    private(set) var approvedTerms: [LearnedTerm] = []
    private var rejectedTerms: Set<String> = []

    private let queue = DispatchQueue(label: "com.voiceflow.termlearner")
    private let fileURL: URL
    private let minFrequency = 3
    private let maxSuggestions = 20

    // Stop-word lists for filtering common words
    private let englishStopWords: Set<String> = [
        "the", "and", "is", "a", "an", "of", "to", "in", "for", "on", "with", "as", "at", "by", "from",
        "it", "that", "this", "or", "be", "are", "was", "were", "been", "have", "has", "had", "do",
        "does", "did", "will", "would", "could", "should", "may", "might", "can", "i", "you", "he",
        "she", "we", "they", "them", "their", "my", "your", "his", "her", "our", "what", "which",
        "who", "when", "where", "why", "how"
    ]

    private let chineseStopWords: Set<String> = [
        "的", "了", "是", "在", "我", "有", "和", "就", "不", "人", "都", "一", "个", "上", "也",
        "他", "这", "中", "大", "为", "来", "那", "要", "可以", "能", "会", "到", "说", "时",
        "地", "得", "着", "过", "么", "去", "好", "没", "与", "她"
    ]

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent("learned-terms.json")
        loadTerms()
    }

    // MARK: - Public API

    /// Analyze frequency from RecordingHistory and generate suggestions
    func analyzeAndRefresh(from recordingHistory: RecordingHistory) {
        queue.async { [weak self] in
            guard let self = self else { return }

            NSLog("[TermLearner] Starting frequency analysis")

            recordingHistory.analyzeWordFrequency { [weak self] frequencyMap in
                guard let self = self else { return }

                self.queue.async {
                    self.generateSuggestions(from: frequencyMap)
                }
            }
        }
    }

    /// Approve a suggestion and mark it as learned
    func approveSuggestion(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard let index = self.suggestions.firstIndex(where: { $0.id == id }) else {
                NSLog("[TermLearner] Suggestion not found: \(id)")
                return
            }

            var approvedTerm = self.suggestions[index]
            approvedTerm.isApproved = true

            self.suggestions.remove(at: index)
            self.approvedTerms.append(approvedTerm)
            self.saveTerms()

            DispatchQueue.main.async {
                self.onSuggestionsChanged?()
            }

            NSLog("[TermLearner] Approved term: \(approvedTerm.term)")
        }
    }

    /// Reject a suggestion to prevent it from being suggested again
    func rejectSuggestion(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard let index = self.suggestions.firstIndex(where: { $0.id == id }) else {
                NSLog("[TermLearner] Suggestion not found: \(id)")
                return
            }

            let rejectedTerm = self.suggestions[index]
            self.suggestions.remove(at: index)
            self.rejectedTerms.insert(rejectedTerm.term.lowercased())
            self.saveTerms()

            DispatchQueue.main.async {
                self.onSuggestionsChanged?()
            }

            NSLog("[TermLearner] Rejected term: \(rejectedTerm.term)")
        }
    }

    /// Add a manually corrected term
    func addManualCorrection(term: String, frequency: Int = 1) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let learnedTerm = LearnedTerm(
                term: term,
                frequency: frequency,
                source: .manualCorrection,
                isApproved: true
            )

            self.approvedTerms.append(learnedTerm)
            self.saveTerms()

            NSLog("[TermLearner] Added manual correction: \(term)")
        }
    }

    /// Export approved terms as JSON data
    func exportTerms() -> Data? {
        var result: Data?
        queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            result = try? encoder.encode(approvedTerms)
            NSLog("[TermLearner] Exported \(approvedTerms.count) learned terms")
        }
        return result
    }

    /// Import terms from JSON data, merging without duplicates
    func importTerms(from data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let decoder = JSONDecoder()
                let importedTerms = try decoder.decode([LearnedTerm].self, from: data)

                // Merge without duplicates (case-insensitive comparison)
                let existingTermsLower = Set(self.approvedTerms.map { $0.term.lowercased() })
                let newTerms = importedTerms.filter { !existingTermsLower.contains($0.term.lowercased()) }

                self.approvedTerms.append(contentsOf: newTerms)
                self.saveTerms()

                NSLog("[TermLearner] Imported \(newTerms.count) new terms (skipped \(importedTerms.count - newTerms.count) duplicates)")

                DispatchQueue.main.async {
                    self.onSuggestionsChanged?()
                }
            } catch {
                NSLog("[TermLearner] Import failed: \(error)")
            }
        }
    }

    /// Clear all suggestions and approved terms
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.suggestions.removeAll()
            self.approvedTerms.removeAll()
            self.rejectedTerms.removeAll()
            self.saveTerms()

            DispatchQueue.main.async {
                self.onSuggestionsChanged?()
            }

            NSLog("[TermLearner] Cleared all terms")
        }
    }

    // MARK: - Private Methods

    private func generateSuggestions(from frequencyMap: [String: Int]) {
        // Filter and rank candidates
        let candidates = frequencyMap
            .filter { word, frequency in
                // Must meet minimum frequency
                guard frequency >= minFrequency else { return false }

                // Must not be a stop-word
                guard !isStopWord(word) else { return false }

                // Must not be already approved
                let approvedTermsLower = Set(approvedTerms.map { $0.term.lowercased() })
                guard !approvedTermsLower.contains(word) else { return false }

                // Must not be rejected
                guard !rejectedTerms.contains(word) else { return false }

                return true
            }
            .sorted { lhs, rhs in
                // Sort by frequency descending, then alphabetically
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .prefix(maxSuggestions)
            .map { word, frequency in
                LearnedTerm(
                    term: word,
                    frequency: frequency,
                    source: .autoLearned,
                    isApproved: false
                )
            }

        suggestions = Array(candidates)

        DispatchQueue.main.async { [weak self] in
            self?.onSuggestionsChanged?()
        }

        NSLog("[TermLearner] Generated \(suggestions.count) suggestions from \(frequencyMap.count) unique words")
    }

    private func isStopWord(_ word: String) -> Bool {
        let normalized = word.lowercased()
        return englishStopWords.contains(normalized) || chineseStopWords.contains(normalized)
    }

    private func loadTerms() {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                NSLog("[TermLearner] No existing learned terms file")
                return
            }

            do {
                let data = try Data(contentsOf: self.fileURL)
                let decoder = JSONDecoder()

                // Try to decode the stored data structure
                if let terms = try? decoder.decode([LearnedTerm].self, from: data) {
                    self.approvedTerms = terms
                    NSLog("[TermLearner] Loaded \(self.approvedTerms.count) approved terms")
                } else if let storedData = try? decoder.decode(StoredData.self, from: data) {
                    self.approvedTerms = storedData.approvedTerms
                    self.rejectedTerms = storedData.rejectedTerms
                    NSLog("[TermLearner] Loaded \(self.approvedTerms.count) approved terms, \(self.rejectedTerms.count) rejected terms")
                }
            } catch {
                NSLog("[TermLearner] Failed to load terms: \(error)")
            }
        }
    }

    private func saveTerms() {
        do {
            let storedData = StoredData(
                approvedTerms: approvedTerms,
                rejectedTerms: rejectedTerms
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(storedData)
            try data.write(to: fileURL, options: .atomic)

            NSLog("[TermLearner] Saved \(approvedTerms.count) approved terms, \(rejectedTerms.count) rejected terms")
        } catch {
            NSLog("[TermLearner] Failed to save terms: \(error)")
        }
    }

    // MARK: - Storage Data Model

    private struct StoredData: Codable {
        let approvedTerms: [LearnedTerm]
        let rejectedTerms: Set<String>
    }
}
