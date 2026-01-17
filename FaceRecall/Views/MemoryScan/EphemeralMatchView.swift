import SwiftUI
import SwiftData
import PhotosUI

/// Photo picker-based face matching for premium users
/// Strictly read-only - no encounters, no persistence, no history
///
/// Privacy Invariants:
/// - NO encounter creation
/// - NO image persistence
/// - NO embedding persistence
/// - NO auto-learning
/// - Photo picker selection cleared after use
/// - Leaves no trace in the app
struct EphemeralMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]

    @State private var viewModel = MemoryScanViewModel()

    /// People with at least one embedding (required for matching)
    private var matchablePeople: [Person] {
        people.filter { !$0.embeddings.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.scanState {
                case .idle:
                    idleContent
                case .processing:
                    processingContent
                case .results(let suggestions):
                    resultsContent(suggestions: suggestions)
                case .noFaceDetected:
                    noFaceContent
                case .error(let message):
                    errorContent(message: message)
                case .scanning:
                    // Not used in ephemeral match
                    processingContent
                }
            }
            .navigationTitle("Quick Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
            if newValue != nil {
                Task {
                    await viewModel.processSelectedPhoto(people: matchablePeople)
                }
            }
        }
        .onDisappear {
            // Privacy invariant: reset all state
            viewModel.reset()
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.softPurple.opacity(0.2), AppColors.teal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.softPurple, AppColors.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Title and description
            VStack(spacing: 8) {
                Text("Quick Match")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Select a photo to identify a face without saving anything")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(AppColors.teal)
                Text("No data is saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColors.teal.opacity(0.1))
            .clipShape(Capsule())

            Spacer()

            // Photo picker button
            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("Select Photo")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppColors.softPurple, AppColors.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .disabled(matchablePeople.isEmpty)

            if matchablePeople.isEmpty {
                Text("Add people with face samples first")
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
            }

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var processingContent: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.teal)

            Text("Analyzing face...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    @ViewBuilder
    private func resultsContent(suggestions: [MatchSuggestion]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Scanned face preview (if available)
                if let faceCrop = viewModel.lastProcessedFaceCrop {
                    VStack(spacing: 8) {
                        Image(uiImage: faceCrop)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(AppColors.teal, lineWidth: 3)
                            }

                        Text("Scanned Face")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                }

                // Results section
                VStack(alignment: .leading, spacing: 12) {
                    Text(suggestions.isEmpty ? "No Matches Found" : "Possible Matches")
                        .font(.headline)
                        .padding(.horizontal)

                    if suggestions.isEmpty {
                        NoMatchesView()
                            .frame(maxWidth: .infinity)
                    } else {
                        // Read-only match cards (no confirm button)
                        ForEach(suggestions) { suggestion in
                            MatchResultCard(
                                suggestion: suggestion,
                                showConfirmButton: false
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                // Try another button
                Button {
                    viewModel.reset()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Another Photo")
                    }
                    .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.teal)
                .padding(.top, 8)

                // Privacy reminder
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.caption)
                    Text("This match was not saved")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var noFaceContent: some View {
        VStack(spacing: 24) {
            Spacer()

            NoFaceDetectedView(onRetry: {
                viewModel.reset()
            })

            Spacer()
        }
    }

    @ViewBuilder
    private func errorContent(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ScanErrorView(message: message, onRetry: {
                viewModel.reset()
            })

            Spacer()
        }
    }
}

#Preview {
    EphemeralMatchView()
        .modelContainer(for: Person.self, inMemory: true)
}
