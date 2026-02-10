import Foundation
import Combine

/// Manages persistence of custom vocabularies to disk using JSON storage
final class VocabularyStorage: ObservableObject {
    private let fileURL: URL
    @Published private(set) var vocabularies: [Vocabulary] = []

    init() {
        // Get Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                NSLog("[VocabularyStorage] Created app directory: \(appDirectory.path)")
            } catch {
                NSLog("[VocabularyStorage] ERROR: Failed to create directory: \(error.localizedDescription)")
            }
        }

        self.fileURL = appDirectory.appendingPathComponent("vocabularies.json")
        NSLog("[VocabularyStorage] Storage location: \(fileURL.path)")

        // Load existing vocabularies
        self.vocabularies = load()
    }

    // MARK: - Public API

    /// Get all vocabularies
    func getAll() -> [Vocabulary] {
        return vocabularies
    }

    /// Get a specific vocabulary by ID
    func get(id: UUID) -> Vocabulary? {
        return vocabularies.first(where: { $0.id == id })
    }

    /// Get vocabularies by IDs (for scene association)
    func getVocabularies(byIDs ids: [UUID]) -> [Vocabulary] {
        return vocabularies.filter { ids.contains($0.id) }
    }

    /// Get all terms from specified vocabularies (for ASR hotword biasing)
    /// - Parameter vocabularyIDs: Array of vocabulary IDs to extract terms from
    /// - Returns: Flat array of all terms from the specified vocabularies
    func getTerms(from vocabularyIDs: [UUID]) -> [String] {
        let selectedVocabularies = getVocabularies(byIDs: vocabularyIDs)
        return selectedVocabularies.flatMap { $0.terms }
    }

    /// Add a new vocabulary
    func add(_ vocabulary: Vocabulary) {
        vocabularies.append(vocabulary)
        save()
        NSLog("[VocabularyStorage] Added vocabulary: \(vocabulary.name) with \(vocabulary.entryCount) entries")
    }

    /// Update an existing vocabulary
    func update(_ vocabulary: Vocabulary) {
        guard let index = vocabularies.firstIndex(where: { $0.id == vocabulary.id }) else {
            NSLog("[VocabularyStorage] WARNING: Vocabulary not found for update: \(vocabulary.id.uuidString)")
            return
        }
        var updatedVocabulary = vocabulary
        updatedVocabulary.updatedAt = Date()
        vocabularies[index] = updatedVocabulary
        save()
        NSLog("[VocabularyStorage] Updated vocabulary: \(vocabulary.name) (\(vocabulary.entryCount) entries)")
    }

    /// Delete a vocabulary by ID
    func delete(id: UUID) {
        guard let index = vocabularies.firstIndex(where: { $0.id == id }) else {
            NSLog("[VocabularyStorage] WARNING: Vocabulary not found for deletion: \(id.uuidString)")
            return
        }
        let deletedVocabulary = vocabularies.remove(at: index)
        save()
        NSLog("[VocabularyStorage] Deleted vocabulary: \(deletedVocabulary.name)")
    }

    /// Add an entry to a specific vocabulary
    func addEntry(_ entry: VocabularyEntry, to vocabularyID: UUID) {
        guard let index = vocabularies.firstIndex(where: { $0.id == vocabularyID }) else {
            NSLog("[VocabularyStorage] WARNING: Vocabulary not found for adding entry: \(vocabularyID.uuidString)")
            return
        }
        vocabularies[index].entries.append(entry)
        vocabularies[index].updatedAt = Date()
        save()
        NSLog("[VocabularyStorage] Added entry '\(entry.term)' to vocabulary: \(vocabularies[index].name)")
    }

    /// Update an entry in a specific vocabulary
    func updateEntry(_ entry: VocabularyEntry, in vocabularyID: UUID) {
        guard let vocabIndex = vocabularies.firstIndex(where: { $0.id == vocabularyID }),
              let entryIndex = vocabularies[vocabIndex].entries.firstIndex(where: { $0.id == entry.id }) else {
            NSLog("[VocabularyStorage] WARNING: Entry not found for update: \(entry.id.uuidString)")
            return
        }
        vocabularies[vocabIndex].entries[entryIndex] = entry
        vocabularies[vocabIndex].updatedAt = Date()
        save()
        NSLog("[VocabularyStorage] Updated entry '\(entry.term)' in vocabulary: \(vocabularies[vocabIndex].name)")
    }

    /// Delete an entry from a specific vocabulary
    func deleteEntry(id: UUID, from vocabularyID: UUID) {
        guard let vocabIndex = vocabularies.firstIndex(where: { $0.id == vocabularyID }),
              let entryIndex = vocabularies[vocabIndex].entries.firstIndex(where: { $0.id == id }) else {
            NSLog("[VocabularyStorage] WARNING: Entry not found for deletion: \(id.uuidString)")
            return
        }
        let deletedEntry = vocabularies[vocabIndex].entries.remove(at: entryIndex)
        vocabularies[vocabIndex].updatedAt = Date()
        save()
        NSLog("[VocabularyStorage] Deleted entry '\(deletedEntry.term)' from vocabulary: \(vocabularies[vocabIndex].name)")
    }

    // MARK: - Import/Export

    /// Import vocabularies from JSON data
    /// - Parameter data: JSON data containing vocabulary array
    /// - Returns: Number of vocabularies imported, or nil on error
    func importFromJSON(data: Data) -> Int? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedVocabularies = try decoder.decode([Vocabulary].self, from: data)

            var importCount = 0
            for vocab in importedVocabularies {
                // Check if vocabulary with same name exists
                if let existingIndex = vocabularies.firstIndex(where: { $0.name == vocab.name }) {
                    // Update existing vocabulary
                    vocabularies[existingIndex] = vocab
                    NSLog("[VocabularyStorage] Updated existing vocabulary from import: \(vocab.name)")
                } else {
                    // Add new vocabulary
                    vocabularies.append(vocab)
                    NSLog("[VocabularyStorage] Imported new vocabulary: \(vocab.name)")
                }
                importCount += 1
            }

            save()
            NSLog("[VocabularyStorage] Import complete: \(importCount) vocabularies")
            return importCount
        } catch {
            NSLog("[VocabularyStorage] ERROR: Failed to import JSON: \(error.localizedDescription)")
            return nil
        }
    }

    /// Export vocabularies to JSON data
    /// - Parameter vocabularyIDs: Optional array of vocabulary IDs to export (nil exports all)
    /// - Returns: JSON data, or nil on error
    func exportToJSON(vocabularyIDs: [UUID]? = nil) -> Data? {
        let vocabulariesToExport: [Vocabulary]
        if let ids = vocabularyIDs {
            vocabulariesToExport = vocabularies.filter { ids.contains($0.id) }
        } else {
            vocabulariesToExport = vocabularies
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(vocabulariesToExport)
            NSLog("[VocabularyStorage] Exported \(vocabulariesToExport.count) vocabularies to JSON")
            return data
        } catch {
            NSLog("[VocabularyStorage] ERROR: Failed to export JSON: \(error.localizedDescription)")
            return nil
        }
    }

    /// Import vocabulary from CSV data
    /// Expected format: term,pronunciation,mapping,category
    /// - Parameter data: CSV data (UTF-8 encoded)
    /// - Parameter vocabularyName: Name for the imported vocabulary
    /// - Returns: The imported vocabulary, or nil on error
    func importFromCSV(data: Data, vocabularyName: String) -> Vocabulary? {
        guard let csvString = String(data: data, encoding: .utf8) else {
            NSLog("[VocabularyStorage] ERROR: Failed to decode CSV as UTF-8")
            return nil
        }

        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            NSLog("[VocabularyStorage] ERROR: CSV file is empty or has no data rows")
            return nil
        }

        var entries: [VocabularyEntry] = []

        // Skip header row (line 0) and process data rows
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let columns = parseCSVLine(line)
            guard !columns.isEmpty else { continue }

            let term = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { continue }

            let pronunciation = columns.count > 1 ? columns[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let mapping = columns.count > 2 ? columns[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let category = columns.count > 3 ? columns[3].trimmingCharacters(in: .whitespacesAndNewlines) : nil

            let entry = VocabularyEntry(
                term: term,
                pronunciation: pronunciation?.isEmpty == false ? pronunciation : nil,
                mapping: mapping?.isEmpty == false ? mapping : nil,
                category: category?.isEmpty == false ? category : nil
            )
            entries.append(entry)
        }

        guard !entries.isEmpty else {
            NSLog("[VocabularyStorage] ERROR: No valid entries found in CSV")
            return nil
        }

        let vocabulary = Vocabulary(
            name: vocabularyName,
            description: "Imported from CSV",
            entries: entries
        )

        NSLog("[VocabularyStorage] Imported \(entries.count) entries from CSV")
        return vocabulary
    }

    /// Export vocabulary to CSV data
    /// Format: term,pronunciation,mapping,category
    /// - Parameter vocabularyID: ID of vocabulary to export
    /// - Returns: CSV data (UTF-8 encoded), or nil on error
    func exportToCSV(vocabularyID: UUID) -> Data? {
        guard let vocabulary = get(id: vocabularyID) else {
            NSLog("[VocabularyStorage] ERROR: Vocabulary not found for CSV export: \(vocabularyID.uuidString)")
            return nil
        }

        var csvString = "term,pronunciation,mapping,category\n"

        for entry in vocabulary.entries {
            let term = escapeCSVField(entry.term)
            let pronunciation = escapeCSVField(entry.pronunciation ?? "")
            let mapping = escapeCSVField(entry.mapping ?? "")
            let category = escapeCSVField(entry.category ?? "")
            csvString += "\(term),\(pronunciation),\(mapping),\(category)\n"
        }

        guard let data = csvString.data(using: .utf8) else {
            NSLog("[VocabularyStorage] ERROR: Failed to encode CSV as UTF-8")
            return nil
        }

        NSLog("[VocabularyStorage] Exported vocabulary '\(vocabulary.name)' to CSV (\(vocabulary.entryCount) entries)")
        return data
    }

    // MARK: - CSV Helpers

    /// Parse a single CSV line, handling quoted fields properly
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]

            if char == "\"" {
                if insideQuotes {
                    // Check for escaped quote ("")
                    let nextIndex = line.index(after: index)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            index = line.index(after: index)
        }

        // Add the last field
        fields.append(currentField)

        return fields
    }

    /// Escape a CSV field by adding quotes if needed
    private func escapeCSVField(_ field: String) -> String {
        // Need quotes if field contains comma, quote, or newline
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Persistence

    private func load() -> [Vocabulary] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("[VocabularyStorage] No existing vocabularies file found, starting with empty list")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let vocabularies = try decoder.decode([Vocabulary].self, from: data)
            NSLog("[VocabularyStorage] Loaded \(vocabularies.count) vocabularies from disk")
            return vocabularies
        } catch {
            NSLog("[VocabularyStorage] ERROR: Failed to load vocabularies: \(error.localizedDescription)")
            return []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(vocabularies)
            try data.write(to: fileURL, options: [.atomic])
            NSLog("[VocabularyStorage] Saved \(vocabularies.count) vocabularies to disk")
        } catch {
            NSLog("[VocabularyStorage] ERROR: Failed to save vocabularies: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    /// Get total number of entries across all vocabularies
    var totalEntryCount: Int {
        return vocabularies.reduce(0) { $0 + $1.entryCount }
    }

    /// Get vocabulary statistics
    var statistics: (vocabularyCount: Int, totalEntries: Int, averageEntriesPerVocabulary: Double) {
        let count = vocabularies.count
        let total = totalEntryCount
        let average = count > 0 ? Double(total) / Double(count) : 0.0
        return (count, total, average)
    }
}
