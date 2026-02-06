import Foundation

/// Manages custom dictionary words and learned term metadata
final class DictionaryManager {
    var onDictionaryChanged: (([String]) -> Void)?

    private(set) var words: Set<String> = []
    private(set) var learnedTerms: [LearnedTerm] = []

    private let queue = DispatchQueue(label: "com.voiceflow.dictionarymanager")
    private let fileURL: URL
    private let learnedTermsFileURL: URL

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent("custom_dictionary.json")
        self.learnedTermsFileURL = appDirectory.appendingPathComponent("learned_terms_metadata.json")

        loadDictionary()
    }

    // MARK: - Public API

    /// Add a word to the dictionary
    func addWord(_ word: String, metadata: LearnedTerm? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }

            self.words.insert(normalized)

            // If metadata provided, store it as learned term
            if let metadata = metadata {
                // Remove existing metadata for this term if any
                self.learnedTerms.removeAll { $0.term.lowercased() == normalized.lowercased() }
                self.learnedTerms.append(metadata)
            }

            self.saveDictionary()
            self.notifyChange()

            NSLog("[DictionaryManager] Added word: \(normalized)")
        }
    }

    /// Remove a word from the dictionary
    func removeWord(_ word: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.words.remove(word)

            // Also remove associated metadata
            self.learnedTerms.removeAll { $0.term.lowercased() == word.lowercased() }

            self.saveDictionary()
            self.notifyChange()

            NSLog("[DictionaryManager] Removed word: \(word)")
        }
    }

    /// Get all dictionary words as sorted array
    func getWords() -> [String] {
        var result: [String] = []
        queue.sync {
            result = Array(words).sorted()
        }
        return result
    }

    /// Get learned term metadata for a specific word
    func getMetadata(for word: String) -> LearnedTerm? {
        var result: LearnedTerm?
        queue.sync {
            result = learnedTerms.first { $0.term.lowercased() == word.lowercased() }
        }
        return result
    }

    /// Get all learned terms with metadata
    func getLearnedTerms() -> [LearnedTerm] {
        var result: [LearnedTerm] = []
        queue.sync {
            result = learnedTerms
        }
        return result
    }

    /// Clear all dictionary words
    func clearDictionary() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.words.removeAll()
            self.learnedTerms.removeAll()
            self.saveDictionary()
            self.notifyChange()

            NSLog("[DictionaryManager] Dictionary cleared")
        }
    }

    /// Export dictionary words as JSON data
    func exportDictionary() -> Data? {
        var result: Data?
        queue.sync {
            let exportData = ExportFormat(
                words: Array(words).sorted(),
                learned_terms: learnedTerms
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            result = try? encoder.encode(exportData)

            NSLog("[DictionaryManager] Exported \(words.count) words and \(learnedTerms.count) learned terms")
        }
        return result
    }

    /// Export dictionary as CSV format
    func exportAsCSV() -> String {
        var result = ""
        queue.sync {
            var lines = ["term,frequency,source,isApproved"]  // CSV header

            for word in words.sorted() {
                let metadata = learnedTerms.first { $0.term.lowercased() == word.lowercased() }
                let frequency = metadata?.frequency ?? 1
                let source = metadata?.source.rawValue ?? "manual"
                let isApproved = metadata?.isApproved ?? true

                // Escape commas and quotes in values
                let escapedWord = escapeCSV(word)

                lines.append("\(escapedWord),\(frequency),\(source),\(isApproved)")
            }

            result = lines.joined(separator: "\n")
            NSLog("[DictionaryManager] Exported \(words.count) words as CSV")
        }
        return result
    }

    /// Import dictionary from CSV format
    func importFromCSV(_ csvContent: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let lines = csvContent.components(separatedBy: .newlines)
            var importedCount = 0

            for (index, line) in lines.enumerated() {
                // Skip header and empty lines
                if index == 0 && line.lowercased().contains("term") { continue }
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

                let columns = self.parseCSVLine(line)
                guard columns.count >= 1 else { continue }

                let term = columns[0].trimmingCharacters(in: .whitespaces)
                guard !term.isEmpty else { continue }

                self.words.insert(term)

                // If frequency is provided, create metadata
                let frequency = columns.count >= 2 ? Int(columns[1]) ?? 1 : 1
                let sourceStr = columns.count >= 3 ? columns[2].trimmingCharacters(in: .whitespaces) : "correction"
                let source = LearnSource(rawValue: sourceStr) ?? .manualCorrection
                let isApproved = columns.count >= 4 ? (columns[3].lowercased() == "true") : true

                // Remove existing and add new
                self.learnedTerms.removeAll { $0.term.lowercased() == term.lowercased() }
                self.learnedTerms.append(LearnedTerm(
                    term: term,
                    frequency: frequency,
                    source: source,
                    timestamp: Date(),
                    isApproved: isApproved
                ))

                importedCount += 1
            }

            self.saveDictionary()
            self.notifyChange()

            NSLog("[DictionaryManager] Imported \(importedCount) terms from CSV")
        }
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result
    }

    /// Import dictionary words from JSON data
    func importDictionary(from data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let decoder = JSONDecoder()

                // Try new format first (with learned terms)
                if let exportData = try? decoder.decode(ExportFormat.self, from: data) {
                    // Merge words
                    for word in exportData.words {
                        self.words.insert(word)
                    }

                    // Merge learned terms without duplicates
                    let existingTermsLower = Set(self.learnedTerms.map { $0.term.lowercased() })
                    let newTerms = exportData.learned_terms.filter { !existingTermsLower.contains($0.term.lowercased()) }
                    self.learnedTerms.append(contentsOf: newTerms)

                    NSLog("[DictionaryManager] Imported \(exportData.words.count) words and \(newTerms.count) learned terms")
                }
                // Fall back to simple word array format
                else if let wordArray = try? decoder.decode([String].self, from: data) {
                    for word in wordArray {
                        self.words.insert(word)
                    }
                    NSLog("[DictionaryManager] Imported \(wordArray.count) words (legacy format)")
                }
                else {
                    NSLog("[DictionaryManager] Import failed: unrecognized format")
                    return
                }

                self.saveDictionary()
                self.notifyChange()
            }
        }
    }

    // MARK: - Private Methods

    private func notifyChange() {
        let wordsArray = Array(words).sorted()
        DispatchQueue.main.async { [weak self] in
            self?.onDictionaryChanged?(wordsArray)
        }
    }

    private func loadDictionary() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Load basic words
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                do {
                    let data = try Data(contentsOf: self.fileURL)
                    let decoder = JSONDecoder()

                    // Try to decode as array of strings
                    if let wordArray = try? decoder.decode([String].self, from: data) {
                        self.words = Set(wordArray)
                        NSLog("[DictionaryManager] Loaded \(self.words.count) words")
                    }
                } catch {
                    NSLog("[DictionaryManager] Failed to load dictionary: \(error)")
                }
            } else {
                NSLog("[DictionaryManager] No existing dictionary file")
            }

            // Load learned terms metadata
            if FileManager.default.fileExists(atPath: self.learnedTermsFileURL.path) {
                do {
                    let data = try Data(contentsOf: self.learnedTermsFileURL)
                    let decoder = JSONDecoder()
                    self.learnedTerms = try decoder.decode([LearnedTerm].self, from: data)
                    NSLog("[DictionaryManager] Loaded \(self.learnedTerms.count) learned terms with metadata")
                } catch {
                    NSLog("[DictionaryManager] Failed to load learned terms metadata: \(error)")
                }
            } else {
                NSLog("[DictionaryManager] No existing learned terms metadata file")
            }
        }
    }

    private func saveDictionary() {
        do {
            // Save basic words
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let wordArray = Array(words).sorted()
            let data = try encoder.encode(wordArray)
            try data.write(to: fileURL, options: .atomic)
            NSLog("[DictionaryManager] Saved \(words.count) words")

            // Save learned terms metadata
            let metadataData = try encoder.encode(learnedTerms)
            try metadataData.write(to: learnedTermsFileURL, options: .atomic)
            NSLog("[DictionaryManager] Saved \(learnedTerms.count) learned terms with metadata")
        } catch {
            NSLog("[DictionaryManager] Failed to save dictionary: \(error)")
        }
    }

    // MARK: - Data Models

    private struct ExportFormat: Codable {
        let words: [String]
        let learned_terms: [LearnedTerm]
    }
}
