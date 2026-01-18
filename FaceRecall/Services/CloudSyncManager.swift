import Foundation
import CloudKit

/// Manages iCloud sync status and monitoring for premium users
@Observable
@MainActor
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    // MARK: - Container ID

    static let containerIdentifier = "iCloud.com.remet.FaceRecall"

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case disabled
        case checking
        case syncing
        case synced
        case error(String)
        case noAccount

        var icon: String {
            switch self {
            case .disabled: return "icloud.slash"
            case .checking, .syncing: return "icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .noAccount: return "person.crop.circle.badge.exclamationmark"
            }
        }

        var color: String {
            switch self {
            case .disabled: return "secondary"
            case .checking, .syncing: return "blue"
            case .synced: return "green"
            case .error: return "red"
            case .noAccount: return "orange"
            }
        }
    }

    // MARK: - State

    private(set) var syncStatus: SyncStatus = .disabled
    private(set) var lastSyncDate: Date?
    private(set) var isCloudKitAvailable = false

    private let container: CKContainer
    private var accountObserver: (any NSObjectProtocol)?

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
        setupAccountNotifications()

        // Initial check
        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Account Status

    /// Check iCloud account availability
    @discardableResult
    func checkAccountStatus() async -> Bool {
        syncStatus = .checking

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                isCloudKitAvailable = true
                syncStatus = .synced
                lastSyncDate = Date()
                return true

            case .noAccount:
                isCloudKitAvailable = false
                syncStatus = .noAccount
                return false

            case .restricted:
                isCloudKitAvailable = false
                syncStatus = .error(String(localized: "iCloud access restricted"))
                return false

            case .couldNotDetermine:
                isCloudKitAvailable = false
                syncStatus = .error(String(localized: "Could not determine iCloud status"))
                return false

            case .temporarilyUnavailable:
                isCloudKitAvailable = false
                syncStatus = .error(String(localized: "iCloud temporarily unavailable"))
                return false

            @unknown default:
                isCloudKitAvailable = false
                syncStatus = .error(String(localized: "Unknown iCloud status"))
                return false
            }
        } catch {
            isCloudKitAvailable = false
            syncStatus = .error(error.localizedDescription)
            return false
        }
    }

    /// Update sync status manually
    func updateStatus(_ status: SyncStatus) {
        syncStatus = status
        if case .synced = status {
            lastSyncDate = Date()
        }
    }

    /// Mark sync as disabled (for non-premium users)
    func setDisabled() {
        syncStatus = .disabled
        isCloudKitAvailable = false
    }

    /// Refresh sync status if premium
    func refreshIfPremium(isPremium: Bool) async {
        if isPremium {
            await checkAccountStatus()
        } else {
            setDisabled()
        }
    }

    // MARK: - Private

    private func setupAccountNotifications() {
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAccountStatus()
            }
        }
    }
}
