import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var encounters: [Encounter]
    @Query private var people: [Person]
    @Query private var embeddings: [FaceEmbedding]

    private var settings = AppSettings.shared

    @State private var showSignInSheet = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                subscriptionSection
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignInSheet) {
                SignInSheet()
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
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button("Sign Out") {
                        // TODO: Implement sign out
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.coral)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Sign in to sync your data across devices")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)

                    Button {
                        showSignInSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Sign In")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Label("Local Storage", systemImage: "internaldrive")
                        .font(.headline)
                    Text("Face embeddings and photos are stored only in the app's private storage on your device.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("No Cloud Sync", systemImage: "icloud.slash")
                        .font(.headline)
                    Text("Your data is not synced to iCloud or any cloud service. If you delete the app, all data is permanently removed.")
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
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Sign In Sheet

struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coral.opacity(0.15), AppColors.teal.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "face.smiling")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.coral, AppColors.teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Sign in to Remet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Sync your data across all your devices")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Apple Sign In
                    Button {
                        // TODO: Implement Apple Sign In
                        // Use AuthenticationServices framework
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Continue with Apple")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Google Sign In
                    Button {
                        // TODO: Implement Google Sign In
                        // Use GoogleSignIn SDK
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)

                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Settings") {
    SettingsView()
}

#Preview("Sign In") {
    SignInSheet()
}
