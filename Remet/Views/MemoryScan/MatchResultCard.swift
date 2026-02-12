import SwiftUI

/// Shared result card for displaying match suggestions
/// Used by both MemoryScanView and EphemeralMatchView
struct MatchResultCard: View {
    let suggestion: MatchSuggestion
    var showConfirmButton: Bool = false
    var onConfirm: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Person thumbnail
            personThumbnail

            // Match info
            VStack(alignment: .leading, spacing: 4) {
                // Confidence badge
                Text(suggestion.confidenceText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(suggestion.confidenceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(suggestion.confidenceColor.opacity(0.15))
                    .clipShape(Capsule())

                // Person name
                Text(suggestion.person.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Similarity score
                Text(suggestion.similarityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Confirm button (only for live scan, not ephemeral match)
            if showConfirmButton, let onConfirm = onConfirm {
                Button {
                    onConfirm()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var personThumbnail: some View {
        if let embedding = suggestion.person.embeddings?.first,
           let image = UIImage(data: embedding.faceCropData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
        }
    }
}

/// Empty results view when no matches found
struct NoMatchesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.textSecondary)

            Text("No matches found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("This person doesn't match anyone in your contacts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// No face detected error view
struct NoFaceDetectedView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.warning)

            Text("No face detected")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Make sure a face is clearly visible and try again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let onRetry = onRetry {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.teal)
            }
        }
        .padding()
    }
}

/// Error view for scan failures
struct ScanErrorView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.coral)

            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let onRetry = onRetry {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.teal)
            }
        }
        .padding()
    }
}

#Preview("Match Result Card") {
    VStack(spacing: 16) {
        // Preview requires mock data
        Text("Match Result Cards")
            .font(.headline)
    }
    .padding()
}

#Preview("No Face Detected") {
    NoFaceDetectedView(onRetry: {})
}

#Preview("Scan Error") {
    ScanErrorView(message: "Camera access denied", onRetry: {})
}
