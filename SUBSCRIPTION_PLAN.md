# FaceRecall Subscription Feature Plan

## Branch
Work on feature branch: `feature/subscription`

---

## Overview
Add subscription monetization with StoreKit 2, usage limits for free tier, and lay groundwork for cloud sync.

**Pricing:**
- Monthly: $4.99/month
- Yearly: $39.99/year (33% savings)

---

## Free vs Premium Features

| Feature | Free | Premium |
|---------|------|---------|
| People | 25 max | Unlimited |
| Face quiz | Yes | Yes |
| Encounters | Yes | Yes |
| Tags | 5 | Unlimited |
| Cloud sync | No | Yes |
| Multi-device | No | Yes |
| Advanced analytics | No | Planned |

---

## Phase 1: StoreKit + Limits (Ship First)

### New Files to Create

| File | Purpose |
|------|---------|
| `Services/SubscriptionManager.swift` | StoreKit 2 purchase handling, transaction listener |
| `Services/SubscriptionLimits.swift` | Limit constants (25 people, 5 tags) |
| `Services/LimitChecker.swift` | Runtime limit enforcement |
| `Services/FeatureFlags.swift` | Feature availability checks |
| `Views/Subscription/PaywallView.swift` | Purchase UI with product options |
| `Views/Subscription/LimitWarningBanner.swift` | Soft limit warning (at 80%) |
| `Views/Subscription/LimitReachedView.swift` | Hard limit paywall |
| `Products.storekit` | Local testing configuration |

### Files to Modify

| File | Changes |
|------|---------|
| `FaceRecallApp.swift` | Inject `SubscriptionManager`, `FeatureFlags` via environment |
| `AppSettings.swift` | Add `firstLaunchDate`, `isInGracePeriod` for existing users |
| `AccountView.swift` | Replace hardcoded `isPremium` with real subscription status |
| `AddPersonView.swift` | Check limits before creating person |
| `QuickCaptureView.swift` | Check limits before capture flow |
| `PeopleListView.swift` | Add `LimitWarningBanner` |
| `HomeView.swift` | Show limit status |

### SubscriptionManager Core Implementation

```swift
@Observable @MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var isPremium: Bool = false
    private(set) var products: [Product] = []

    func loadProducts() async { ... }
    func purchase(_ product: Product) async throws -> Bool { ... }
    func restorePurchases() async { ... }
}
```

### Limit Enforcement

**Soft limit** (80% = 20 people): Show warning banner with upgrade CTA
**Hard limit** (25 people): Block adding, show paywall sheet

**Grace period**: Existing users get 30 days unlimited before limits apply

---

## Phase 2: Cloud Sync (Future)

### Backend: CloudKit
- Zero server maintenance
- iCloud authentication built-in
- Private database for user data

### Sync Models
Add to Person, Encounter, FaceEmbedding:
```swift
var cloudKitRecordID: String?
var lastSyncedAt: Date?
var needsSync: Bool = false
```

### Conflict Resolution
Last-write-wins based on `lastModifiedAt` timestamps.

---

## Implementation Steps

### Step 1: SubscriptionManager
1. Create `Products.storekit` configuration
2. Implement `SubscriptionManager` with product loading, purchase, restore
3. Add transaction listener for real-time status updates

### Step 2: Limit System
1. Create `SubscriptionLimits` constants
2. Create `LimitChecker` service
3. Add grace period tracking to `AppSettings`

### Step 3: Paywall UI
1. Build `PaywallView` with products, features list
2. Build `LimitWarningBanner` and `LimitReachedView`
3. Add restore purchases button

### Step 4: Integration
1. Inject services via environment in `FaceRecallApp`
2. Replace `isPremium = false` in AccountView
3. Add limit checks to AddPersonView, QuickCaptureView
4. Add warning banners to PeopleListView, HomeView

### Step 5: App Store Compliance
- Restore purchases visible and working
- Subscription terms displayed
- Links to Terms of Service and Privacy Policy
- Auto-renewal disclosure

---

## Verification

1. **StoreKit sandbox**: Test purchase and restore with sandbox account
2. **Limit enforcement**: Add 25 people, verify hard limit triggers paywall
3. **Soft limit**: At 20 people, verify warning banner appears
4. **Grace period**: Existing user data should allow unlimited for 30 days
5. **Subscription status**: Premium users see "Premium Active" in Account tab
