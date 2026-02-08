import Foundation
import Combine
import AppKit

/// Settings for system audio transcription and subtitle display
final class SystemAudioSettings: ObservableObject {
    static let shared = SystemAudioSettings()

    // MARK: - Keys

    private enum Keys {
        static let subtitleFontSize = "systemAudio.subtitleFontSize"
        static let subtitleBackgroundOpacity = "systemAudio.subtitleBackgroundOpacity"
        static let subtitleMaxLines = "systemAudio.subtitleMaxLines"
    }

    // MARK: - Defaults

    private enum Defaults {
        static let subtitleFontSize: Double = 20.0
        static let subtitleBackgroundOpacity: Double = 0.7
        static let subtitleMaxLines: Int = 3
    }

    // MARK: - Published Properties

    /// Subtitle font size (18-24pt)
    @Published var subtitleFontSize: Double {
        didSet {
            let clamped = max(18.0, min(24.0, subtitleFontSize))
            if clamped != subtitleFontSize {
                subtitleFontSize = clamped
            }
            UserDefaults.standard.set(clamped, forKey: Keys.subtitleFontSize)
            NSLog("[SystemAudioSettings] Subtitle font size changed to: \(clamped)")
        }
    }

    /// Subtitle background opacity (0.6-0.8)
    @Published var subtitleBackgroundOpacity: Double {
        didSet {
            let clamped = max(0.6, min(0.8, subtitleBackgroundOpacity))
            if clamped != subtitleBackgroundOpacity {
                subtitleBackgroundOpacity = clamped
            }
            UserDefaults.standard.set(clamped, forKey: Keys.subtitleBackgroundOpacity)
            NSLog("[SystemAudioSettings] Subtitle background opacity changed to: \(clamped)")
        }
    }

    /// Maximum number of subtitle lines (1-5)
    @Published var subtitleMaxLines: Int {
        didSet {
            let clamped = max(1, min(5, subtitleMaxLines))
            if clamped != subtitleMaxLines {
                subtitleMaxLines = clamped
            }
            UserDefaults.standard.set(clamped, forKey: Keys.subtitleMaxLines)
            NSLog("[SystemAudioSettings] Subtitle max lines changed to: \(clamped)")
        }
    }

    // MARK: - Computed Properties

    /// Path to transcript storage directory
    var transcriptStoragePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let transcriptsDir = appSupport
            .appendingPathComponent("VoiceFlow", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
        return transcriptsDir.path
    }

    /// URL to transcript storage directory
    var transcriptStorageURL: URL {
        return URL(fileURLWithPath: transcriptStoragePath, isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        // Load subtitle font size
        if let value = UserDefaults.standard.object(forKey: Keys.subtitleFontSize) as? Double {
            self.subtitleFontSize = max(18.0, min(24.0, value))
        } else {
            self.subtitleFontSize = Defaults.subtitleFontSize
        }

        // Load subtitle background opacity
        if let value = UserDefaults.standard.object(forKey: Keys.subtitleBackgroundOpacity) as? Double {
            self.subtitleBackgroundOpacity = max(0.6, min(0.8, value))
        } else {
            self.subtitleBackgroundOpacity = Defaults.subtitleBackgroundOpacity
        }

        // Load subtitle max lines
        if let value = UserDefaults.standard.object(forKey: Keys.subtitleMaxLines) as? Int {
            self.subtitleMaxLines = max(1, min(5, value))
        } else {
            self.subtitleMaxLines = Defaults.subtitleMaxLines
        }

        NSLog("[SystemAudioSettings] Initialized with fontSize=\(subtitleFontSize), opacity=\(subtitleBackgroundOpacity), maxLines=\(subtitleMaxLines)")
    }

    // MARK: - Actions

    /// Open the transcript storage folder in Finder
    func openTranscriptFolder() {
        let url = transcriptStorageURL

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                NSLog("[SystemAudioSettings] ERROR: Failed to create transcript directory: \(error.localizedDescription)")
                return
            }
        }

        NSWorkspace.shared.open(url)
        NSLog("[SystemAudioSettings] Opened transcript folder: \(url.path)")
    }

    /// Reset to default values
    func resetToDefaults() {
        subtitleFontSize = Defaults.subtitleFontSize
        subtitleBackgroundOpacity = Defaults.subtitleBackgroundOpacity
        subtitleMaxLines = Defaults.subtitleMaxLines
        NSLog("[SystemAudioSettings] Reset to defaults")
    }
}
