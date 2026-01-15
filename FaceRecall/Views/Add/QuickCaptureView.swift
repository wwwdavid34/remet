import SwiftUI
import SwiftData
import AVFoundation

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var capturedImage: UIImage?
    @State private var showingReview = false
    @State private var detectedFaces: [DetectedFace] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = capturedImage {
                    QuickCaptureReviewView(
                        image: image,
                        detectedFaces: detectedFaces,
                        onSave: { name, context in
                            savePersonWithFace(name: name, context: context)
                        },
                        onRetake: {
                            capturedImage = nil
                            detectedFaces = []
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                } else {
                    CameraPreviewView(
                        onCapture: { image in
                            capturedImage = image
                            detectFaces(in: image)
                        }
                    )
                }

                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    ProgressView("Processing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
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

    private func savePersonWithFace(name: String, context: String?) {
        guard capturedImage != nil else { return }
        isProcessing = true

        Task {
            do {
                // Create person
                let person = Person(name: name, contextTag: context)

                // Get first detected face and create embedding
                if let detectedFace = detectedFaces.first {
                    let faceImage = detectedFace.cropImage
                    let embeddingService = FaceEmbeddingService()
                    let embedding = try await embeddingService.generateEmbedding(for: faceImage)
                    if let faceData = faceImage.jpegData(compressionQuality: 0.8) {
                        let faceEmbedding = FaceEmbedding(
                            vector: embedding.withUnsafeBytes { Data($0) },
                            faceCropData: faceData
                        )
                        faceEmbedding.person = person
                        person.embeddings.append(faceEmbedding)
                    }
                }

                // Initialize spaced repetition data
                let srData = SpacedRepetitionData()
                srData.person = person
                person.spacedRepetitionData = srData

                await MainActor.run {
                    modelContext.insert(person)
                    try? modelContext.save()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error saving person: \(error)")
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: View {
    let onCapture: (UIImage) -> Void

    @StateObject private var cameraManager = CameraManager()
    @State private var flashEnabled = false

    var body: some View {
        ZStack {
            CameraPreviewRepresentable(session: cameraManager.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 40) {
                    // Flash toggle
                    Button {
                        flashEnabled.toggle()
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }

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

                    // Flip camera
                    Button {
                        cameraManager.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                .padding(.bottom, 40)
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

// MARK: - Quick Capture Review

struct QuickCaptureReviewView: View {
    let image: UIImage
    let detectedFaces: [DetectedFace]
    let onSave: (String, String?) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var contextNote = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Image with face indicators
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Face detection overlays using normalized bounding box
                    ForEach(detectedFaces.indices, id: \.self) { index in
                        let face = detectedFaces[index]
                        let rect = face.normalizedBoundingBox
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(
                                width: rect.width * geometry.size.width,
                                height: rect.height * geometry.size.height
                            )
                            .position(
                                x: rect.midX * geometry.size.width,
                                y: (1 - rect.midY) * geometry.size.height
                            )
                    }
                }
            }
            .frame(maxHeight: 400)

            // Form
            VStack(spacing: 16) {
                if detectedFaces.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("No face detected. Try retaking the photo.")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("\(detectedFaces.count) face\(detectedFaces.count == 1 ? "" : "s") detected")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                TextField("Name (required)", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFieldFocused)

                TextField("Context (e.g., Met at conference)", text: $contextNote)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button("Retake") {
                        onRetake()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        onSave(name, contextNote.isEmpty ? nil : contextNote)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || detectedFaces.isEmpty)
                }
            }
            .padding()
        }
        .onAppear {
            nameFieldFocused = true
        }
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var captureCompletion: ((UIImage?) -> Void)?

    func startSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add camera input
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        // Add photo output
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

    func flipCamera() {
        session.beginConfiguration()

        // Remove current input
        session.inputs.forEach { session.removeInput($0) }

        // Switch position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        // Add new input
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        session.commitConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(nil)
            return
        }
        captureCompletion?(image)
    }
}

// MARK: - Camera Preview Representable

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            if let session = session {
                previewLayer.session = session
            }
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewLayer()
    }

    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

#Preview {
    QuickCaptureView()
}
