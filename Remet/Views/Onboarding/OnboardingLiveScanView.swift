import SwiftUI
import SwiftData
import AVFoundation

/// Onboarding step that guides user to try the Memory Scan feature
/// Demonstrates instant face recognition with their newly created profile
struct OnboardingLiveScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]

    let currentStep: Int
    let totalSteps: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var viewModel = MemoryScanViewModel()
    @StateObject private var cameraManager = SilentScanCameraManager()
    @State private var scanDelegate: OnboardingScanDelegate?
    @State private var matchedPerson: Person?
    @State private var showSuccess = false
    @State private var hasStartedScanning = false

    /// The user's "Me" profile
    private var meProfile: Person? {
        people.first { $0.isMe }
    }

    var body: some View {
        ZStack {
            // Camera preview (front camera)
            CameraPreviewRepresentable(session: cameraManager.session)
                .ignoresSafeArea()

            // Dark overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            if showSuccess {
                successOverlay
            } else {
                scanningContent
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
            viewModel.reset()
        }
    }

    // MARK: - Scanning Content

    @ViewBuilder
    private var scanningContent: some View {
        VStack(spacing: 24) {
            // Progress indicator
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.top, 16)

            // Header
            VStack(spacing: 8) {
                Text(String(localized: "Try Memory Scan"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(String(localized: "Point the camera at yourself to see instant face recognition in action!"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 60)

            Spacer()

            // Scan area indicator
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                    .foregroundStyle(AppColors.teal)
                    .frame(width: 250, height: 320)

                if case .scanning = viewModel.scanState {
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.scanProgress)
                            .progressViewStyle(.linear)
                            .tint(AppColors.teal)
                            .frame(width: 180)

                        Text(String(localized: "Scanning..."))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if case .processing = viewModel.scanState {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(String(localized: "Identifying..."))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.teal)

                        Text(String(localized: "Position your face here"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }

            Spacer()

            // Bottom controls
            VStack(spacing: 16) {
                if case .idle = viewModel.scanState {
                    Button {
                        startScan()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "eye")
                                .font(.title2)
                            Text(String(localized: "Scan My Face"))
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                } else if case .noFaceDetected = viewModel.scanState {
                    VStack(spacing: 12) {
                        Text(String(localized: "No face detected"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        Button {
                            viewModel.reset()
                        } label: {
                            Text(String(localized: "Try Again"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppColors.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                    }
                } else if case .results(let faceResults) = viewModel.scanState {
                    // Check if we matched "Me"
                    let _ = checkForMeMatch(faceResults: faceResults)
                }

                Button(action: onSkip) {
                    Text(String(localized: "Skip for Now"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Success Overlay

    @ViewBuilder
    private var successOverlay: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(AppColors.teal.opacity(0.2))
                    .frame(width: 160, height: 160)

                if let person = matchedPerson,
                   let embedding = person.profileEmbedding,
                   let image = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.teal, lineWidth: 4)
                        )
                }

                // Checkmark badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.teal)
                    .background(Circle().fill(.white).padding(4))
                    .offset(x: 45, y: 45)
            }

            // Success message
            VStack(spacing: 12) {
                Text(String(localized: "It's You!"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let person = matchedPerson {
                    Text(String(localized: "Recognized as \(person.name)"))
                        .font(.headline)
                        .foregroundStyle(AppColors.teal)
                }

                Text(String(localized: "Memory Scan can instantly identify anyone you've added. Just point your camera at them!"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()

            // Tip about hiding profile
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColors.warmYellow)
                    Text(String(localized: "Tip: You can hide your profile from the People list anytime in Settings."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                Button {
                    onComplete()
                } label: {
                    Text(String(localized: "Continue"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Methods

    private func setupCamera() {
        let delegate = OnboardingScanDelegate(
            viewModel: viewModel,
            people: people,
            onMeMatched: { person in
                matchedPerson = person
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSuccess = true
                }
            }
        )
        scanDelegate = delegate
        cameraManager.delegate = delegate
        cameraManager.startSession()

        // Switch to front camera for selfie scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cameraManager.flipCamera()
        }
    }

    private func startScan() {
        hasStartedScanning = true
        viewModel.startScanning()
        cameraManager.startScan()
    }

    private func checkForMeMatch(faceResults: [FaceMatchResult]) {
        // Check if any result matched "Me"
        for result in faceResults {
            for suggestion in result.suggestions {
                if suggestion.person.isMe {
                    matchedPerson = suggestion.person
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSuccess = true
                    }
                    return
                }
            }
        }

        // No match - show try again
        if !showSuccess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.reset()
            }
        }
    }
}

// MARK: - Onboarding Scan Delegate

private class OnboardingScanDelegate: NSObject, SilentScanCameraManagerDelegate {
    let viewModel: MemoryScanViewModel
    let people: [Person]
    let onMeMatched: (Person) -> Void

    init(viewModel: MemoryScanViewModel, people: [Person], onMeMatched: @escaping (Person) -> Void) {
        self.viewModel = viewModel
        self.people = people
        self.onMeMatched = onMeMatched
    }

    func cameraManagerDidFinishScanning(_ manager: SilentScanCameraManager, bestFrame: UIImage?) {
        Task { @MainActor in
            guard let image = bestFrame else {
                viewModel.scanState = .noFaceDetected
                return
            }

            await viewModel.processImageEphemerally(image, people: people)

            // Check for "Me" match
            if case .results(let faceResults) = viewModel.scanState {
                for result in faceResults {
                    for suggestion in result.suggestions {
                        if suggestion.person.isMe {
                            onMeMatched(suggestion.person)
                            return
                        }
                    }
                }
            }
        }
    }

    func cameraManagerDidUpdateProgress(_ manager: SilentScanCameraManager, progress: Double) {
        Task { @MainActor in
            viewModel.updateProgress(progress)
        }
    }
}

#Preview {
    OnboardingLiveScanView(currentStep: 2, totalSteps: 5, onComplete: {}, onSkip: {})
}
