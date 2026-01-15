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

    @Relationship(deleteRule: .cascade, inverse: \FaceEmbedding.person)
    var embeddings: [FaceEmbedding] = []

    @Relationship(deleteRule: .nullify, inverse: \Encounter.people)
    var encounters: [Encounter] = []

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []

    var encounterCount: Int {
        encounters.count
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
