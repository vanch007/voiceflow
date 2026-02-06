import Foundation

/// Text replacement engine that applies rules to transcribed text
final class TextReplacementEngine {
    private let storage: ReplacementStorage

    init(storage: ReplacementStorage) {
        self.storage = storage
        NSLog("[TextReplacementEngine] Initialized")
    }

    /// Apply replacement rules to input text (scene-aware)
    /// - Parameters:
    ///   - text: The original transcribed text
    ///   - scene: Optional scene type for filtering rules
    /// - Returns: Text with replacements applied
    func applyReplacements(to text: String, scene: SceneType? = nil) -> String {
        let rules = storage.getRules(for: scene)

        guard !rules.isEmpty else {
            NSLog("[TextReplacementEngine] No enabled rules for scene: \(scene?.rawValue ?? "all"), returning original text")
            return text
        }

        var result = text

        // Apply each enabled rule
        for rule in rules {
            let options: String.CompareOptions = rule.caseSensitive
                ? [.literal]
                : [.caseInsensitive, .literal]

            let range = result.range(of: rule.trigger, options: options)

            if let matchRange = range {
                result.replaceSubrange(matchRange, with: rule.replacement)
                NSLog("[TextReplacementEngine] Applied rule: '\(rule.trigger)' → '\(rule.replacement.prefix(30))'")
            }
        }

        if result != text {
            NSLog("[TextReplacementEngine] Text transformed: '\(text.prefix(30))' → '\(result.prefix(30))'")
        }

        return result
    }
}
