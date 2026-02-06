import Foundation

/// 规则来源
enum RuleSource: String, Codable {
    case user = "user"                      // 用户手动创建
    case preset = "preset"                  // 预设规则（从场景默认词典导入）
    case manualCorrection = "manualCorrection"  // 手动纠正学习
}

/// Represents a text replacement rule with trigger and replacement text
struct ReplacementRule: Codable, Identifiable, Hashable {
    /// Unique identifier for the rule
    let id: UUID

    /// The trigger text to match
    var trigger: String

    /// The replacement text to insert (supports multiline)
    var replacement: String

    /// Whether this rule is enabled
    var isEnabled: Bool

    /// Whether matching should be case-sensitive (default: false for backward compatibility)
    var caseSensitive: Bool

    /// Applicable scenes (empty array means global/all scenes)
    var applicableScenes: [SceneType]

    /// Source of the rule
    var source: RuleSource

    /// Preset ID for deduplication (format: "sceneType:term")
    var presetID: String?

    /// Creates a new replacement rule
    init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        isEnabled: Bool = true,
        caseSensitive: Bool = false,
        applicableScenes: [SceneType] = [],
        source: RuleSource = .user,
        presetID: String? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.caseSensitive = caseSensitive
        self.applicableScenes = applicableScenes
        self.source = source
        self.presetID = presetID
    }

    // MARK: - Codable with backward compatibility

    enum CodingKeys: String, CodingKey {
        case id, trigger, replacement, isEnabled
        case caseSensitive, applicableScenes, source, presetID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        trigger = try container.decode(String.self, forKey: .trigger)
        replacement = try container.decode(String.self, forKey: .replacement)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        // New fields with defaults for backward compatibility
        caseSensitive = try container.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false
        applicableScenes = try container.decodeIfPresent([SceneType].self, forKey: .applicableScenes) ?? []
        source = try container.decodeIfPresent(RuleSource.self, forKey: .source) ?? .user
        presetID = try container.decodeIfPresent(String.self, forKey: .presetID)
    }

    // Hashable conformance (automatic synthesis)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReplacementRule, rhs: ReplacementRule) -> Bool {
        return lhs.id == rhs.id
    }
}
