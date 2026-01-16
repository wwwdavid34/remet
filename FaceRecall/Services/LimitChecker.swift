import Foundation

/// Service for checking subscription limits at runtime
@Observable
@MainActor
final class LimitChecker {
    private let subscriptionManager: SubscriptionManager

    init(subscriptionManager: SubscriptionManager = .shared) {
        self.subscriptionManager = subscriptionManager
    }

    // MARK: - Current Limits

    /// Current people limit based on subscription status
    var peopleLimit: Int {
        subscriptionManager.isPremium
            ? SubscriptionLimits.premiumPeopleLimit
            : SubscriptionLimits.freePeopleLimit
    }

    /// Current tags limit based on subscription status
    var tagsLimit: Int {
        subscriptionManager.isPremium
            ? SubscriptionLimits.premiumTagsLimit
            : SubscriptionLimits.freeTagsLimit
    }

    // MARK: - Limit Status Checks

    /// Check if user can add another person
    func canAddPerson(currentCount: Int) -> LimitStatus {
        if subscriptionManager.isPremium {
            return .allowed
        }

        // Check grace period for existing users
        if AppSettings.shared.isInGracePeriod {
            return .allowed
        }

        let limit = SubscriptionLimits.freePeopleLimit

        if currentCount >= limit {
            return .hardLimitReached(limit: limit, current: currentCount)
        } else if currentCount >= SubscriptionLimits.peopleWarningThreshold {
            return .approachingLimit(limit: limit, current: currentCount)
        }

        return .allowed
    }

    /// Check if user can add another tag
    func canAddTag(currentCount: Int) -> LimitStatus {
        if subscriptionManager.isPremium {
            return .allowed
        }

        if AppSettings.shared.isInGracePeriod {
            return .allowed
        }

        let limit = SubscriptionLimits.freeTagsLimit

        if currentCount >= limit {
            return .hardLimitReached(limit: limit, current: currentCount)
        } else if currentCount >= SubscriptionLimits.tagsWarningThreshold {
            return .approachingLimit(limit: limit, current: currentCount)
        }

        return .allowed
    }

    /// Get the current people limit status for display
    func peopleStatus(currentCount: Int) -> LimitStatus {
        canAddPerson(currentCount: currentCount)
    }

    // MARK: - Limit Status Enum

    enum LimitStatus: Equatable {
        case allowed
        case approachingLimit(limit: Int, current: Int)
        case hardLimitReached(limit: Int, current: Int)

        /// Whether adding is blocked
        var isBlocked: Bool {
            if case .hardLimitReached = self {
                return true
            }
            return false
        }

        /// Whether a warning should be shown
        var shouldShowWarning: Bool {
            switch self {
            case .allowed:
                return false
            case .approachingLimit, .hardLimitReached:
                return true
            }
        }

        /// Remaining count before limit
        var remaining: Int? {
            switch self {
            case .allowed:
                return nil
            case .approachingLimit(let limit, let current):
                return limit - current
            case .hardLimitReached:
                return 0
            }
        }

        /// User-facing message
        var message: String? {
            switch self {
            case .allowed:
                return nil
            case .approachingLimit(let limit, let current):
                let remaining = limit - current
                return "You've added \(current) of \(limit) people. \(remaining) remaining."
            case .hardLimitReached(let limit, _):
                return "You've reached the free limit of \(limit) people."
            }
        }

        /// Short message for banners
        var shortMessage: String? {
            switch self {
            case .allowed:
                return nil
            case .approachingLimit(let limit, let current):
                return "\(current)/\(limit) people"
            case .hardLimitReached(let limit, _):
                return "\(limit)/\(limit) people (limit reached)"
            }
        }
    }
}
