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
                photoStorageSection
                faceMatchingSection
                storageInfoSection
                aboutSection
            }
            .navigationTitle("Settings")
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

#Preview {
    SettingsView()
}
