import Foundation
import SwiftUI

/// Manages referral codes, promo codes, and credit tracking
@Observable @MainActor
final class ReferralManager {
    static let shared = ReferralManager()

    // MARK: - Constants

    static let creditPerReferral: Decimal = 0.50
    static let maxCreditBalance: Decimal = 5.00
    static let creditExpirationDays: Int = 365

    // MARK: - State

    private(set) var credit: ReferralCredit
    private(set) var isLoading = false
    private(set) var error: String?

    private let cloudKit = ReferralCloudKitService.shared
    private let storageKey = "remet_referral_credit"

    // MARK: - Computed Properties

    var referralCode: String { credit.referralCode }
    var balance: Decimal { credit.balance }
    var referralCount: Int { credit.referralCount }
    var hasCredit: Bool { credit.balance > 0 }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: credit.balance as NSDecimalNumber) ?? "$0.00"
    }

    // MARK: - Init

    private init() {
        // Load from storage or create new
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(ReferralCredit.self, from: data) {
            self.credit = saved
        } else {
            self.credit = ReferralCredit()
        }

        // Generate referral code if needed
        if credit.referralCode.isEmpty {
            credit.referralCode = generateUniqueCode()
            save()
        }
    }

    // MARK: - Code Generation

    /// Generate a unique referral code
    private func generateUniqueCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let random = (0..<6).map { _ in chars.randomElement()! }
        return "REMET-\(String(random))"
    }

    /// Ensure code is synced to CloudKit
    func syncReferralCode() async {
        guard !credit.referralCode.isEmpty else { return }

        do {
            // Check if code exists in CloudKit
            let exists = await cloudKit.codeExists(credit.referralCode)
            if !exists {
                try await cloudKit.saveReferralCode(credit.referralCode)
            }
        } catch {
            print("Failed to sync referral code: \(error)")
        }
    }

    // MARK: - Apply Code

    /// Apply a referral or promo code
    func applyCode(_ code: String) async -> Result<CodeApplyResult, ReferralError> {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedCode.isEmpty else {
            return .failure(.invalidCode)
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        // Determine code type
        if trimmedCode.hasPrefix("REMET-") {
            return await applyReferralCode(trimmedCode)
        } else {
            return await applyPromoCode(trimmedCode)
        }
    }

    /// Apply a referral code
    private func applyReferralCode(_ code: String) async -> Result<CodeApplyResult, ReferralError> {
        // Check if already used a referral code
        if credit.referredBy != nil {
            return .failure(.alreadyUsedReferralCode)
        }

        // Check for self-referral
        if code == credit.referralCode {
            return .failure(.selfReferral)
        }

        do {
            // Validate code exists
            guard let codeInfo = try await cloudKit.validateReferralCode(code) else {
                return .failure(.invalidCode)
            }

            // Create referral event
            try await cloudKit.createReferralEvent(
                referralCode: code,
                referredDeviceID: ReferralCloudKitService.deviceID
            )

            // Store locally
            credit.referredBy = code
            save()

            return .success(CodeApplyResult(
                type: .referral,
                message: "Referral code applied! You'll get $0.50 credit when you subscribe."
            ))
        } catch let error as ReferralError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }

    /// Apply a promo code
    private func applyPromoCode(_ code: String) async -> Result<CodeApplyResult, ReferralError> {
        // Check if already used a promo code
        let hasUsedPromo = await cloudKit.hasRedeemedPromoCode(deviceID: ReferralCloudKitService.deviceID)
        if hasUsedPromo {
            return .failure(.alreadyUsedPromoCode)
        }

        do {
            // Validate promo code
            guard let promoInfo = try await cloudKit.validatePromoCode(code) else {
                return .failure(.invalidCode)
            }

            // Redeem promo code
            try await cloudKit.redeemPromoCode(
                code,
                deviceID: ReferralCloudKitService.deviceID,
                promoRecordID: promoInfo.recordID
            )

            // Add credit locally
            let creditAmount = min(promoInfo.creditAmount, Self.maxCreditBalance - credit.balance)
            if creditAmount > 0 {
                addCredit(amount: creditAmount, type: .promoBonus, description: "Promo code: \(code)")
            }

            return .success(CodeApplyResult(
                type: .promo,
                creditAmount: creditAmount,
                message: "Promo code applied! You received \(formatCurrency(creditAmount)) credit."
            ))
        } catch let error as ReferralError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }

    // MARK: - Credit Management

    /// Add credit to balance
    func addCredit(amount: Decimal, type: CreditType, description: String) {
        let cappedAmount = min(amount, Self.maxCreditBalance - credit.balance)
        guard cappedAmount > 0 else { return }

        credit.balance += cappedAmount
        credit.lifetimeEarned += cappedAmount

        let transaction = CreditTransaction(
            id: UUID(),
            amount: cappedAmount,
            type: type,
            date: Date(),
            description: description
        )
        credit.creditHistory.append(transaction)

        save()
    }

    /// Redeem credits (called after successful subscription)
    func redeemCredits(for productID: String) -> Decimal {
        guard credit.balance > 0 else { return 0 }

        let amountRedeemed = credit.balance
        credit.balance = 0

        let transaction = CreditTransaction(
            id: UUID(),
            amount: -amountRedeemed,
            type: .redeemed,
            date: Date(),
            description: "Applied to \(productID.contains("monthly") ? "Monthly" : "Yearly") subscription"
        )
        credit.creditHistory.append(transaction)

        save()
        return amountRedeemed
    }

    /// Award credit when referred user subscribes
    func onReferredUserSubscribed() async {
        // Mark our referral event as subscribed
        do {
            if let referralCode = try await cloudKit.markReferralEventSubscribed(
                deviceID: ReferralCloudKitService.deviceID
            ) {
                // We were referred - add our bonus
                addCredit(amount: Self.creditPerReferral, type: .referredBonus, description: "Welcome bonus")

                // The referrer will get credited on their next sync
                print("Marked subscription for referral code: \(referralCode)")
            }
        } catch {
            print("Failed to mark referral event: \(error)")
        }
    }

    /// Sync to check for new referral credits (called periodically)
    func syncCredits() async {
        // First sync our referral code to CloudKit
        await syncReferralCode()

        // Check for uncredited referrals
        do {
            let uncredited = try await cloudKit.getUncreditedReferrals(forCode: credit.referralCode)

            for event in uncredited {
                addCredit(
                    amount: Self.creditPerReferral,
                    type: .referralBonus,
                    description: "Friend subscribed"
                )
                credit.referralCount += 1
            }

            if !uncredited.isEmpty {
                // Mark them as credited
                try await cloudKit.markReferralsCredited(recordIDs: uncredited.map { $0.recordID })

                // Update referral count in CloudKit
                if let codeInfo = try await cloudKit.validateReferralCode(credit.referralCode) {
                    try await cloudKit.incrementReferralCount(recordID: codeInfo.recordID)
                }
            }

            credit.lastSyncedAt = Date()
            save()
        } catch {
            print("Failed to sync credits: \(error)")
        }
    }

    /// Expire old credits
    func expireOldCredits() {
        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.creditExpirationDays,
            to: Date()
        ) ?? Date()

        var expiredAmount: Decimal = 0

        for transaction in credit.creditHistory {
            if transaction.type == .referralBonus || transaction.type == .referredBonus || transaction.type == .promoBonus {
                if transaction.date < expirationDate && transaction.amount > 0 {
                    expiredAmount += transaction.amount
                }
            }
        }

        if expiredAmount > 0 && expiredAmount <= credit.balance {
            credit.balance -= expiredAmount

            let transaction = CreditTransaction(
                id: UUID(),
                amount: -expiredAmount,
                type: .expired,
                date: Date(),
                description: "Credits expired after 12 months"
            )
            credit.creditHistory.append(transaction)
            save()
        }
    }

    // MARK: - Sharing

    /// Get the share message for referrals
    func shareMessage() -> String {
        """
        Know someone who struggles remembering faces?
        Try Remet - it helps you never forget a face again.

        Use my code \(credit.referralCode) and we both get $0.50 off Premium!

        Download: https://apps.apple.com/app/remet/id123456789
        """
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(credit) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Supporting Types

struct ReferralCredit: Codable {
    var balance: Decimal = 0
    var lifetimeEarned: Decimal = 0
    var referralCode: String = ""
    var referredBy: String?
    var referralCount: Int = 0
    var creditHistory: [CreditTransaction] = []
    var lastSyncedAt: Date?
    var appliedPromoCode: String?
}

struct CreditTransaction: Codable, Identifiable {
    let id: UUID
    let amount: Decimal
    let type: CreditType
    let date: Date
    let description: String
}

enum CreditType: String, Codable {
    case referralBonus      // Earned by referring someone
    case referredBonus      // Earned by being referred
    case promoBonus         // Earned from promo code
    case redeemed           // Applied to subscription
    case expired            // Credit expired after 12 months
}

struct CodeApplyResult {
    let type: CodeType
    var creditAmount: Decimal = 0
    let message: String

    enum CodeType {
        case referral
        case promo
    }
}
