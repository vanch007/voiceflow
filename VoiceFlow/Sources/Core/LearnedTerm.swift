import Foundation

/// Represents a term learned from transcription history or manual corrections
struct LearnedTerm: Codable, Identifiable {
    let id: UUID
    let term: String
    let frequency: Int
    let source: LearnSource
    let timestamp: Date
    var isApproved: Bool

    init(id: UUID = UUID(), term: String, frequency: Int, source: LearnSource, timestamp: Date = Date(), isApproved: Bool = false) {
        self.id = id
        self.term = term
        self.frequency = frequency
        self.source = source
        self.timestamp = timestamp
        self.isApproved = isApproved
    }
}

/// The source of a learned term
enum LearnSource: String, Codable {
    case autoLearned = "auto"
    case manualCorrection = "correction"
}
