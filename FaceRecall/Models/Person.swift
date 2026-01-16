import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var relationship: String?
    var contextTag: String?
    var createdAt: Date
    var lastSeenAt: Date?

    // Personal details
    var company: String?
    var jobTitle: String?
    var email: String?
    var phone: String?
    var notes: String?
    var birthday: Date?

    // Social links
    var linkedIn: String?
    var twitter: String?

    // Profile photo selection
    var profileEmbeddingId: UUID?

    // Relationship building fields
    var howWeMet: String?
    var interestsData: Data?  // JSON array of strings
    var talkingPointsData: Data?  // JSON array of strings

    @Relationship(deleteRule: .cascade, inverse: \FaceEmbedding.person)
    var embeddings: [FaceEmbedding] = []

    @Relationship(deleteRule: .nullify, inverse: \Encounter.people)
    var encounters: [Encounter] = []

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []

    // Relationship memory features
    @Relationship(deleteRule: .cascade)
    var interactionNotes: [InteractionNote] = []

    @Relationship(deleteRule: .cascade)
    var quizAttempts: [QuizAttempt] = []

    @Relationship(deleteRule: .cascade)
    var spacedRepetitionData: SpacedRepetitionData?

    var encounterCount: Int {
        encounters.count
    }

    // Computed properties for interests and talking points
    var interests: [String] {
        get {
            guard let data = interestsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            interestsData = try? JSONEncoder().encode(newValue)
        }
    }

    var talkingPoints: [String] {
        get {
            guard let data = talkingPointsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            talkingPointsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this person needs review based on spaced repetition
    var needsReview: Bool {
        spacedRepetitionData?.needsReview ?? true
    }

    /// The embedding to use for the profile photo (selected or first available)
    var profileEmbedding: FaceEmbedding? {
        if let profileId = profileEmbeddingId,
           let selected = embeddings.first(where: { $0.id == profileId }) {
            return selected
        }
        return embeddings.first
    }

    /// Recent interaction notes (last 5)
    var recentNotes: [InteractionNote] {
        interactionNotes.sorted { $0.createdAt > $1.createdAt }.prefix(5).map { $0 }
    }

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String? = nil,
        contextTag: String? = nil,
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.contextTag = contextTag
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.company = company
        self.jobTitle = jobTitle
        self.email = email
        self.phone = phone
        self.notes = notes
    }
}
