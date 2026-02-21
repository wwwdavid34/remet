import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var encounters: [Encounter]
    @Query private var people: [Person]
    @Query private var embeddings: [FaceEmbedding]

    private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                displaySection
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            // TODO: Replace with actual subscription state
            let isPremium = false

            if isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppColors.warmYellow)
                    Text("Premium Active")
                        .fontWeight(.medium)
                    Spacer()
                    Text("Manage")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.teal)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(AppColors.warmYellow)
                        Text("Upgrade to Premium")
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        PremiumFeatureRow(icon: "icloud", text: "Cloud sync across devices")
                        PremiumFeatureRow(icon: "infinity", text: "Unlimited people & encounters")
                        PremiumFeatureRow(icon: "chart.bar", text: "Advanced analytics")
                        PremiumFeatureRow(icon: "calendar.badge.clock", text: "Calendar integration")
                    }

                    Button {
                        // TODO: Show subscription options
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

    // MARK: - Photo Storage Section

    @ViewBuilder
    private var photoStorageSection: some View {
        Section {
            Picker("Photo Quality", selection: Binding(
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

                Text("Resolution: \(Int(settings.photoResolution))px")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)

            Toggle("Save Photos to Camera Roll", isOn: Binding(
                get: { settings.savePhotosToCameraRoll },
                set: { settings.savePhotosToCameraRoll = $0 }
            ))
        } header: {
            Text("Photo Storage")
        } footer: {
            Text("Higher quality uses more storage but preserves more detail. When enabled, photos taken with Remet are also saved to your Photos app.")
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

            Toggle("Show Face Boxes", isOn: Binding(
                get: { settings.showBoundingBoxes },
                set: { settings.showBoundingBoxes = $0 }
            ))
        } header: {
            Text("Face Matching")
        } footer: {
            Text("Faces matched above the threshold are automatically labeled. Face boxes are always shown when editing.")
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
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                PrivacyInfoView()
            } label: {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
    }

    // MARK: - Developer Section (Debug Only)

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        Section {
            Button {
                settings.hasCompletedOnboarding = false
                RemetApp.scheduleTipKitReset()
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

struct StorageRow: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }
}

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("On-Device Processing", systemImage: "iphone")
                        .font(.headline)
                    Text("All face detection and recognition happens entirely on your device. Your photos and face data are never uploaded to any server.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Local-First Storage", systemImage: "internaldrive")
                        .font(.headline)
                    Text("Face embeddings and photos are stored in the app's private storage on your device. No biometric data is ever uploaded to our servers.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Optional iCloud Sync", systemImage: "icloud.fill")
                        .font(.headline)
                    Text("Premium users can sync data via iCloud, stored in your private CloudKit container. This data is encrypted and accessible only to your Apple ID. We cannot access your iCloud data.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("No Tracking", systemImage: "hand.raised.fill")
                        .font(.headline)
                    Text("No advertising or analytics SDKs are integrated. No device fingerprinting or user profiling. Your data is used solely to help you remember people.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Photo Library Access", systemImage: "photo.on.rectangle")
                        .font(.headline)
                    Text("The app requests access to your photo library only to scan for faces. Photos are copied into the app for offline access.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Premium Feature Row

struct PremiumFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.teal)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Settings") {
    SettingsView()
}
