import Foundation

final class DictionaryManager {
    var onDictionaryChanged: (([String]) -> Void)?

    private var words: Set<String> = []
    private let fileManager = FileManager.default

    /// Path to Application Support directory for VoiceFlow
    private var appSupportPath: String {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = paths.first else {
            NSLog("[DictionaryManager] ERROR: Cannot access Application Support directory")
            return ""
        }
        let voiceflowDir = appSupport.appendingPathComponent("VoiceFlow")

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: voiceflowDir.path) {
            do {
                try fileManager.createDirectory(at: voiceflowDir, withIntermediateDirectories: true)
                NSLog("[DictionaryManager] Created directory: \(voiceflowDir.path)")
            } catch {
                NSLog("[DictionaryManager] ERROR: Failed to create directory: \(error)")
            }
        }

        return voiceflowDir.path
    }

    private var dictionaryFilePath: String {
        return (appSupportPath as NSString).appendingPathComponent("custom_dictionary.json")
    }

    init() {
        loadDictionary()
    }

    // MARK: - Public API

    /// Returns the current dictionary words as a sorted array
    func getWords() -> [String] {
        return Array(words).sorted()
    }

    /// Adds a new word to the dictionary
    func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            NSLog("[DictionaryManager] Cannot add empty word")
            return
        }

        let previousCount = words.count
        words.insert(trimmed)

        if words.count > previousCount {
            NSLog("[DictionaryManager] Added word: \(trimmed)")
            saveDictionary()
            notifyChange()
        } else {
            NSLog("[DictionaryManager] Word already exists: \(trimmed)")
        }
    }

    /// Removes a word from the dictionary
    func removeWord(_ word: String) {
        if words.remove(word) != nil {
            NSLog("[DictionaryManager] Removed word: \(word)")
            saveDictionary()
            notifyChange()
        } else {
            NSLog("[DictionaryManager] Word not found: \(word)")
        }
    }

    /// Removes all words from the dictionary
    func clearDictionary() {
        words.removeAll()
        NSLog("[DictionaryManager] Dictionary cleared")
        saveDictionary()
        notifyChange()
    }

    /// Exports dictionary to a specified file path
    func exportToFile(path: String) -> Bool {
        let wordsArray = getWords()

        guard let data = try? JSONSerialization.data(withJSONObject: wordsArray, options: .prettyPrinted) else {
            NSLog("[DictionaryManager] ERROR: Failed to serialize dictionary for export")
            return false
        }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            NSLog("[DictionaryManager] Exported \(wordsArray.count) words to: \(path)")
            return true
        } catch {
            NSLog("[DictionaryManager] ERROR: Failed to export dictionary: \(error)")
            return false
        }
    }

    /// Imports dictionary from a specified file path (replaces current dictionary)
    func importFromFile(path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            NSLog("[DictionaryManager] ERROR: Failed to read file: \(path)")
            return false
        }

        guard let wordsArray = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            NSLog("[DictionaryManager] ERROR: Invalid JSON format in file: \(path)")
            return false
        }

        words = Set(wordsArray.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        NSLog("[DictionaryManager] Imported \(words.count) words from: \(path)")
        saveDictionary()
        notifyChange()
        return true
    }

    // MARK: - Private Methods

    private func loadDictionary() {
        let path = dictionaryFilePath

        guard fileManager.fileExists(atPath: path) else {
            NSLog("[DictionaryManager] No existing dictionary file, starting fresh")
            return
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            NSLog("[DictionaryManager] ERROR: Failed to read dictionary file")
            return
        }

        guard let wordsArray = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            NSLog("[DictionaryManager] ERROR: Invalid dictionary file format")
            return
        }

        words = Set(wordsArray)
        NSLog("[DictionaryManager] Loaded \(words.count) words from: \(path)")
    }

    private func saveDictionary() {
        let path = dictionaryFilePath
        let wordsArray = getWords()

        guard let data = try? JSONSerialization.data(withJSONObject: wordsArray, options: .prettyPrinted) else {
            NSLog("[DictionaryManager] ERROR: Failed to serialize dictionary")
            return
        }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            NSLog("[DictionaryManager] Saved \(wordsArray.count) words to: \(path)")
        } catch {
            NSLog("[DictionaryManager] ERROR: Failed to save dictionary: \(error)")
        }
    }

    private func notifyChange() {
        let wordsArray = getWords()
        onDictionaryChanged?(wordsArray)
    }
}
