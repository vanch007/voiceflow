import Foundation

/// Represents a text replacement rule with trigger and replacement text
struct ReplacementRule: Codable, Identifiable, Hashable {
    /// Unique identifier for the rule
    let id: UUID

    /// The trigger text to match (case-insensitive matching)
    var trigger: String

    /// The replacement text to insert (supports multiline)
    var replacement: String

    /// Whether this rule is enabled
    var isEnabled: Bool

    /// Creates a new replacement rule
    init(id: UUID = UUID(), trigger: String, replacement: String, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
    }

    // Hashable conformance (automatic synthesis)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReplacementRule, rhs: ReplacementRule) -> Bool {
        return lhs.id == rhs.id
    }
}
