import Foundation
import StoreKit

/// Manages subscription purchases and entitlements using StoreKit 2
@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs

    static let monthlyProductId = "com.remet.premium.monthly"
    static let yearlyProductId = "com.remet.premium.yearly"
    static let productIds = [monthlyProductId, yearlyProductId]

    // MARK: - State

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var subscriptionStatus: SubscriptionStatus = .free
    private(set) var isLoading = false
    private(set) var purchaseError: String?

    // MARK: - Gifted Premium (Referrals)

    private let giftedPremiumKey = "remet_gifted_premium_until"

    /// Date until which the user has free premium from referrals
    var giftedPremiumUntil: Date? {
        get { UserDefaults.standard.object(forKey: giftedPremiumKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: giftedPremiumKey) }
    }

    /// Whether user currently has active gifted premium time
    var hasActiveGiftedPremium: Bool {
        guard let until = giftedPremiumUntil else { return false }
        return until > Date()
    }

    // MARK: - Computed Properties

    /// Whether the user has an active premium subscription or gifted premium
    var isPremium: Bool {
        // Check gifted premium first (from referrals)
        if hasActiveGiftedPremium {
            return true
        }
        // Then check subscription status
        switch subscriptionStatus {
        case .premium, .gracePeriod:
            return true
        case .free, .expired:
            return false
        }
    }

    /// Monthly product if available
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductId }
    }

    /// Yearly product if available
    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductId }
    }

    /// Savings percentage for yearly vs monthly
    var yearlySavingsPercent: Int {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return 0 }
        let monthlyAnnual = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        let savings = (monthlyAnnual - yearlyPrice) / monthlyAnnual * 100
        return Int(savings)
    }

    // MARK: - Subscription Status

    enum SubscriptionStatus: Equatable {
        case free
        case premium
        case expired
        case gracePeriod(expiresAt: Date)

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .premium: return "Premium"
            case .expired: return "Expired"
            case .gracePeriod: return "Grace Period"
            }
        }
    }

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        transactionListenerTask = listenForTransactions()
        Task { await refreshPurchaseStatus() }
    }

    // MARK: - Load Products

    /// Load available products from the App Store
    func loadProducts() async {
        guard products.isEmpty else { return }

        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIds)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Unable to load subscription options. Please try again."
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchase a subscription product
    /// - Returns: `true` if purchase succeeded, `false` if cancelled or pending
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshPurchaseStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            purchaseError = "Purchase is pending approval (e.g., parental controls)."
            return false

        @unknown default:
            purchaseError = "An unknown error occurred."
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            purchaseError = "Unable to restore purchases. Please try again."
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Gifted Premium

    /// Grant free premium time (e.g., from referrals)
    /// - Parameter months: Number of months to grant
    func grantFreePremium(months: Int = 1) {
        let calendar = Calendar.current
        let currentEnd = giftedPremiumUntil ?? Date()
        let startDate = currentEnd > Date() ? currentEnd : Date()

        if let newEnd = calendar.date(byAdding: .month, value: months, to: startDate) {
            giftedPremiumUntil = newEnd
        }
    }

    /// Remaining days of gifted premium
    var giftedPremiumDaysRemaining: Int {
        guard let until = giftedPremiumUntil, until > Date() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: until).day ?? 0
        return max(0, days)
    }

    // MARK: - Refresh Status

    /// Refresh subscription status from current entitlements
    func refreshPurchaseStatus() async {
        var validProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.revocationDate == nil {
                validProductIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = validProductIDs

        if purchasedProductIDs.isEmpty {
            subscriptionStatus = .free
        } else {
            await updateDetailedSubscriptionStatus()
        }
    }

    // MARK: - Private Helpers

    private func updateDetailedSubscriptionStatus() async {
        // Find the first purchased product that's a subscription
        guard let product = products.first(where: { purchasedProductIDs.contains($0.id) }),
              let subscription = product.subscription else {
            subscriptionStatus = purchasedProductIDs.isEmpty ? .free : .premium
            return
        }

        do {
            let statuses = try await subscription.status
            guard let status = statuses.first else {
                subscriptionStatus = .premium
                return
            }

            switch status.state {
            case .subscribed:
                subscriptionStatus = .premium

            case .inGracePeriod:
                if case .verified(let info) = status.renewalInfo,
                   let expirationDate = info.gracePeriodExpirationDate {
                    subscriptionStatus = .gracePeriod(expiresAt: expirationDate)
                } else {
                    subscriptionStatus = .premium
                }

            case .inBillingRetryPeriod:
                // Give them a week grace period during billing retry
                let gracePeriodEnd = Date().addingTimeInterval(7 * 24 * 60 * 60)
                subscriptionStatus = .gracePeriod(expiresAt: gracePeriodEnd)

            case .expired, .revoked:
                subscriptionStatus = .expired

            default:
                subscriptionStatus = .free
            }
        } catch {
            // If we can't get detailed status but have entitlements, assume premium
            subscriptionStatus = purchasedProductIDs.isEmpty ? .free : .premium
        }
    }

    /// Listen for transaction updates (purchases, renewals, refunds)
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshPurchaseStatus()
            }
        }
    }

    /// Verify a transaction result
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw SubscriptionError.verificationFailed
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Unable to verify purchase. Please contact support."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        }
    }
}
