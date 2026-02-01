import Foundation

/// Text replacement engine that applies rules to transcribed text
final class TextReplacementEngine {
    private let storage: ReplacementStorage

    init(storage: ReplacementStorage) {
        self.storage = storage
        NSLog("[TextReplacementEngine] Initialized")
    }

    /// Apply replacement rules to input text
    /// - Parameter text: The original transcribed text
    /// - Returns: Text with replacements applied
    func applyReplacements(to text: String) -> String {
        let rules = storage.getAll().filter { $0.isEnabled }

        guard !rules.isEmpty else {
            NSLog("[TextReplacementEngine] No enabled rules, returning original text")
            return text
        }

        var result = text

        // Apply each enabled rule
        for rule in rules {
            // Case-insensitive matching
            let range = result.range(
                of: rule.trigger,
                options: [.caseInsensitive, .literal]
            )

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
