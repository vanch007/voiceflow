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

    // 性能指标（阶段4.1）
    var asrLatencyMs: Int?       // ASR 转录延迟（毫秒）
    var polishLatencyMs: Int?    // 润色延迟（毫秒）
    var polishMethod: String?    // 润色方法: "llm", "rules", "none"
    var characterCount: Int?     // 转录字符数

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, duration: TimeInterval, audioPath: String? = nil, appName: String? = nil, bundleID: String? = nil, asrLatencyMs: Int? = nil, polishLatencyMs: Int? = nil, polishMethod: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.duration = duration
        self.audioPath = audioPath
        self.appName = appName
        self.bundleID = bundleID
        self.asrLatencyMs = asrLatencyMs
        self.polishLatencyMs = polishLatencyMs
        self.polishMethod = polishMethod
        self.characterCount = text.count
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

    /// Get entries for a specific application name
    func entriesForApp(_ appName: String, limit: Int = 100) -> [RecordingEntry] {
        let snapshot: [RecordingEntry] = queue.sync { entries }
        let filtered = snapshot.filter { $0.appName == appName }
        return Array(filtered.prefix(limit))
    }

    /// Get entries for a specific bundle ID
    func entriesForBundleID(_ bundleID: String, limit: Int = 100) -> [RecordingEntry] {
        let snapshot: [RecordingEntry] = queue.sync { entries }
        let filtered = snapshot.filter { $0.bundleID == bundleID }
        return Array(filtered.prefix(limit))
    }

    /// Get all unique application names in history
    func uniqueAppNames() -> [String] {
        let snapshot: [RecordingEntry] = queue.sync { entries }
        let names = snapshot.compactMap { $0.appName }
        return Array(Set(names)).sorted()
    }

    // MARK: - Usage Statistics (阶段4.1)

    /// 使用统计数据结构
    struct UsageStatistics {
        let totalRecordings: Int
        let totalDurationSeconds: Double
        let totalCharacters: Int
        let averageASRLatencyMs: Double
        let averagePolishLatencyMs: Double
        let llmPolishCount: Int
        let rulesPolishCount: Int
        let noPolishCount: Int
        let topApps: [(name: String, count: Int)]
        let recordingsToday: Int
        let recordingsThisWeek: Int
    }

    /// 计算使用统计
    func calculateStatistics() -> UsageStatistics {
        let snapshot: [RecordingEntry] = queue.sync { entries }

        let totalRecordings = snapshot.count
        let totalDuration = snapshot.reduce(0.0) { $0 + $1.duration }
        let totalChars = snapshot.reduce(0) { $0 + ($1.characterCount ?? $1.text.count) }

        // 延迟统计
        let asrLatencies = snapshot.compactMap { $0.asrLatencyMs }
        let avgASR = asrLatencies.isEmpty ? 0.0 : Double(asrLatencies.reduce(0, +)) / Double(asrLatencies.count)

        let polishLatencies = snapshot.compactMap { $0.polishLatencyMs }
        let avgPolish = polishLatencies.isEmpty ? 0.0 : Double(polishLatencies.reduce(0, +)) / Double(polishLatencies.count)

        // 润色方法统计
        let llmCount = snapshot.filter { $0.polishMethod == "llm" }.count
        let rulesCount = snapshot.filter { $0.polishMethod == "rules" }.count
        let noneCount = snapshot.filter { $0.polishMethod == "none" || $0.polishMethod == nil }.count

        // 应用使用排行
        var appCounts: [String: Int] = [:]
        for entry in snapshot {
            if let appName = entry.appName {
                appCounts[appName, default: 0] += 1
            }
        }
        let topApps = appCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        // 时间范围统计
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let todayCount = snapshot.filter { $0.timestamp >= startOfToday }.count
        let weekCount = snapshot.filter { $0.timestamp >= startOfWeek }.count

        return UsageStatistics(
            totalRecordings: totalRecordings,
            totalDurationSeconds: totalDuration,
            totalCharacters: totalChars,
            averageASRLatencyMs: avgASR,
            averagePolishLatencyMs: avgPolish,
            llmPolishCount: llmCount,
            rulesPolishCount: rulesCount,
            noPolishCount: noneCount,
            topApps: topApps,
            recordingsToday: todayCount,
            recordingsThisWeek: weekCount
        )
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
