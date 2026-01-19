import SwiftUI
import SwiftData

struct AccountView: View {
    @Query private var encounters: [Encounter]
    @Query private var people: [Person]
    @Query private var embeddings: [FaceEmbedding]

    private var settings = AppSettings.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var referralManager = ReferralManager.shared
    @State private var cloudSyncManager = CloudSyncManager.shared

    @State private var showPaywall = false
    @State private var isRestoringPurchases = false
    @State private var showInviteFriends = false
    @State private var showEnterCode = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                if subscriptionManager.isPremium {
                    syncSection
                }
                referralSection
                displaySection
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showInviteFriends) {
                InviteFriendsView()
            }
            .sheet(isPresented: $showEnterCode) {
                EnterReferralCodeView()
            }
            .task {
                await referralManager.syncCredits()
            }
        }
    }

    // MARK: - Sync Section

    @ViewBuilder
    private var syncSection: some View {
        Section {
            NavigationLink {
                SyncSettingsView()
                    .environment(cloudSyncManager)
            } label: {
                HStack {
                    Image(systemName: cloudSyncManager.syncStatus.icon)
                        .foregroundStyle(syncStatusColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "iCloud Sync"))
                            .fontWeight(.medium)
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "Sync"))
        }
    }

    private var syncStatusColor: Color {
        switch cloudSyncManager.syncStatus {
        case .disabled: return .secondary
        case .checking, .syncing: return .blue
        case .synced: return .green
        case .error: return .red
        case .noAccount: return .orange
        }
    }

    private var syncStatusText: String {
        switch cloudSyncManager.syncStatus {
        case .disabled: return String(localized: "Disabled")
        case .checking: return String(localized: "Checking...")
        case .syncing: return String(localized: "Syncing...")
        case .synced: return String(localized: "All data synced")
        case .error: return String(localized: "Error")
        case .noAccount: return String(localized: "No iCloud account")
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            if subscriptionManager.isPremium {
                // Premium active state
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppColors.warmYellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Premium Active"))
                            .fontWeight(.medium)
                        if case .gracePeriod(let expiresAt) = subscriptionManager.subscriptionStatus {
                            Text(String(localized: "Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(String(localized: "Manage")) {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.teal)
                }
            } else {
                // Free tier - show upgrade prompt
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(AppColors.warmYellow)
                        Text(String(localized: "Upgrade to Premium"))
                            .fontWeight(.semibold)
                    }

                    // Usage status
                    HStack {
                        Image(systemName: "person.3")
                            .foregroundStyle(AppColors.teal)
                        Text(String(localized: "\(people.count)/\(SubscriptionLimits.freePeopleLimit) people"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        PremiumFeatureRow(icon: "infinity", text: String(localized: "Unlimited people & encounters"))
                        PremiumFeatureRow(icon: "icloud", text: String(localized: "Cloud sync across devices"))
                        PremiumFeatureRow(icon: "chart.bar", text: String(localized: "Advanced analytics"))
                    }

                    Button {
                        showPaywall = true
                    } label: {
                        Text(String(localized: "View Plans"))
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.coral, AppColors.warmYellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            // Restore Purchases - always visible
            Button {
                Task {
                    isRestoringPurchases = true
                    await subscriptionManager.restorePurchases()
                    isRestoringPurchases = false
                }
            } label: {
                HStack {
                    if isRestoringPurchases {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(String(localized: "Restore Purchases"))
                }
            }
            .disabled(isRestoringPurchases)
        } header: {
            Text(String(localized: "Subscription"))
        }
    }

    // MARK: - Referral Section

    @ViewBuilder
    private var referralSection: some View {
        Section {
            // Invite Friends button
            Button {
                showInviteFriends = true
            } label: {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Invite Friends"))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(String(localized: "Get $0.50 credit for each referral"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Show credit balance if any
                    if referralManager.hasCredit {
                        Text(referralManager.formattedBalance)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Enter code option (if user hasn't used a referral code yet)
            if referralManager.credit.referredBy == nil {
                Button {
                    showEnterCode = true
                } label: {
                    HStack {
                        Image(systemName: "ticket")
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Enter Code"))
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(String(localized: "Have a referral or promo code?"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "Referrals & Promos"))
        }
    }

    // MARK: - Photo Storage Section

    @ViewBuilder
    private var photoStorageSection: some View {
        Section {
            Picker(String(localized: "Photo Quality"), selection: Binding(
                get: { settings.photoStorageQuality },
                set: { settings.photoStorageQuality = $0 }
            )) {
                ForEach(PhotoStorageQuality.allCases) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.photoStorageQuality.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(localized: "Resolution: \(Int(settings.photoResolution))px"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "Photo Storage"))
        } footer: {
            Text(String(localized: "Higher quality uses more storage but preserves more detail. Changes apply to newly imported photos only."))
        }
    }

    // MARK: - Face Matching Section

    @ViewBuilder
    private var faceMatchingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "Auto-Accept Threshold"))
                    Spacer()
                    Text("\(Int(settings.autoAcceptThreshold * 100))%")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { settings.autoAcceptThreshold },
                        set: { settings.autoAcceptThreshold = $0 }
                    ),
                    in: 0.7...0.99,
                    step: 0.01
                )
            }

            Toggle(String(localized: "Show Confidence Scores"), isOn: Binding(
                get: { settings.showConfidenceScores },
                set: { settings.showConfidenceScores = $0 }
            ))
        } header: {
            Text(String(localized: "Face Matching"))
        } footer: {
            Text(String(localized: "Faces matched above the threshold are automatically labeled. Lower values match more aggressively but may cause false positives."))
        }
    }

    // MARK: - Storage Info Section

    @ViewBuilder
    private var storageInfoSection: some View {
        Section(String(localized: "Storage Usage")) {
            StorageRow(
                title: String(localized: "Encounters"),
                count: encounters.count,
                icon: "person.2.crop.square.stack"
            )

            StorageRow(
                title: String(localized: "People"),
                count: people.count,
                icon: "person.3"
            )

            StorageRow(
                title: String(localized: "Face Samples"),
                count: embeddings.count,
                icon: "face.smiling"
            )

            if let storageSize = calculateStorageSize() {
                HStack {
                    Label(String(localized: "Estimated Storage"), systemImage: "internaldrive")
                    Spacer()
                    Text(storageSize)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section(String(localized: "About")) {
            HStack {
                Label(String(localized: "Version"), systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                FAQView()
            } label: {
                Label(String(localized: "FAQ"), systemImage: "questionmark.circle")
            }

            NavigationLink {
                PrivacyInfoView()
            } label: {
                Label(String(localized: "Privacy"), systemImage: "hand.raised")
            }

            Button {
                openSupportEmail()
            } label: {
                Label(String(localized: "Contact Support"), systemImage: "envelope")
            }
        }
    }

    // MARK: - Display Section

    @ViewBuilder
    private var displaySection: some View {
        Section {
            Toggle(String(localized: "Show \"Me\" in People List"), isOn: Binding(
                get: { settings.showMeInPeopleList },
                set: { settings.showMeInPeopleList = $0 }
            ))
        } header: {
            Text(String(localized: "Display"))
        } footer: {
            Text(String(localized: "When disabled, your profile won't appear in the People list but will still be used to exclude your face from practice quizzes."))
        }
    }

    // MARK: - Developer Section (Debug Only)

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        Section {
            Button {
                settings.hasCompletedOnboarding = false
            } label: {
                HStack {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    Spacer()
                    if !settings.hasCompletedOnboarding {
                        Text("Will show on next launch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(AppColors.coral)
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug options. Reset onboarding to test the first-run wizard without losing data.")
        }
    }
    #endif

    // MARK: - Helpers

    private func openSupportEmail() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "Unknown")
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "Unknown")
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        let isPremium = subscriptionManager.isPremium ? String(localized: "Yes") : String(localized: "No")

        let subject = String(localized: "Remet Support Request")
        let body = """


        ---
        \(String(localized: "App Version")): \(appVersion) (\(buildNumber))
        \(String(localized: "iOS Version")): \(iosVersion)
        \(String(localized: "Device")): \(deviceModel)
        \(String(localized: "Premium")): \(isPremium)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@remet-app.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    private func calculateStorageSize() -> String? {
        // Rough estimate based on counts
        let photoCount = encounters.reduce(0) { $0 + max(1, $1.photos.count) }
        let avgPhotoSize = settings.photoStorageQuality.estimatedSizePerPhoto
        let photoStorage = photoCount * avgPhotoSize // KB

        let faceStorage = embeddings.count * 12 // ~10KB crop + 2KB embedding

        let totalKB = photoStorage + faceStorage

        if totalKB < 1024 {
            return "\(totalKB) KB"
        } else if totalKB < 1024 * 1024 {
            return String(format: "%.1f MB", Double(totalKB) / 1024.0)
        } else {
            return String(format: "%.2f GB", Double(totalKB) / (1024.0 * 1024.0))
        }
    }
}

#Preview {
    AccountView()
}
