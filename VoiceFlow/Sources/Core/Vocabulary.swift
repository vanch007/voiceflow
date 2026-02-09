import Foundation

/// Represents a vocabulary entry (hotword) with optional pronunciation and mapping
struct VocabularyEntry: Codable, Identifiable, Hashable {
    /// Unique identifier for the entry
    let id: UUID

    /// The term to recognize (e.g., "React", "Kubernetes")
    var term: String

    /// Optional pronunciation guide (e.g., "ri ˈækt", pinyin for Chinese)
    var pronunciation: String?

    /// Optional display mapping (e.g., "React框架" for contextual replacement)
    var mapping: String?

    /// Optional category for organization (e.g., "programming", "medical", "names")
    var category: String?

    /// Creates a new vocabulary entry
    init(
        id: UUID = UUID(),
        term: String,
        pronunciation: String? = nil,
        mapping: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.term = term
        self.pronunciation = pronunciation
        self.mapping = mapping
        self.category = category
    }

    // Hashable conformance (automatic synthesis based on all properties)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VocabularyEntry, rhs: VocabularyEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a custom vocabulary list for ASR hotword biasing
struct Vocabulary: Codable, Identifiable, Hashable {
    /// Unique identifier for the vocabulary
    let id: UUID

    /// Display name of the vocabulary
    var name: String

    /// Optional description of the vocabulary's purpose
    var description: String

    /// List of vocabulary entries (hotwords)
    var entries: [VocabularyEntry]

    /// Creation timestamp
    var createdAt: Date

    /// Last modified timestamp
    var updatedAt: Date

    /// Creates a new vocabulary
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        entries: [VocabularyEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable with backward compatibility

    enum CodingKeys: String, CodingKey {
        case id, name, description, entries, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        entries = try container.decodeIfPresent([VocabularyEntry].self, forKey: .entries) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Vocabulary, rhs: Vocabulary) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    /// Returns the count of entries in this vocabulary
    var entryCount: Int {
        return entries.count
    }

    /// Returns all terms as a flat array for ASR hotword biasing
    var terms: [String] {
        return entries.map { $0.term }
    }
}
