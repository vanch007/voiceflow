import Foundation

// Data model for a single recording entry
struct RecordingEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let text: String
    let duration: TimeInterval
    let audioPath: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, duration: TimeInterval, audioPath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.duration = duration
        self.audioPath = audioPath
    }
}

final class RecordingHistory {
    private let maxEntries = 50
    private let userDefaultsKey = "com.voiceflow.recordingHistory"
    private let audioDirectory: URL

    private(set) var entries: [RecordingEntry] = []

    var onEntriesChanged: (() -> Void)?

    init() {
        // Set up audio directory in Application Support
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = appSupport.appendingPathComponent("VoiceFlow/Recordings", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        loadEntries()
    }

    // MARK: - Public Methods

    func addEntry(text: String, duration: TimeInterval, audioData: Data? = nil) {
        let audioPath: String?
        if let data = audioData {
            audioPath = saveAudioFile(data)
        } else {
            audioPath = nil
        }

        let entry = RecordingEntry(text: text, duration: duration, audioPath: audioPath)
        entries.insert(entry, at: 0) // Insert at beginning (newest first)

        // Enforce max entries limit
        if entries.count > maxEntries {
            let removed = entries.removeLast()
            deleteAudioFile(path: removed.audioPath)
        }

        saveEntries()
        onEntriesChanged?()
        NSLog("[RecordingHistory] Added entry: \(text.prefix(50))... (duration: \(duration)s)")
    }

    func deleteEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        deleteAudioFile(path: entry.audioPath)
        saveEntries()
        onEntriesChanged?()
        NSLog("[RecordingHistory] Deleted entry: \(id)")
    }

    func clearAll() {
        // Delete all audio files
        for entry in entries {
            deleteAudioFile(path: entry.audioPath)
        }
        entries.removeAll()
        saveEntries()
        onEntriesChanged?()
        NSLog("[RecordingHistory] Cleared all entries")
    }

    func searchEntries(query: String) -> [RecordingEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    func getAudioData(for entry: RecordingEntry) -> Data? {
        guard let path = entry.audioPath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    // MARK: - Private Persistence

    private func saveEntries() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(entries) else {
            NSLog("[RecordingHistory] ERROR: Failed to encode entries")
            return
        }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            NSLog("[RecordingHistory] No saved entries found")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([RecordingEntry].self, from: data) else {
            NSLog("[RecordingHistory] ERROR: Failed to decode entries")
            return
        }

        entries = decoded
        NSLog("[RecordingHistory] Loaded \(entries.count) entries")
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
