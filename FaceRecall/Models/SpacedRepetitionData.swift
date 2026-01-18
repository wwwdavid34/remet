import Foundation
import SwiftData

/// Spaced repetition learning data for a person (SM-2 algorithm)
@Model
final class SpacedRepetitionData {
    var id: UUID = UUID()

    @Relationship(inverse: \Person.spacedRepetitionData)
    var person: Person?

    // SM-2 Algorithm fields
    /// Ease factor - affects interval growth (default 2.5, min 1.3)
    var easeFactor: Double = 2.5

    /// Days until next review
    var interval: Int = 0

    /// Consecutive correct answers
    var repetitions: Int = 0

    /// When the next review is due
    var nextReviewDate: Date = Date()

    /// When the last review occurred
    var lastReviewDate: Date?

    // Statistics
    var totalAttempts: Int = 0
    var correctAttempts: Int = 0

    /// Accuracy percentage (0.0 - 1.0)
    var accuracy: Double {
        totalAttempts > 0 ? Double(correctAttempts) / Double(totalAttempts) : 0
    }

    /// Whether this person needs review (due date passed)
    var needsReview: Bool {
        nextReviewDate <= Date()
    }

    /// Days until next review (negative if overdue)
    var daysUntilReview: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextReviewDate).day ?? 0
    }

    init(
        id: UUID = UUID(),
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewDate: Date? = nil,
        totalAttempts: Int = 0,
        correctAttempts: Int = 0
    ) {
        self.id = id
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.totalAttempts = totalAttempts
        self.correctAttempts = correctAttempts
    }
}
