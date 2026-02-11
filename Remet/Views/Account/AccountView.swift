import SwiftUI
import SwiftData
import StoreKit

struct AccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var encounters: [Encounter]
    @Query private var people: [Person]
    @Query private var embeddings: [FaceEmbedding]

    private var settings = AppSettings.shared
    @State private var isLoadingDemoData = false
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var cloudSyncManager = CloudSyncManager.shared

    @State private var showPaywall = false
    @State private var isRestoringPurchases = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                if subscriptionManager.isPremium {
                    syncSection
                }
                displaySection
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
                dataManagementSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showDeleteConfirmation) {
                DeleteConfirmationView(
                    onConfirm: {
                        DemoDataService.clearAllData(modelContext: modelContext)
                        showDeleteConfirmation = false
                    },
                    onCancel: {
                        showDeleteConfirmation = false
                    }
                )
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
                        PremiumFeatureRow(icon: "tag", text: String(localized: "Unlimited tags"))
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

            // Redeem Promo Code
            Button {
                Task {
                    if let windowScene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first {
                        do {
                            try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                        } catch {
                            // User cancelled or error occurred - no action needed
                        }
                    }
                }
            } label: {
                Label(String(localized: "Redeem Promo Code"), systemImage: "giftcard")
            }
        } header: {
            Text(String(localized: "Subscription"))
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

    // MARK: - Data Management Section

    @ViewBuilder
    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "Delete All My Data"), systemImage: "trash")
            }
        } header: {
            Text(String(localized: "Data Management"))
        } footer: {
            Text(String(localized: "This will permanently delete all your people, encounters, and photos. This action cannot be undone."))
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

            Button {
                Task {
                    isLoadingDemoData = true
                    DemoDataService.clearAllData(modelContext: modelContext)
                    await DemoDataService.seedDemoData(modelContext: modelContext)
                    isLoadingDemoData = false
                }
            } label: {
                HStack {
                    Label("Load Demo Data", systemImage: "square.and.arrow.down")
                    Spacer()
                    if isLoadingDemoData {
                        ProgressView()
                    }
                }
            }
            .foregroundStyle(AppColors.teal)
            .disabled(isLoadingDemoData)

            Button {
                DemoDataService.clearAllData(modelContext: modelContext)
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
            .foregroundStyle(AppColors.error)
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug options for testing. Load Demo Data will clear existing data and add sample profiles and encounters for App Store screenshots.")
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
        let photoCount = encounters.reduce(0) { $0 + max(1, ($1.photos ?? []).count) }
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

// MARK: - Delete Confirmation View

struct DeleteConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.warning)
                    .padding(.top, 32)

                // Warning text
                VStack(spacing: 12) {
                    Text(String(localized: "Delete All Data?"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(String(localized: "This will permanently delete all your people, encounters, photos, and practice history. This cannot be undone."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Swipe to confirm
                SwipeToConfirmBar {
                    onConfirm()
                }
                .padding(.horizontal, 24)

                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Swipe to Confirm Bar

struct SwipeToConfirmBar: View {
    let onConfirm: () -> Void

    private let trackHeight: CGFloat = 60
    private let thumbSize: CGFloat = 52
    private let thumbPadding: CGFloat = 4

    @State private var dragOffset: CGFloat = 0
    @State private var confirmed = false

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticHeavy = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - thumbSize - thumbPadding * 2
            let progress = min(max(dragOffset / maxOffset, 0), 1)

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.red.opacity(0.12 + 0.18 * progress))
                    .overlay {
                        RoundedRectangle(cornerRadius: trackHeight / 2)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                    }

                // Label
                Text(String(localized: "Slide to Delete"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red.opacity(Double(max(0, 1 - progress * 2.5))))
                    .frame(maxWidth: .infinity)

                // Draggable thumb
                Circle()
                    .fill(confirmed ? Color.red : Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .overlay {
                        Image(systemName: confirmed ? "checkmark" : "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(confirmed ? .white : .red)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(.leading, thumbPadding)
                    .offset(x: confirmed ? maxOffset : dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !confirmed else { return }
                                dragOffset = min(max(value.translation.width, 0), maxOffset)
                            }
                            .onEnded { _ in
                                guard !confirmed else { return }
                                if progress > 0.85 {
                                    confirmed = true
                                    hapticHeavy.notificationOccurred(.success)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = maxOffset
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        onConfirm()
                                    }
                                } else {
                                    hapticLight.impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Slide to delete all data"))
        .accessibilityHint(String(localized: "Double-tap to confirm deletion"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onConfirm()
        }
    }
}

#Preview {
    AccountView()
}
