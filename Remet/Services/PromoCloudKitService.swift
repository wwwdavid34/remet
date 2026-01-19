import Foundation
import CloudKit

/// Handles CloudKit operations for promo codes
actor PromoCloudKitService {
    static let shared = PromoCloudKitService()

    private let container: CKContainer
    private let publicDatabase: CKDatabase

    // Record Types
    private let promoCodeType = "PromoCode"
    private let promoRedemptionType = "PromoRedemption"

    private init() {
        container = CKContainer.default()
        publicDatabase = container.publicCloudDatabase
    }

    // MARK: - Device ID

    /// Get or create a unique device identifier
    static var deviceID: String {
        let key = "remet_device_id"
        if let existingID = UserDefaults.standard.string(forKey: key) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    // MARK: - Promo Code Operations

    /// Validate a promo code
    /// PromoCode record fields:
    /// - code: String (the promo code)
    /// - freeMonths: Int (number of free months to grant)
    /// - maxUses: Int (0 = unlimited)
    /// - currentUses: Int
    /// - expiresAt: Date? (optional expiration)
    /// - isActive: Bool
    /// - campaign: String? (for tracking, e.g., "beta_testers", "influencer_jan2025")
    func validatePromoCode(_ code: String) async throws -> PromoCodeInfo? {
        let predicate = NSPredicate(format: "code == %@ AND isActive == true", code.uppercased())
        let query = CKQuery(recordType: promoCodeType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first,
              let record = try? result.get() else {
            return nil
        }

        // Check expiration
        if let expiresAt = record["expiresAt"] as? Date, expiresAt < Date() {
            return nil
        }

        // Check max uses
        let maxUses = record["maxUses"] as? Int ?? 0
        let currentUses = record["currentUses"] as? Int ?? 0
        if maxUses > 0 && currentUses >= maxUses {
            return nil
        }

        return PromoCodeInfo(
            code: record["code"] as? String ?? "",
            freeMonths: record["freeMonths"] as? Int ?? 1,
            maxUses: maxUses,
            currentUses: currentUses,
            campaign: record["campaign"] as? String,
            recordID: record.recordID
        )
    }

    /// Check if device already redeemed a promo code
    func hasRedeemedPromoCode(deviceID: String) async -> Bool {
        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        let query = CKQuery(recordType: promoRedemptionType, predicate: predicate)

        do {
            let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    /// Redeem a promo code
    func redeemPromoCode(_ code: String, deviceID: String, promoRecordID: CKRecord.ID) async throws {
        // Check if already redeemed
        if await hasRedeemedPromoCode(deviceID: deviceID) {
            throw PromoError.alreadyRedeemed
        }

        // Create redemption record
        let redemptionRecord = CKRecord(recordType: promoRedemptionType)
        redemptionRecord["promoCode"] = code.uppercased()
        redemptionRecord["deviceID"] = deviceID
        redemptionRecord["redeemedAt"] = Date()

        try await publicDatabase.save(redemptionRecord)

        // Increment usage count on promo code
        let promoRecord = try await publicDatabase.record(for: promoRecordID)
        let currentUses = promoRecord["currentUses"] as? Int ?? 0
        promoRecord["currentUses"] = currentUses + 1
        try await publicDatabase.save(promoRecord)
    }
}

// MARK: - Supporting Types

struct PromoCodeInfo {
    let code: String
    let freeMonths: Int
    let maxUses: Int
    let currentUses: Int
    let campaign: String?
    let recordID: CKRecord.ID
}
