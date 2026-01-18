import Foundation
import SwiftUI

/// Photo storage quality presets
enum PhotoStorageQuality: String, CaseIterable, Identifiable {
    case high = "high"
    case balanced = "balanced"
    case compact = "compact"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return String(localized: "High Quality")
        case .balanced: return String(localized: "Balanced")
        case .compact: return String(localized: "Compact")
        }
    }

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
            return String(localized: "Best quality, largest storage (~200 KB/photo)")
        case .balanced:
            return String(localized: "Good quality, moderate storage (~80 KB/photo)")
        case .compact:
            return String(localized: "Acceptable quality, smallest storage (~40 KB/photo)")
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
        static let showBoundingBoxes = "showBoundingBoxes"
        static let savePhotosToCameraRoll = "savePhotosToCameraRoll"
        static let hasShownCameraRollHint = "hasShownCameraRollHint"
        static let firstLaunchDate = "firstLaunchDate"
        static let subscriptionLimitsVersion = "subscriptionLimitsVersion"
    }

    // MARK: - Stored Properties (for @Observable tracking)

    private var _photoStorageQuality: PhotoStorageQuality = .balanced
    private var _autoAcceptThreshold: Float = 0.90
    private var _showConfidenceScores: Bool = false
    private var _showBoundingBoxes: Bool = true
    private var _savePhotosToCameraRoll: Bool = false
    private var _hasShownCameraRollHint: Bool = false

    var photoStorageQuality: PhotoStorageQuality {
        get { _photoStorageQuality }
        set {
            _photoStorageQuality = newValue
            defaults.set(newValue.rawValue, forKey: Keys.photoStorageQuality)
        }
    }

    var autoAcceptThreshold: Float {
        get { _autoAcceptThreshold }
        set {
            _autoAcceptThreshold = newValue
            defaults.set(newValue, forKey: Keys.autoAcceptThreshold)
        }
    }

    var showConfidenceScores: Bool {
        get { _showConfidenceScores }
        set {
            _showConfidenceScores = newValue
            defaults.set(newValue, forKey: Keys.showConfidenceScores)
        }
    }

    var showBoundingBoxes: Bool {
        get { _showBoundingBoxes }
        set {
            _showBoundingBoxes = newValue
            defaults.set(newValue, forKey: Keys.showBoundingBoxes)
        }
    }

    var savePhotosToCameraRoll: Bool {
        get { _savePhotosToCameraRoll }
        set {
            _savePhotosToCameraRoll = newValue
            defaults.set(newValue, forKey: Keys.savePhotosToCameraRoll)
        }
    }

    var hasShownCameraRollHint: Bool {
        get { _hasShownCameraRollHint }
        set {
            _hasShownCameraRollHint = newValue
            defaults.set(newValue, forKey: Keys.hasShownCameraRollHint)
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

    private init() {
        // Load saved values from UserDefaults
        if let rawValue = defaults.string(forKey: Keys.photoStorageQuality) {
            // Try new rawValue format first
            if let quality = PhotoStorageQuality(rawValue: rawValue) {
                _photoStorageQuality = quality
            } else {
                // Migrate old rawValue format ("High Quality" -> "high", etc.)
                let migratedQuality: PhotoStorageQuality? = switch rawValue {
                case "High Quality": .high
                case "Balanced": .balanced
                case "Compact": .compact
                default: nil
                }
                if let quality = migratedQuality {
                    _photoStorageQuality = quality
                    // Save with new format
                    defaults.set(quality.rawValue, forKey: Keys.photoStorageQuality)
                }
            }
        }

        let savedThreshold = defaults.float(forKey: Keys.autoAcceptThreshold)
        if savedThreshold > 0 {
            _autoAcceptThreshold = savedThreshold
        }

        _showConfidenceScores = defaults.bool(forKey: Keys.showConfidenceScores)

        if defaults.object(forKey: Keys.showBoundingBoxes) != nil {
            _showBoundingBoxes = defaults.bool(forKey: Keys.showBoundingBoxes)
        }

        _savePhotosToCameraRoll = defaults.bool(forKey: Keys.savePhotosToCameraRoll)
        _hasShownCameraRollHint = defaults.bool(forKey: Keys.hasShownCameraRollHint)
    }
}
