import Foundation

// Data model for a single recording entry
struct RecordingEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let text: String
    let duration: TimeInterval
    let audioPath: String?
    let appName: String?
    let bundleID: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, duration: TimeInterval, audioPath: String? = nil, appName: String? = nil, bundleID: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.duration = duration
        self.audioPath = audioPath
        self.appName = appName
        self.bundleID = bundleID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecordingEntry, rhs: RecordingEntry) -> Bool {
        lhs.id == rhs.id
    }
}

final class RecordingHistory {
    private let maxEntries = 50
    private let userDefaultsKey = "com.voiceflow.recordingHistory"
    private let audioDirectory: URL
    private let historyFileURL: URL
    private let queue = DispatchQueue(label: "com.voiceflow.recordinghistory")

    private(set) var entries: [RecordingEntry] = []

    var onEntriesChanged: (() -> Void)?

    init() {
        // Set up audio directory in Application Support
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = appSupport.appendingPathComponent("VoiceFlow/Recordings", isDirectory: true)
        historyFileURL = appSupport.appendingPathComponent("VoiceFlow/recording_history.json")

        // Create directory if needed
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        loadEntries()
    }

    // MARK: - Public Methods

    func addEntry(text: String, duration: TimeInterval, audioData: Data? = nil, appName: String? = nil, bundleID: String? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let audioPath: String?
            if let data = audioData {
                audioPath = self.saveAudioFile(data)
            } else {
                audioPath = nil
            }

            let entry = RecordingEntry(text: text, duration: duration, audioPath: audioPath, appName: appName, bundleID: bundleID)
            self.entries.insert(entry, at: 0) // newest first

            // Enforce max entries limit
            if self.entries.count > self.maxEntries {
                let removed = self.entries.removeLast()
                self.deleteAudioFile(path: removed.audioPath)
            }

            self.saveEntries()
            DispatchQueue.main.async { self.onEntriesChanged?() }
            NSLog("[RecordingHistory] Added entry: \(text.prefix(50))... (duration: \(duration)s)")
        }
    }

    func deleteEntry(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let index = self.entries.firstIndex(where: { $0.id == id }) else { return }
            let entry = self.entries.remove(at: index)
            self.deleteAudioFile(path: entry.audioPath)
            self.saveEntries()
            DispatchQueue.main.async { self.onEntriesChanged?() }
            NSLog("[RecordingHistory] Deleted entry: \(id)")
        }
    }

    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            for entry in self.entries {
                self.deleteAudioFile(path: entry.audioPath)
            }
            self.entries.removeAll()
            self.saveEntries()
            DispatchQueue.main.async { self.onEntriesChanged?() }
            NSLog("[RecordingHistory] Cleared all entries")
        }
    }

    func searchEntries(query: String) -> [RecordingEntry] {
        let snapshot: [RecordingEntry] = queue.sync { entries }
        guard !query.isEmpty else { return snapshot }
        return snapshot.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    func getAudioData(for entry: RecordingEntry) -> Data? {
        guard let path = entry.audioPath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }


    // MARK: - Word Frequency Analysis

    /// Analyze word frequency across all entries
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

    private func tokenizeText(_ text: String) -> [String] {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.compactMap { component in
            let cleaned = component.trimmingCharacters(in: .punctuationCharacters)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    // MARK: - Private Persistence

    private func saveEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            NSLog("[RecordingHistory] ERROR: Failed to write entries to file: \(error)")
        }
    }

    private func loadEntries() {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if fm.fileExists(atPath: historyFileURL.path) {
            do {
                let data = try Data(contentsOf: historyFileURL)
                entries = try decoder.decode([RecordingEntry].self, from: data)
                NSLog("[RecordingHistory] Loaded \(entries.count) entries from file")
                return
            } catch {
                NSLog("[RecordingHistory] ERROR: Failed to decode entries from file: \(error)")
            }
        }

        // Fallback: migrate from UserDefaults if present
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                entries = try decoder.decode([RecordingEntry].self, from: data)
                NSLog("[RecordingHistory] Migrated \(entries.count) entries from UserDefaults")
                saveEntries()
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            } catch {
                NSLog("[RecordingHistory] ERROR: Failed to decode entries from UserDefaults: \(error)")
            }
        } else {
            NSLog("[RecordingHistory] No saved entries found")
        }
    }

    // MARK: - Audio File Management

    private func saveAudioFile(_ data: Data) -> String? {
        let filename = "\(UUID().uuidString).wav"
        let fileURL = audioDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            NSLog("[RecordingHistory] Saved audio file: \(filename)")
            return fileURL.path
        } catch {
            NSLog("[RecordingHistory] ERROR: Failed to save audio file: \(error)")
            return nil
        }
    }

    private func deleteAudioFile(path: String?) {
        guard let path = path else { return }
        let fileURL = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: fileURL)
        NSLog("[RecordingHistory] Deleted audio file: \(path)")
    }
}
