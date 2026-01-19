import Foundation

/// Constants for subscription tier limits
enum SubscriptionLimits {
    // MARK: - Free Tier Limits

    /// Maximum number of people in free tier
    static let freePeopleLimit = 25

    /// Maximum number of tags in free tier
    static let freeTagsLimit = 5

    /// Maximum encounters per person in free tier (not currently enforced)
    static let freeEncountersPerPersonLimit = 10

    /// Maximum face embeddings per person in free tier (not currently enforced)
    static let freeFaceEmbeddingsPerPersonLimit = 5

    // MARK: - Premium Limits (Unlimited)

    static let premiumPeopleLimit = Int.max
    static let premiumTagsLimit = Int.max
    static let premiumEncountersLimit = Int.max
    static let premiumEmbeddingsLimit = Int.max

    // MARK: - Grace Period

    /// Number of days existing users get unlimited access before limits apply
    static let existingUserGracePeriodDays = 30

    // MARK: - Warning Thresholds

    /// Show warning banner when reaching this percentage of limit (80%)
    static let softLimitWarningThreshold = 0.8

    // MARK: - Helpers

    /// Number of people at which to show warning (80% of limit)
    static var peopleWarningThreshold: Int {
        Int(Double(freePeopleLimit) * softLimitWarningThreshold)
    }

    /// Number of tags at which to show warning
    static var tagsWarningThreshold: Int {
        Int(Double(freeTagsLimit) * softLimitWarningThreshold)
    }
}
