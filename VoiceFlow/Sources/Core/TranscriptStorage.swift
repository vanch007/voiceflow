import Foundation
import Combine

/// A single transcript entry with timestamp and metadata
struct TranscriptEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval?
    let appName: String?

    init(id: UUID = UUID(), text: String, timestamp: Date, duration: TimeInterval? = nil, appName: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.appName = appName
    }
}

/// Daily transcript file containing all entries for a single day
private struct DailyTranscripts: Codable {
    let date: String
    var entries: [TranscriptEntry]
}

/// Manages persistence of transcript entries to disk using JSON storage
/// Storage path: ~/Library/Application Support/VoiceFlow/Transcripts/
/// File format: YYYY-MM-DD.json
final class TranscriptStorage: ObservableObject {
    static let shared = TranscriptStorage()

    private let transcriptsDirectory: URL
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    @Published private(set) var todayEntries: [TranscriptEntry] = []

    private init() {
        // Setup date formatter for file names (YYYY-MM-DD)
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Setup time formatter for SRT export (HH:mm:ss,SSS)
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss,SSS"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Get Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)
        self.transcriptsDirectory = appDirectory.appendingPathComponent("Transcripts", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: transcriptsDirectory.path) {
            do {
                try fileManager.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
                NSLog("[TranscriptStorage] Created transcripts directory: \(transcriptsDirectory.path)")
            } catch {
                NSLog("[TranscriptStorage] ERROR: Failed to create directory: \(error.localizedDescription)")
            }
        }

        NSLog("[TranscriptStorage] Storage location: \(transcriptsDirectory.path)")

        // Load today's entries
        todayEntries = loadTranscripts(date: Date())
    }

    // MARK: - Public API

    /// Save a transcript entry
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - timestamp: When the transcript was created
    ///   - duration: Optional duration of the recording in seconds
    ///   - appName: Optional name of the active application
    func saveTranscript(text: String, timestamp: Date, duration: TimeInterval? = nil, appName: String? = nil) {
        let entry = TranscriptEntry(
            text: text,
            timestamp: timestamp,
            duration: duration,
            appName: appName
        )

        let dateString = dateFormatter.string(from: timestamp)
        var daily = loadDailyTranscripts(dateString: dateString)
        daily.entries.append(entry)
        saveDailyTranscripts(daily, dateString: dateString)

        // Update today's entries if applicable
        if dateFormatter.string(from: Date()) == dateString {
            todayEntries = daily.entries
        }

        NSLog("[TranscriptStorage] Saved transcript: \(text.prefix(50))...")
    }

    /// Load all transcripts for a specific date
    /// - Parameter date: The date to load transcripts for
    /// - Returns: Array of transcript entries for that date
    func loadTranscripts(date: Date) -> [TranscriptEntry] {
        let dateString = dateFormatter.string(from: date)
        return loadDailyTranscripts(dateString: dateString).entries
    }

    /// Export transcripts for a date to SRT subtitle format
    /// - Parameter date: The date to export
    /// - Returns: URL of the exported SRT file, or nil if export failed
    func exportToSRT(date: Date) -> URL? {
        let entries = loadTranscripts(date: date)
        guard !entries.isEmpty else {
            NSLog("[TranscriptStorage] No entries to export for date: \(dateFormatter.string(from: date))")
            return nil
        }

        let dateString = dateFormatter.string(from: date)
        let srtContent = generateSRTContent(entries: entries)

        let exportURL = transcriptsDirectory.appendingPathComponent("\(dateString).srt")

        do {
            try srtContent.write(to: exportURL, atomically: true, encoding: .utf8)
            NSLog("[TranscriptStorage] Exported SRT to: \(exportURL.path)")
            return exportURL
        } catch {
            NSLog("[TranscriptStorage] ERROR: Failed to export SRT: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get all available transcript dates
    /// - Returns: Array of dates that have transcripts, sorted descending
    func getAvailableDates() -> [Date] {
        do {
            let files = try fileManager.contentsOfDirectory(at: transcriptsDirectory, includingPropertiesForKeys: nil)
            let dates = files.compactMap { url -> Date? in
                guard url.pathExtension == "json" else { return nil }
                let dateString = url.deletingPathExtension().lastPathComponent
                return dateFormatter.date(from: dateString)
            }
            return dates.sorted(by: >)
        } catch {
            NSLog("[TranscriptStorage] ERROR: Failed to list transcript files: \(error.localizedDescription)")
            return []
        }
    }

    /// Delete transcripts for a specific date
    /// - Parameter date: The date to delete transcripts for
    func deleteTranscripts(date: Date) {
        let dateString = dateFormatter.string(from: date)
        let fileURL = transcriptsDirectory.appendingPathComponent("\(dateString).json")

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                NSLog("[TranscriptStorage] Deleted transcripts for: \(dateString)")

                // Update today's entries if applicable
                if dateFormatter.string(from: Date()) == dateString {
                    todayEntries = []
                }
            }
        } catch {
            NSLog("[TranscriptStorage] ERROR: Failed to delete transcripts: \(error.localizedDescription)")
        }
    }

    /// Get total transcript count for a date
    /// - Parameter date: The date to count
    /// - Returns: Number of transcripts for that date
    func getTranscriptCount(date: Date) -> Int {
        return loadTranscripts(date: date).count
    }

    // MARK: - Private Methods

    private func fileURL(for dateString: String) -> URL {
        return transcriptsDirectory.appendingPathComponent("\(dateString).json")
    }

    private func loadDailyTranscripts(dateString: String) -> DailyTranscripts {
        let url = fileURL(for: dateString)

        guard fileManager.fileExists(atPath: url.path) else {
            return DailyTranscripts(date: dateString, entries: [])
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let daily = try decoder.decode(DailyTranscripts.self, from: data)
            NSLog("[TranscriptStorage] Loaded \(daily.entries.count) entries for \(dateString)")
            return daily
        } catch {
            NSLog("[TranscriptStorage] ERROR: Failed to load transcripts for \(dateString): \(error.localizedDescription)")
            return DailyTranscripts(date: dateString, entries: [])
        }
    }

    private func saveDailyTranscripts(_ daily: DailyTranscripts, dateString: String) {
        let url = fileURL(for: dateString)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(daily)
            try data.write(to: url, options: .atomic)
            NSLog("[TranscriptStorage] Saved \(daily.entries.count) entries for \(dateString)")
        } catch {
            NSLog("[TranscriptStorage] ERROR: Failed to save transcripts for \(dateString): \(error.localizedDescription)")
        }
    }

    /// Generate SRT subtitle content from transcript entries
    private func generateSRTContent(entries: [TranscriptEntry]) -> String {
        var srtLines: [String] = []
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }

        for (index, entry) in sortedEntries.enumerated() {
            let sequenceNumber = index + 1

            // Calculate start and end times
            let startTime = formatSRTTime(entry.timestamp)
            let endTime: String
            if let duration = entry.duration, duration > 0 {
                let endDate = entry.timestamp.addingTimeInterval(duration)
                endTime = formatSRTTime(endDate)
            } else {
                // Default duration of 3 seconds if not specified
                let endDate = entry.timestamp.addingTimeInterval(3.0)
                endTime = formatSRTTime(endDate)
            }

            // SRT format: sequence number, timecodes, text, blank line
            srtLines.append("\(sequenceNumber)")
            srtLines.append("\(startTime) --> \(endTime)")
            srtLines.append(entry.text)
            srtLines.append("")
        }

        return srtLines.joined(separator: "\n")
    }

    /// Format a date as SRT timecode (HH:mm:ss,SSS)
    private func formatSRTTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
}
