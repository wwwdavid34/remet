import SwiftUI
import SwiftData

struct AccountView: View {
    @Query private var encounters: [Encounter]
    @Query private var people: [Person]
    @Query private var embeddings: [FaceEmbedding]

    private var settings = AppSettings.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var referralManager = ReferralManager.shared

    @State private var showSignInSheet = false
    @State private var showPaywall = false
    @State private var showInviteFriends = false
    @State private var showEnterCode = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                subscriptionSection
                referralSection
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showSignInSheet) {
                SignInSheet()
            }
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

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        Section {
            // TODO: Replace with actual authentication state
            let isSignedIn = false

            if isSignedIn {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("John Doe")
                            .fontWeight(.medium)
                        Text("john@example.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Sign Out", role: .destructive) {
                        // TODO: Implement sign out
                    }
                    .font(.subheadline)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Sign in to sync your data across devices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)

                    Button {
                        showSignInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Sign In")
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Account")
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
                        Text("Premium Active")
                            .fontWeight(.medium)
                        if case .gracePeriod(let expiresAt) = subscriptionManager.subscriptionStatus {
                            Text("Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Manage") {
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
                        Text("Upgrade to Premium")
                            .fontWeight(.semibold)
                    }

                    // Usage status
                    HStack {
                        Image(systemName: "person.3")
                            .foregroundStyle(AppColors.teal)
                        Text("\(people.count)/\(SubscriptionLimits.freePeopleLimit) people")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        PremiumFeatureRow(icon: "infinity", text: "Unlimited people & encounters")
                        PremiumFeatureRow(icon: "icloud", text: "Cloud sync across devices")
                        PremiumFeatureRow(icon: "chart.bar", text: "Advanced analytics")
                    }

                    Button {
                        showPaywall = true
                    } label: {
                        Text("View Plans")
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
        } header: {
            Text("Subscription")
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
                        Text("Invite Friends")
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("Get $0.50 credit for each referral")
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
                            Text("Enter Code")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text("Have a referral or promo code?")
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
            Text("Referrals & Promos")
        }
    }

    // MARK: - Photo Storage Section

    @ViewBuilder
    private var photoStorageSection: some View {
        Section {
            Picker("Photo Quality", selection: Binding(
                get: { settings.photoStorageQuality },
                set: { settings.photoStorageQuality = $0 }
            )) {
                ForEach(PhotoStorageQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.photoStorageQuality.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Resolution: \(Int(settings.photoResolution))px")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Photo Storage")
        } footer: {
            Text("Higher quality uses more storage but preserves more detail. Changes apply to newly imported photos only.")
        }
    }

    // MARK: - Face Matching Section

    @ViewBuilder
    private var faceMatchingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Auto-Accept Threshold")
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

            Toggle("Show Confidence Scores", isOn: Binding(
                get: { settings.showConfidenceScores },
                set: { settings.showConfidenceScores = $0 }
            ))
        } header: {
            Text("Face Matching")
        } footer: {
            Text("Faces matched above the threshold are automatically labeled. Lower values match more aggressively but may cause false positives.")
        }
    }

    // MARK: - Storage Info Section

    @ViewBuilder
    private var storageInfoSection: some View {
        Section("Storage Usage") {
            StorageRow(
                title: "Encounters",
                count: encounters.count,
                icon: "person.2.crop.square.stack"
            )

            StorageRow(
                title: "People",
                count: people.count,
                icon: "person.3"
            )

            StorageRow(
                title: "Face Samples",
                count: embeddings.count,
                icon: "face.smiling"
            )

            if let storageSize = calculateStorageSize() {
                HStack {
                    Label("Estimated Storage", systemImage: "internaldrive")
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
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                PrivacyInfoView()
            } label: {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
    }

    // MARK: - Helpers

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
