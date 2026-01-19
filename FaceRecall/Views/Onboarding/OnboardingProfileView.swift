import SwiftUI
import SwiftData
import AVFoundation

struct OnboardingProfileView: View {
    @Environment(\.modelContext) private var modelContext

    let onComplete: (Person) -> Void
    let onSkip: () -> Void

    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var detectedFaces: [DetectedFace] = []
    @State private var isProcessing = false
    @State private var name = ""
    @State private var showNamePrompt = false
    @State private var errorMessage: String?
    @State private var showHideProfileTip = false
    @State private var createdPerson: Person?
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(String(localized: "Create Your Profile"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(localized: "Take a selfie so we know who you are. For best results, face the camera in a well-lit area. Your face will be excluded from practice quizzes."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)

            Spacer()

            // Camera/Photo area
            if let image = capturedImage {
                // Show captured selfie
                capturedImageView(image)
            } else if cameraPermissionStatus == .authorized || cameraPermissionStatus == .notDetermined {
                // Camera preview
                cameraPreviewArea
            } else {
                // Permission denied state
                permissionDeniedView
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if capturedImage != nil && !showNamePrompt {
                    // Retake / Continue buttons
                    HStack(spacing: 16) {
                        Button {
                            capturedImage = nil
                            detectedFaces = []
                        } label: {
                            Text(String(localized: "Retake"))
                                .font(.headline)
                                .foregroundStyle(AppColors.coral)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.coral.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            showNamePrompt = true
                        } label: {
                            Text(String(localized: "Continue"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(detectedFaces.isEmpty ? Color.gray : AppColors.coral)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(detectedFaces.isEmpty)
                    }
                } else if showNamePrompt {
                    // Name input
                    nameInputView
                } else if cameraPermissionStatus == .authorized {
                    // Capture button is in the camera preview
                } else {
                    // Skip button for permission denied
                    Button(action: onSkip) {
                        Text(String(localized: "Skip for Now"))
                            .font(.headline)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }

                // Always show skip option if not in name prompt
                if capturedImage == nil && !showNamePrompt {
                    Button(action: onSkip) {
                        Text(String(localized: "Skip for Now"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .onTapGesture {
            nameFieldFocused = false
        }
        .onAppear {
            checkCameraPermission()
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView(String(localized: "Processing..."))
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(String(localized: "Profile Created!"), isPresented: $showHideProfileTip) {
            Button(String(localized: "Got It")) {
                if let person = createdPerson {
                    onComplete(person)
                }
            }
        } message: {
            Text(String(localized: "Try the Memory Scan feature to instantly identify people you've added - just point your camera at them!\n\nTip: You can hide your profile from the People list in Settings."))
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var cameraPreviewArea: some View {
        ZStack {
            OnboardingCameraPreview(
                onCapture: { image in
                    capturedImage = image
                    detectFaces(in: image)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.coral.opacity(0.3), lineWidth: 2)
            )
        }
        .frame(width: 280, height: 350)
    }

    @ViewBuilder
    private func capturedImageView(_ image: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(detectedFaces.isEmpty ? AppColors.warning : AppColors.teal, lineWidth: 3)
                )

            if detectedFaces.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(String(localized: "No face detected. Please retake."))
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.warning)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "Face detected"))
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.teal)
            }
        }
    }

    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textMuted)

            Text(String(localized: "Camera Access Required"))
                .font(.headline)

            Text(String(localized: "To create your profile, we need access to your camera. You can enable this in Settings."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(String(localized: "Open Settings"))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.teal)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var nameInputView: some View {
        VStack(spacing: 16) {
            TextField(String(localized: "Your name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    nameFieldFocused = false
                }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }

            HStack(spacing: 16) {
                Button {
                    nameFieldFocused = false
                    showNamePrompt = false
                    name = ""
                } label: {
                    Text(String(localized: "Back"))
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    nameFieldFocused = false
                    saveProfile()
                } label: {
                    Text(String(localized: "Save"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(name.isEmpty ? Color.gray : AppColors.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(name.isEmpty)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nameFieldFocused = true
            }
        }
    }

    // MARK: - Methods

    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraPermissionStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionStatus = granted ? .authorized : .denied
                }
            }
        }
    }

    private func detectFaces(in image: UIImage) {
        isProcessing = true
        Task {
            do {
                let faceDetectionService = FaceDetectionService()
                let faces = try await faceDetectionService.detectFaces(in: image)
                await MainActor.run {
                    detectedFaces = faces
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    detectedFaces = []
                    isProcessing = false
                }
            }
        }
    }

    private func saveProfile() {
        guard !name.isEmpty, let image = capturedImage, let face = detectedFaces.first else {
            errorMessage = String(localized: "Please enter your name")
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // Create "Me" person
                let person = Person(name: name)
                person.isMe = true

                // Generate face embedding
                let embeddingService = FaceEmbeddingService()
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)

                if let faceData = face.cropImage.jpegData(compressionQuality: 0.8) {
                    let faceEmbedding = FaceEmbedding(
                        vector: embedding.withUnsafeBytes { Data($0) },
                        faceCropData: faceData
                    )
                    faceEmbedding.person = person
                    person.embeddings.append(faceEmbedding)
                    person.profileEmbeddingId = faceEmbedding.id
                }

                // Initialize spaced repetition data
                let srData = SpacedRepetitionData()
                srData.person = person
                person.spacedRepetitionData = srData

                await MainActor.run {
                    modelContext.insert(person)
                    try? modelContext.save()
                    isProcessing = false
                    createdPerson = person
                    showHideProfileTip = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(localized: "Failed to save profile. Please try again.")
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Onboarding Camera Preview (Front camera default)

struct OnboardingCameraPreview: View {
    let onCapture: (UIImage) -> Void

    @StateObject private var cameraManager = OnboardingCameraManager()

    var body: some View {
        ZStack {
            CameraPreviewRepresentable(session: cameraManager.session)

            VStack {
                Spacer()

                // Capture button
                Button {
                    cameraManager.capturePhoto { image in
                        if let image = image {
                            onCapture(image)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

// MARK: - Onboarding Camera Manager (Front camera default)

class OnboardingCameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?

    func startSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Use front camera for selfie
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(nil)
            return
        }
        captureCompletion?(image)
    }
}

#Preview {
    OnboardingProfileView(onComplete: { _ in }, onSkip: {})
}
