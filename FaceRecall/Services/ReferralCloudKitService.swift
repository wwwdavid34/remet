import Foundation
import CloudKit

/// Handles CloudKit operations for referral codes, events, and promo codes
actor ReferralCloudKitService {
    static let shared = ReferralCloudKitService()

    private let container: CKContainer
    private let publicDatabase: CKDatabase

    // Record Types
    private let referralCodeType = "ReferralCode"
    private let referralEventType = "ReferralEvent"
    private let promoCodeType = "PromoCode"
    private let promoRedemptionType = "PromoRedemption"

    private init() {
        // Use default container based on bundle ID
        // This requires CloudKit capability to be enabled in Xcode
        container = CKContainer.default()
        publicDatabase = container.publicCloudDatabase
    }

    // MARK: - Device ID

    /// Get or create a unique device identifier for this device
    static var deviceID: String {
        let key = "remet_device_id"
        if let existingID = UserDefaults.standard.string(forKey: key) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    // MARK: - Referral Code Operations

    /// Save a new referral code to CloudKit
    func saveReferralCode(_ code: String) async throws {
        let record = CKRecord(recordType: referralCodeType)
        record["code"] = code
        record["ownerDeviceID"] = Self.deviceID
        record["createdAt"] = Date()
        record["referralCount"] = 0
        record["isActive"] = true

        try await publicDatabase.save(record)
    }

    /// Check if a referral code exists and is valid
    func validateReferralCode(_ code: String) async throws -> ReferralCodeInfo? {
        let predicate = NSPredicate(format: "code == %@ AND isActive == true", code.uppercased())
        let query = CKQuery(recordType: referralCodeType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first,
              let record = try? result.get() else {
            return nil
        }

        return ReferralCodeInfo(
            code: record["code"] as? String ?? "",
            ownerDeviceID: record["ownerDeviceID"] as? String ?? "",
            referralCount: record["referralCount"] as? Int ?? 0,
            recordID: record.recordID
        )
    }

    /// Check if a referral code already exists (for generating unique codes)
    func codeExists(_ code: String) async -> Bool {
        do {
            let info = try await validateReferralCode(code)
            return info != nil
        } catch {
            return false
        }
    }

    /// Increment the referral count for a code
    func incrementReferralCount(recordID: CKRecord.ID) async throws {
        let record = try await publicDatabase.record(for: recordID)
        let currentCount = record["referralCount"] as? Int ?? 0
        record["referralCount"] = currentCount + 1
        try await publicDatabase.save(record)
    }

    // MARK: - Referral Event Operations

    /// Record when a user enters a referral code
    func createReferralEvent(referralCode: String, referredDeviceID: String) async throws {
        // Check if this device already used a referral code
        let existingPredicate = NSPredicate(format: "referredDeviceID == %@", referredDeviceID)
        let existingQuery = CKQuery(recordType: referralEventType, predicate: existingPredicate)
        let (existingResults, _) = try await publicDatabase.records(matching: existingQuery, resultsLimit: 1)

        if !existingResults.isEmpty {
            throw ReferralError.alreadyUsedReferralCode
        }

        let record = CKRecord(recordType: referralEventType)
        record["referralCode"] = referralCode.uppercased()
        record["referredDeviceID"] = referredDeviceID
        record["subscribedAt"] = nil as Date?
        record["credited"] = false
        record["createdAt"] = Date()

        try await publicDatabase.save(record)
    }

    /// Mark a referral event as subscribed (called when referred user subscribes)
    func markReferralEventSubscribed(deviceID: String) async throws -> String? {
        let predicate = NSPredicate(format: "referredDeviceID == %@ AND subscribedAt == nil", deviceID)
        let query = CKQuery(recordType: referralEventType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first,
              let record = try? result.get() else {
            return nil
        }

        record["subscribedAt"] = Date()
        try await publicDatabase.save(record)

        // Return the referral code so we can credit the referrer
        return record["referralCode"] as? String
    }

    /// Get uncredited referral events for a referral code (for crediting referrer)
    func getUncreditedReferrals(forCode code: String) async throws -> [ReferralEventInfo] {
        let predicate = NSPredicate(format: "referralCode == %@ AND subscribedAt != nil AND credited == false", code.uppercased())
        let query = CKQuery(recordType: referralEventType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)

        return results.compactMap { (_, result) -> ReferralEventInfo? in
            guard let record = try? result.get() else { return nil }
            return ReferralEventInfo(
                referralCode: record["referralCode"] as? String ?? "",
                referredDeviceID: record["referredDeviceID"] as? String ?? "",
                subscribedAt: record["subscribedAt"] as? Date,
                recordID: record.recordID
            )
        }
    }

    /// Mark referral events as credited
    func markReferralsCredited(recordIDs: [CKRecord.ID]) async throws {
        for recordID in recordIDs {
            let record = try await publicDatabase.record(for: recordID)
            record["credited"] = true
            try await publicDatabase.save(record)
        }
    }

    // MARK: - Promo Code Operations

    /// Validate a promo code
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
            creditAmount: Decimal(record["creditAmount"] as? Double ?? 0),
            creditType: record["creditType"] as? String ?? "fixed",
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

struct ReferralCodeInfo {
    let code: String
    let ownerDeviceID: String
    let referralCount: Int
    let recordID: CKRecord.ID
}

struct ReferralEventInfo {
    let referralCode: String
    let referredDeviceID: String
    let subscribedAt: Date?
    let recordID: CKRecord.ID
}

struct PromoCodeInfo {
    let code: String
    let creditAmount: Decimal
    let creditType: String  // "fixed" or "percentage"
    let maxUses: Int
    let currentUses: Int
    let campaign: String?
    let recordID: CKRecord.ID

    var isPercentage: Bool { creditType == "percentage" }
}

enum ReferralError: LocalizedError {
    case invalidCode
    case alreadyUsedReferralCode
    case alreadyUsedPromoCode
    case codeExpired
    case codeLimitReached
    case selfReferral
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "This code is not valid."
        case .alreadyUsedReferralCode:
            return "You've already used a referral code."
        case .alreadyUsedPromoCode:
            return "You've already used a promo code."
        case .codeExpired:
            return "This code has expired."
        case .codeLimitReached:
            return "This code has reached its usage limit."
        case .selfReferral:
            return "You can't use your own referral code."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
