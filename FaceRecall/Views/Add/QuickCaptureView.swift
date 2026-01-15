import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var capturedImage: UIImage?
    @State private var showingReview = false
    @State private var detectedFaces: [DetectedFace] = []
    @State private var isProcessing = false
    @State private var capturedLocation: CLLocation?
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = capturedImage {
                    QuickCaptureReviewView(
                        image: image,
                        detectedFaces: detectedFaces,
                        location: capturedLocation,
                        onSave: { name, context, locationName in
                            savePersonWithFace(name: name, context: context, locationName: locationName)
                        },
                        onRetake: {
                            capturedImage = nil
                            detectedFaces = []
                            capturedLocation = nil
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                } else {
                    CameraPreviewView(
                        onCapture: { image in
                            capturedImage = image
                            capturedLocation = locationManager.lastLocation
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

    private func savePersonWithFace(name: String, context: String?, locationName: String?) {
        guard capturedImage != nil else { return }
        isProcessing = true

        Task {
            do {
                // Create person with location info
                let person = Person(name: name, contextTag: context)

                // Store where we met this person
                if let locationName = locationName, !locationName.isEmpty {
                    person.howWeMet = "Met at \(locationName)"
                }

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

                // Create an encounter to record the meeting with GPS
                let encounter = Encounter(
                    occasion: "Met \(name)",
                    location: locationName,
                    latitude: capturedLocation?.coordinate.latitude,
                    longitude: capturedLocation?.coordinate.longitude,
                    date: Date()
                )
                encounter.people.append(person)
                person.encounters.append(encounter)

                await MainActor.run {
                    modelContext.insert(person)
                    modelContext.insert(encounter)
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
    let location: CLLocation?
    let onSave: (String, String?, String?) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var contextNote = ""
    @State private var locationName = ""
    @State private var isLoadingLocation = false
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
            .frame(maxHeight: 350)

            // Form
            ScrollView {
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

                    HStack {
                        Image(systemName: "mappin")
                            .foregroundStyle(.secondary)
                        if isLoadingLocation {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        TextField("Location (e.g., Coffee shop downtown)", text: $locationName)
                            .textFieldStyle(.roundedBorder)
                    }

                    if location != nil && locationName.isEmpty {
                        Text("GPS captured - add a location name above")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Retake") {
                            onRetake()
                        }
                        .buttonStyle(.bordered)

                        Button("Save") {
                            onSave(name, contextNote.isEmpty ? nil : contextNote, locationName.isEmpty ? nil : locationName)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.isEmpty || detectedFaces.isEmpty)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            nameFieldFocused = true
            reverseGeocodeIfNeeded()
        }
    }

    private func reverseGeocodeIfNeeded() {
        guard let location = location else { return }
        isLoadingLocation = true

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            isLoadingLocation = false
            if let placemark = placemarks?.first {
                var components: [String] = []
                if let name = placemark.name {
                    components.append(name)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if !components.isEmpty {
                    locationName = components.joined(separator: ", ")
                }
            }
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

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

#Preview {
    QuickCaptureView()
}
