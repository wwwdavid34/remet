import Foundation
import SwiftData

/// A single quiz attempt for a person
@Model
final class QuizAttempt {
    var id: UUID

    @Relationship(inverse: \Person.quizAttempts)
    var person: Person?

    /// Whether the user correctly identified the person
    var wasCorrect: Bool

    /// Response time in milliseconds (optional)
    var responseTimeMs: Int?

    /// When the attempt occurred
    var attemptedAt: Date

    /// The user's guess (for incorrect attempts)
    var userGuess: String?

    init(
        id: UUID = UUID(),
        wasCorrect: Bool,
        responseTimeMs: Int? = nil,
        attemptedAt: Date = Date(),
        userGuess: String? = nil
    ) {
        self.id = id
        self.wasCorrect = wasCorrect
        self.responseTimeMs = responseTimeMs
        self.attemptedAt = attemptedAt
        self.userGuess = userGuess
    }
}
