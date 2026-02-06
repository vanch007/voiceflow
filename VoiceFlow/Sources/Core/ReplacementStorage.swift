import Foundation
import Combine

/// Manages persistence of replacement rules to disk using JSON storage
final class ReplacementStorage: ObservableObject {
    private let fileURL: URL
    @Published private(set) var rules: [ReplacementRule] = []

    /// Version key for tracking preset imports
    private static let presetImportedKey = "replacement.presetImported.v1"

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

    /// Get rules filtered by scene type
    /// - Parameter scene: The scene type to filter by (nil returns all enabled rules)
    /// - Returns: Enabled rules applicable to the scene (global rules + scene-specific rules)
    func getRules(for scene: SceneType?) -> [ReplacementRule] {
        return rules.filter { rule in
            guard rule.isEnabled else { return false }
            if let scene = scene {
                // Include if rule is global (empty applicableScenes) or matches the scene
                return rule.applicableScenes.isEmpty || rule.applicableScenes.contains(scene)
            }
            return true
        }
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
    func addRule(from: String, to: String, source: RuleSource = .user, scene: SceneType? = nil) {
        let fromNormalized = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let toNormalized = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fromNormalized.isEmpty && !toNormalized.isEmpty else { return }

        if let existingIndex = rules.firstIndex(where: { $0.trigger.lowercased() == fromNormalized.lowercased() }) {
            // Update existing rule
            rules[existingIndex].replacement = toNormalized
            save()
            NSLog("[ReplacementStorage] Updated rule: '\(fromNormalized)' → '\(toNormalized)'")
        } else {
            let applicableScenes: [SceneType] = scene != nil ? [scene!] : []
            let newRule = ReplacementRule(
                trigger: fromNormalized,
                replacement: toNormalized,
                applicableScenes: applicableScenes,
                source: source
            )
            add(newRule)
            NSLog("[ReplacementStorage] Added rule via addRule: '\(fromNormalized)' → '\(toNormalized)'")
        }
    }

    /// Apply replacement rules to text (scene-aware)
    func applyReplacements(to text: String, scene: SceneType? = nil) -> String {
        let applicableRules = getRules(for: scene)
        var result = text

        for rule in applicableRules {
            let options: String.CompareOptions = rule.caseSensitive
                ? [.literal]
                : [.caseInsensitive, .literal]
            result = result.replacingOccurrences(of: rule.trigger, with: rule.replacement, options: options)
        }
        return result
    }

    // MARK: - Preset Import

    /// Import default glossaries from SceneProfile if not already imported
    func importDefaultGlossariesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.presetImportedKey) else {
            NSLog("[ReplacementStorage] Preset glossaries already imported, skipping")
            return
        }

        NSLog("[ReplacementStorage] Importing default glossaries from SceneProfile...")
        var importCount = 0

        for (sceneType, entries) in SceneProfile.defaultGlossaries {
            for entry in entries {
                let presetID = "\(sceneType.rawValue):\(entry.term)"

                // Skip if already exists
                if rules.contains(where: { $0.presetID == presetID }) {
                    continue
                }

                let rule = ReplacementRule(
                    trigger: entry.term,
                    replacement: entry.replacement,
                    caseSensitive: entry.caseSensitive,
                    applicableScenes: [sceneType],
                    source: .preset,
                    presetID: presetID
                )
                rules.append(rule)
                importCount += 1
            }
        }

        if importCount > 0 {
            save()
            NSLog("[ReplacementStorage] Imported \(importCount) preset glossary entries")
        }

        UserDefaults.standard.set(true, forKey: Self.presetImportedKey)
    }

    /// Migrate existing glossaries from SceneManager (one-time migration)
    /// Note: This is now a no-op since glossary field has been removed from SceneProfile.
    /// Kept for backward compatibility with the migration flag.
    func migrateExistingGlossaries(from sceneManager: SceneManager) {
        let migrationKey = "replacement.glossaryMigrated.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Mark migration as complete - glossary field no longer exists in SceneProfile
        // Any existing glossary data would have been lost when SceneProfile was updated
        NSLog("[ReplacementStorage] Glossary migration marked complete (field removed from SceneProfile)")
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Scene-specific helpers

    /// Get rules for a specific scene (including global rules)
    func getSceneRules(for scene: SceneType) -> [ReplacementRule] {
        return rules.filter { rule in
            rule.applicableScenes.isEmpty || rule.applicableScenes.contains(scene)
        }
    }

    /// Add a rule for a specific scene
    func addSceneRule(trigger: String, replacement: String, scene: SceneType, caseSensitive: Bool = false) {
        let rule = ReplacementRule(
            trigger: trigger,
            replacement: replacement,
            caseSensitive: caseSensitive,
            applicableScenes: [scene],
            source: .user
        )
        add(rule)
    }

    // MARK: - Import/Export

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
