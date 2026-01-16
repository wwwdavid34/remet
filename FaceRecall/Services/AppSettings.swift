import Foundation
import SwiftUI

/// Photo storage quality presets
enum PhotoStorageQuality: String, CaseIterable, Identifiable {
    case high = "High Quality"
    case balanced = "Balanced"
    case compact = "Compact"

    var id: String { rawValue }

    var resolution: CGFloat {
        switch self {
        case .high: return 1024
        case .balanced: return 768
        case .compact: return 512
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .high: return 0.8
        case .balanced: return 0.6
        case .compact: return 0.5
        }
    }

    var description: String {
        switch self {
        case .high:
            return "Best quality, largest storage (~200 KB/photo)"
        case .balanced:
            return "Good quality, moderate storage (~80 KB/photo)"
        case .compact:
            return "Acceptable quality, smallest storage (~40 KB/photo)"
        }
    }

    var estimatedSizePerPhoto: Int {
        switch self {
        case .high: return 200
        case .balanced: return 80
        case .compact: return 40
        }
    }
}

/// Centralized app settings using UserDefaults
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let photoStorageQuality = "photoStorageQuality"
        static let autoAcceptThreshold = "autoAcceptThreshold"
        static let showConfidenceScores = "showConfidenceScores"
        static let firstLaunchDate = "firstLaunchDate"
        static let subscriptionLimitsVersion = "subscriptionLimitsVersion"
    }

    var photoStorageQuality: PhotoStorageQuality {
        get {
            if let rawValue = defaults.string(forKey: Keys.photoStorageQuality),
               let quality = PhotoStorageQuality(rawValue: rawValue) {
                return quality
            }
            return .balanced
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.photoStorageQuality)
        }
    }

    var autoAcceptThreshold: Float {
        get {
            let value = defaults.float(forKey: Keys.autoAcceptThreshold)
            return value > 0 ? value : 0.90
        }
        set {
            defaults.set(newValue, forKey: Keys.autoAcceptThreshold)
        }
    }

    var showConfidenceScores: Bool {
        get {
            defaults.bool(forKey: Keys.showConfidenceScores)
        }
        set {
            defaults.set(newValue, forKey: Keys.showConfidenceScores)
        }
    }

    // Computed properties for photo processing
    var photoResolution: CGFloat {
        photoStorageQuality.resolution
    }

    var photoJpegQuality: CGFloat {
        photoStorageQuality.jpegQuality
    }

    var photoTargetSize: CGSize {
        CGSize(width: photoResolution, height: photoResolution)
    }

    // MARK: - Subscription & Grace Period

    /// Date when the app was first launched (used for grace period)
    var firstLaunchDate: Date? {
        get {
            defaults.object(forKey: Keys.firstLaunchDate) as? Date
        }
        set {
            defaults.set(newValue, forKey: Keys.firstLaunchDate)
        }
    }

    /// Version of subscription limits (for future migrations)
    var subscriptionLimitsVersion: Int {
        get {
            defaults.integer(forKey: Keys.subscriptionLimitsVersion)
        }
        set {
            defaults.set(newValue, forKey: Keys.subscriptionLimitsVersion)
        }
    }

    /// Whether this is an existing user (had data before subscription feature)
    var isExistingUser: Bool {
        guard let firstLaunch = firstLaunchDate else { return false }
        // Subscription feature launch date - users before this are "existing"
        let subscriptionFeatureLaunchDate = Date() // Will be set to actual launch date
        return firstLaunch < subscriptionFeatureLaunchDate
    }

    /// Date when grace period expires for existing users
    var gracePeriodExpirationDate: Date? {
        guard let firstLaunch = firstLaunchDate else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: SubscriptionLimits.existingUserGracePeriodDays,
            to: firstLaunch
        )
    }

    /// Whether the user is currently in the grace period
    var isInGracePeriod: Bool {
        guard isExistingUser,
              let expiration = gracePeriodExpirationDate else {
            return false
        }
        return Date() < expiration
    }

    /// Record the first launch if not already recorded
    func recordFirstLaunchIfNeeded() {
        if firstLaunchDate == nil {
            firstLaunchDate = Date()
        }
    }

    private init() {}
}
