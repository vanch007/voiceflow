import Foundation
import Combine

/// Manages persistence of replacement rules to disk using JSON storage
final class ReplacementStorage: ObservableObject {
    private let fileURL: URL
    @Published private(set) var rules: [ReplacementRule] = []

    init() {
        // Get Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                NSLog("[ReplacementStorage] Created app directory: \(appDirectory.path)")
            } catch {
                NSLog("[ReplacementStorage] ERROR: Failed to create directory: \(error.localizedDescription)")
            }
        }

        self.fileURL = appDirectory.appendingPathComponent("replacement-rules.json")
        NSLog("[ReplacementStorage] Storage location: \(fileURL.path)")

        // Load existing rules
        self.rules = load()
    }

    // MARK: - Public API

    /// Get all replacement rules
    func getAll() -> [ReplacementRule] {
        return rules
    }

    /// Add a new replacement rule
    func add(_ rule: ReplacementRule) {
        rules.append(rule)
        save()
        NSLog("[ReplacementStorage] Added rule: \(rule.trigger) → \(rule.replacement.prefix(20))")
    }

    /// Update an existing replacement rule
    func update(_ rule: ReplacementRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            NSLog("[ReplacementStorage] WARNING: Rule not found for update: \(rule.id.uuidString)")
            return
        }
        rules[index] = rule
        save()
        NSLog("[ReplacementStorage] Updated rule: \(rule.trigger) → \(rule.replacement.prefix(20))")
    }

    /// Delete a replacement rule by ID
    func delete(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            NSLog("[ReplacementStorage] WARNING: Rule not found for deletion: \(id.uuidString)")
            return
        }
        let deletedRule = rules.remove(at: index)
        save()
        NSLog("[ReplacementStorage] Deleted rule: \(deletedRule.trigger)")
    }


    /// Convenience method: add or update a replacement rule by from/to strings
    func addRule(from: String, to: String) {
        let fromNormalized = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let toNormalized = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fromNormalized.isEmpty && !toNormalized.isEmpty else { return }

        if let existingIndex = rules.firstIndex(where: { $0.trigger.lowercased() == fromNormalized.lowercased() }) {
            // Update existing rule
            rules[existingIndex].replacement = toNormalized
            save()
            NSLog("[ReplacementStorage] Updated rule: '\(fromNormalized)' → '\(toNormalized)'")
        } else {
            let newRule = ReplacementRule(trigger: fromNormalized, replacement: toNormalized)
            add(newRule)
            NSLog("[ReplacementStorage] Added rule via addRule: '\(fromNormalized)' → '\(toNormalized)'")
        }
    }

    /// Apply replacement rules to text
    func applyReplacements(to text: String) -> String {
        var result = text
        for rule in rules where rule.isEnabled {
            result = result.replacingOccurrences(of: rule.trigger, with: rule.replacement, options: .caseInsensitive)
        }
        return result
    }


    /// Import rules from JSON data (replaces all existing rules)
    func importRules(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            let importedRules = try decoder.decode([ReplacementRule].self, from: data)
            self.rules = importedRules
            save()
            NSLog("[ReplacementStorage] Imported \(importedRules.count) rules")
            return true
        } catch {
            NSLog("[ReplacementStorage] ERROR: Failed to import rules: \(error.localizedDescription)")
            return false
        }
    }

    /// Export all rules as JSON data
    func exportRules() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            NSLog("[ReplacementStorage] Exported \(rules.count) rules")
            return data
        } catch {
            NSLog("[ReplacementStorage] ERROR: Failed to export rules: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Methods

    /// Load rules from disk
    private func load() -> [ReplacementRule] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("[ReplacementStorage] No existing rules file, starting fresh")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let loadedRules = try decoder.decode([ReplacementRule].self, from: data)
            NSLog("[ReplacementStorage] Loaded \(loadedRules.count) rules from disk")
            return loadedRules
        } catch {
            NSLog("[ReplacementStorage] ERROR: Failed to load rules: \(error.localizedDescription)")
            return []
        }
    }

    /// Save current rules to disk
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            try data.write(to: fileURL, options: .atomic)
            NSLog("[ReplacementStorage] Saved \(rules.count) rules to disk")
        } catch {
            NSLog("[ReplacementStorage] ERROR: Failed to save rules: \(error.localizedDescription)")
        }
    }
}
