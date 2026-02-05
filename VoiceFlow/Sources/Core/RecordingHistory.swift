import Foundation

/// Represents a single transcription entry in the recording history
struct RecordingEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

/// Manages transcription history with frequency analysis capabilities
final class RecordingHistory {
    var onEntriesChanged: (() -> Void)?

    private(set) var entries: [RecordingEntry] = []
    private let queue = DispatchQueue(label: "com.voiceflow.recordinghistory")
    private let fileURL: URL
    private let maxEntries = 50

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent("recording_history.json")
        loadEntries()
    }

    /// Add a new transcription entry
    func addEntry(text: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let entry = RecordingEntry(text: text)
            self.entries.insert(entry, at: 0)

            // Keep only the most recent maxEntries
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }

            self.saveEntries()

            DispatchQueue.main.async {
                self.onEntriesChanged?()
            }

            NSLog("[RecordingHistory] Added entry, total: \(self.entries.count)")
        }
    }

    /// Analyze word frequency across all entries
    /// Returns a dictionary mapping words to their occurrence counts
    func analyzeWordFrequency(completion: @escaping ([String: Int]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }

            var frequencyMap: [String: Int] = [:]

            for entry in self.entries {
                let words = self.tokenizeText(entry.text)
                for word in words {
                    let normalized = word.lowercased()
                    frequencyMap[normalized, default: 0] += 1
                }
            }

            NSLog("[RecordingHistory] Analyzed \(self.entries.count) entries, found \(frequencyMap.count) unique words")

            DispatchQueue.main.async {
                completion(frequencyMap)
            }
        }
    }

    /// Clear all entries
    func clearHistory() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.entries.removeAll()
            self.saveEntries()

            DispatchQueue.main.async {
                self.onEntriesChanged?()
            }

            NSLog("[RecordingHistory] History cleared")
        }
    }

    // MARK: - Private Methods

    private func tokenizeText(_ text: String) -> [String] {
        // Split on whitespace and punctuation
        let components = text.components(separatedBy: .whitespacesAndNewlines)

        return components.compactMap { component in
            let cleaned = component.trimmingCharacters(in: .punctuationCharacters)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    private func loadEntries() {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                NSLog("[RecordingHistory] No existing history file")
                return
            }

            do {
                let data = try Data(contentsOf: self.fileURL)
                let decoder = JSONDecoder()
                self.entries = try decoder.decode([RecordingEntry].self, from: data)
                NSLog("[RecordingHistory] Loaded \(self.entries.count) entries")
            } catch {
                NSLog("[RecordingHistory] Failed to load history: \(error)")
            }
        }
    }

    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
            NSLog("[RecordingHistory] Saved \(entries.count) entries")
        } catch {
            NSLog("[RecordingHistory] Failed to save history: \(error)")
        }
    }
}
