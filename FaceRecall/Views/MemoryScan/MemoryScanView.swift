import SwiftUI
import SwiftData
import AVFoundation

/// Full-screen live camera scan for identifying people
/// Free tier feature - creates encounters when user confirms a match
///
/// Privacy:
/// - All image processing is ephemeral
/// - Frames are discarded immediately after best frame selection
/// - No images are stored
/// - Encounter creation is optional and stores only metadata
struct MemoryScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]

    @State private var viewModel = MemoryScanViewModel()
    @StateObject private var cameraManager = SilentScanCameraManager()
    @State private var showConfirmation = false
    @State private var selectedMatch: MatchSuggestion?
    @State private var scanDelegate: ScanDelegate?

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewRepresentable(session: cameraManager.session)
                .ignoresSafeArea()

            // Overlay based on state
            switch viewModel.scanState {
            case .idle:
                idleOverlay
            case .scanning:
                scanningOverlay
            case .processing:
                processingOverlay
            case .results(let faceResults):
                // For live scan, use first face result (camera typically captures one face)
                let suggestions = faceResults.first?.suggestions ?? []
                resultsOverlay(suggestions: suggestions)
            case .noFaceDetected:
                noFaceOverlay
            case .error(let message):
                errorOverlay(message: message)
            }

            // Close button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            setupCameraDelegate()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
            viewModel.reset()
        }
        .alert("Create Encounter?", isPresented: $showConfirmation, presenting: selectedMatch) { match in
            Button("Yes, I met \(match.person.name)") {
                createEncounter(for: match.person)
            }
            Button("Cancel", role: .cancel) {
                selectedMatch = nil
            }
        } message: { match in
            Text("This will record that you met \(match.person.name) today. No photo will be saved.")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var idleOverlay: some View {
        VStack {
            Spacer()

            // Instruction text
            Text("Point camera at a face")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Spacer()

            // Bottom controls
            HStack(spacing: 40) {
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 50, height: 50)

                // Scan button
                Button {
                    startScan()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(AppColors.teal)
                            .frame(width: 66, height: 66)

                        Image(systemName: "eye")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }

                // Flip camera button
                Button {
                    cameraManager.flipCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Flip Camera")
                .accessibilityHint("Switch between front and back camera")
            }
            .padding(.bottom, 60)
        }
    }

    @ViewBuilder
    private var scanningOverlay: some View {
        VStack {
            Spacer()

            // Progress indicator
            VStack(spacing: 12) {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(.linear)
                    .tint(AppColors.teal)
                    .frame(width: 200)

                Text("Scanning...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Cancel button
            Button("Cancel") {
                cameraManager.cancelScan()
                viewModel.reset()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 60)
        }
    }

    @ViewBuilder
    private var processingOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Identifying...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
    }

    @ViewBuilder
    private func resultsOverlay(suggestions: [MatchSuggestion]) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text(suggestions.isEmpty ? "No Matches" : "Possible Matches")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.reset()
                    } label: {
                        Text("Scan Again")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.teal)
                    }
                }

                if suggestions.isEmpty {
                    NoMatchesView()
                } else {
                    // Match cards
                    ForEach(suggestions) { suggestion in
                        MatchResultCard(
                            suggestion: suggestion,
                            showConfirmButton: true,
                            onConfirm: {
                                selectedMatch = suggestion
                                showConfirmation = true
                            }
                        )
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }

    @ViewBuilder
    private var noFaceOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                NoFaceDetectedView(onRetry: {
                    viewModel.reset()
                })
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }

    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                ScanErrorView(message: message, onRetry: {
                    viewModel.reset()
                })
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }

    // MARK: - Actions

    private func setupCameraDelegate() {
        let delegate = ScanDelegate(viewModel: viewModel, people: people)
        scanDelegate = delegate
        cameraManager.delegate = delegate
    }

    private func startScan() {
        viewModel.startScanning()
        cameraManager.startScan()
    }

    private func createEncounter(for person: Person) {
        // Create minimal encounter (no image data per privacy guidelines)
        let encounter = Encounter(
            occasion: "Met \(person.name)",
            date: Date()
        )

        encounter.people.append(person)
        person.encounters.append(encounter)

        modelContext.insert(encounter)
        try? modelContext.save()

        // Reset and dismiss
        viewModel.reset()
        dismiss()
    }
}

// MARK: - Camera Delegate Wrapper

private class ScanDelegate: NSObject, SilentScanCameraManagerDelegate {
    let viewModel: MemoryScanViewModel
    let people: [Person]

    init(viewModel: MemoryScanViewModel, people: [Person]) {
        self.viewModel = viewModel
        self.people = people
    }

    func cameraManagerDidFinishScanning(_ manager: SilentScanCameraManager, bestFrame: UIImage?) {
        Task { @MainActor in
            guard let image = bestFrame else {
                viewModel.scanState = .noFaceDetected
                return
            }

            await viewModel.processImageEphemerally(image, people: people)
        }
    }

    func cameraManagerDidUpdateProgress(_ manager: SilentScanCameraManager, progress: Double) {
        Task { @MainActor in
            viewModel.updateProgress(progress)
        }
    }
}

#Preview {
    MemoryScanView()
        .modelContainer(for: Person.self, inMemory: true)
}
