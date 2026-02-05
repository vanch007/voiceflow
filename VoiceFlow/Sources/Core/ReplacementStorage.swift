import Foundation

/// Manages text replacement rules for auto-correction
final class ReplacementStorage {
    var onReplacementChanged: (([ReplacementRule]) -> Void)?

    private(set) var rules: [ReplacementRule] = []

    private let queue = DispatchQueue(label: "com.voiceflow.replacementstorage")
    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent("replacement-rules.json")

        loadRules()
    }

    // MARK: - Public API

    /// Add a replacement rule
    func addRule(from: String, to: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let fromNormalized = from.trimmingCharacters(in: .whitespacesAndNewlines)
            let toNormalized = to.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !fromNormalized.isEmpty && !toNormalized.isEmpty else { return }

            // Check if rule already exists
            if let existingIndex = self.rules.firstIndex(where: { $0.from.lowercased() == fromNormalized.lowercased() }) {
                // Update existing rule
                var updatedRule = self.rules[existingIndex]
                updatedRule.to = toNormalized
                updatedRule.count += 1
                self.rules[existingIndex] = updatedRule
                NSLog("[ReplacementStorage] Updated rule: '\(fromNormalized)' → '\(toNormalized)' (count: \(updatedRule.count))")
            } else {
                // Create new rule
                let newRule = ReplacementRule(from: fromNormalized, to: toNormalized)
                self.rules.append(newRule)
                NSLog("[ReplacementStorage] Added rule: '\(fromNormalized)' → '\(toNormalized)'")
            }

            self.saveRules()
            self.notifyChange()
        }
    }

    /// Remove a replacement rule
    func removeRule(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            guard let index = self.rules.firstIndex(where: { $0.id == id }) else {
                NSLog("[ReplacementStorage] Rule not found: \(id)")
                return
            }

            let removedRule = self.rules[index]
            self.rules.remove(at: index)
            self.saveRules()
            self.notifyChange()

            NSLog("[ReplacementStorage] Removed rule: '\(removedRule.from)' → '\(removedRule.to)'")
        }
    }

    /// Get all replacement rules
    func getRules() -> [ReplacementRule] {
        var result: [ReplacementRule] = []
        queue.sync {
            result = rules
        }
        return result
    }

    /// Apply replacement rules to text
    func applyReplacements(to text: String) -> String {
        var result = text
        queue.sync {
            for rule in rules {
                result = result.replacingOccurrences(of: rule.from, with: rule.to, options: .caseInsensitive)
            }
        }
        return result
    }

    /// Export rules as JSON data
    func exportRules() -> Data? {
        var result: Data?
        queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            result = try? encoder.encode(rules)
            NSLog("[ReplacementStorage] Exported \(rules.count) replacement rules")
        }
        return result
    }

    /// Import rules from JSON data
    func importRules(from data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let decoder = JSONDecoder()
                let importedRules = try decoder.decode([ReplacementRule].self, from: data)

                // Merge without duplicates (case-insensitive comparison on 'from' field)
                let existingFromLower = Set(self.rules.map { $0.from.lowercased() })
                let newRules = importedRules.filter { !existingFromLower.contains($0.from.lowercased()) }

                self.rules.append(contentsOf: newRules)
                self.saveRules()

                NSLog("[ReplacementStorage] Imported \(newRules.count) new rules (skipped \(importedRules.count - newRules.count) duplicates)")

                self.notifyChange()
            } catch {
                NSLog("[ReplacementStorage] Import failed: \(error)")
            }
        }
    }

    /// Clear all replacement rules
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.rules.removeAll()
            self.saveRules()
            self.notifyChange()

            NSLog("[ReplacementStorage] Cleared all replacement rules")
        }
    }

    // MARK: - Private Methods

    private func notifyChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let rulesCopy = self.rules
            self.onReplacementChanged?(rulesCopy)
        }
    }

    private func loadRules() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                do {
                    let data = try Data(contentsOf: self.fileURL)
                    let decoder = JSONDecoder()
                    self.rules = try decoder.decode([ReplacementRule].self, from: data)
                    NSLog("[ReplacementStorage] Loaded \(self.rules.count) replacement rules")
                } catch {
                    NSLog("[ReplacementStorage] Failed to load rules: \(error)")
                }
            } else {
                NSLog("[ReplacementStorage] No existing rules file")
            }
        }
    }

    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            try data.write(to: fileURL, options: .atomic)
            NSLog("[ReplacementStorage] Saved \(rules.count) replacement rules")
        } catch {
            NSLog("[ReplacementStorage] Failed to save rules: \(error)")
        }
    }
}

// MARK: - Data Model

/// Represents a text replacement rule
struct ReplacementRule: Codable, Identifiable {
    let id: UUID
    let from: String
    var to: String
    var count: Int
    let timestamp: Date

    init(from: String, to: String, count: Int = 1) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.count = count
        self.timestamp = Date()
    }
}
