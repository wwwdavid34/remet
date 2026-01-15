import Foundation
import SwiftData

/// Category for interaction notes
enum InteractionCategory: String, Codable, CaseIterable, Identifiable {
    case conversation = "Conversation"
    case interest = "Interest"
    case reminder = "Remember This"
    case followUp = "Follow Up"
    case milestone = "Milestone"
    case general = "General"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right"
        case .interest: return "star"
        case .reminder: return "lightbulb"
        case .followUp: return "arrow.uturn.forward"
        case .milestone: return "flag"
        case .general: return "note.text"
        }
    }
}

/// A note about an interaction or observation about a person
@Model
final class InteractionNote {
    var id: UUID
    var content: String
    var categoryRaw: String
    var createdAt: Date

    @Relationship(inverse: \Person.interactionNotes)
    var person: Person?

    var encounterId: UUID?

    var category: InteractionCategory {
        get { InteractionCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        content: String,
        category: InteractionCategory = .general,
        createdAt: Date = Date(),
        encounterId: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
        self.encounterId = encounterId
    }
}
