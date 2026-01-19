import Foundation
import SwiftUI

/// Manages promo codes for beta testers and influencers
@Observable @MainActor
final class PromoCodeManager {
    static let shared = PromoCodeManager()

    // MARK: - State

    private(set) var redeemedCode: String?
    private(set) var isLoading = false
    private(set) var error: String?

    private let cloudKit = PromoCloudKitService.shared
    private let storageKey = "remet_promo_data"

    // MARK: - Computed

    var hasRedeemedCode: Bool { redeemedCode != nil }

    // MARK: - Init

    private init() {
        loadFromStorage()
    }

    // MARK: - Apply Promo Code

    /// Apply a promo code - grants free premium months
    func applyCode(_ code: String) async -> Result<PromoResult, PromoError> {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedCode.isEmpty else {
            return .failure(.invalidCode)
        }

        // Check if already redeemed a code
        if redeemedCode != nil {
            return .failure(.alreadyRedeemed)
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Validate promo code in CloudKit
            guard let promoInfo = try await cloudKit.validatePromoCode(trimmedCode) else {
                return .failure(.invalidCode)
            }

            // Redeem the code
            try await cloudKit.redeemPromoCode(
                trimmedCode,
                deviceID: PromoCloudKitService.deviceID,
                promoRecordID: promoInfo.recordID
            )

            // Store locally
            redeemedCode = trimmedCode
            saveToStorage()

            // Grant free premium
            SubscriptionManager.shared.grantFreePremium(months: promoInfo.freeMonths)

            let message = promoInfo.freeMonths == 1
                ? String(localized: "You got 1 month of Premium free!")
                : String(localized: "You got \(promoInfo.freeMonths) months of Premium free!")

            return .success(PromoResult(freeMonths: promoInfo.freeMonths, message: message))
        } catch let error as PromoError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        redeemedCode = UserDefaults.standard.string(forKey: storageKey)
    }

    private func saveToStorage() {
        UserDefaults.standard.set(redeemedCode, forKey: storageKey)
    }
}

// MARK: - Supporting Types

struct PromoResult {
    let freeMonths: Int
    let message: String
}

enum PromoError: LocalizedError {
    case invalidCode
    case alreadyRedeemed
    case codeExpired
    case codeLimitReached
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return String(localized: "This code is not valid.")
        case .alreadyRedeemed:
            return String(localized: "You've already redeemed a promo code.")
        case .codeExpired:
            return String(localized: "This code has expired.")
        case .codeLimitReached:
            return String(localized: "This code has reached its usage limit.")
        case .networkError(let error):
            return String(localized: "Network error: \(error.localizedDescription)")
        }
    }
}
