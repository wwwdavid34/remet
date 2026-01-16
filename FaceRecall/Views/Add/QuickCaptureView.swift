import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
import Photos

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]

    @State private var capturedImage: UIImage?
    @State private var showingReview = false
    @State private var detectedFaces: [DetectedFace] = []
    @State private var isProcessing = false
    @State private var capturedLocation: CLLocation?
    @State private var showPaywall = false
    @State private var showCameraRollHint = false
    @State private var pendingSave: (name: String, context: String?, location: String?)?
    @StateObject private var locationManager = LocationManager()

    private let limitChecker = LimitChecker()

    private var limitStatus: LimitChecker.LimitStatus {
        limitChecker.canAddPerson(currentCount: people.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Check if limit reached
                if limitStatus.isBlocked {
                    LimitReachedView {
                        showPaywall = true
                    }
                } else if let image = capturedImage {
                    QuickCaptureReviewView(
                        image: image,
                        detectedFaces: $detectedFaces,
                        location: capturedLocation,
                        onSave: { name, context, locationName in
                            // Check if we need to show the camera roll hint
                            if !AppSettings.shared.hasShownCameraRollHint {
                                pendingSave = (name, context, locationName)
                                showCameraRollHint = true
                            } else {
                                // Setting already configured, save directly
                                if AppSettings.shared.savePhotosToCameraRoll {
                                    savePhotoToCameraRoll(image, location: capturedLocation)
                                }
                                savePersonWithFace(name: name, context: context, locationName: locationName)
                            }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Save to Camera Roll?", isPresented: $showCameraRollHint) {
                Button("Yes, Save") {
                    AppSettings.shared.savePhotosToCameraRoll = true
                    AppSettings.shared.hasShownCameraRollHint = true
                    // Save current photo to camera roll with location
                    if let image = capturedImage {
                        savePhotoToCameraRoll(image, location: capturedLocation)
                    }
                    // Complete the pending save
                    if let save = pendingSave {
                        savePersonWithFace(name: save.name, context: save.context, locationName: save.location)
                    }
                    pendingSave = nil
                }
                Button("No Thanks", role: .cancel) {
                    AppSettings.shared.hasShownCameraRollHint = true
                    // Complete the pending save without camera roll
                    if let save = pendingSave {
                        savePersonWithFace(name: save.name, context: save.context, locationName: save.location)
                    }
                    pendingSave = nil
                }
            } message: {
                Text("Would you like this photo saved to your Camera Roll as well? Future photos will also be saved automatically. You can change this anytime in Settings.")
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

    /// Save photo to camera roll with GPS location metadata
    private func savePhotoToCameraRoll(_ image: UIImage, location: CLLocation?) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if let imageData = image.jpegData(compressionQuality: 1.0) {
                    request.addResource(with: .photo, data: imageData, options: nil)
                }
                // Set location metadata
                if let location = location {
                    request.location = location
                }
                // Set creation date to now
                request.creationDate = Date()
            } completionHandler: { success, error in
                if let error = error {
                    print("Error saving photo to camera roll: \(error)")
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

                // Prepare image data for encounter
                let settings = AppSettings.shared
                let resizedImage = resizeImage(capturedImage!, targetSize: settings.photoTargetSize)
                guard let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) else {
                    await MainActor.run {
                        isProcessing = false
                    }
                    return
                }

                // Create an encounter to record the meeting with GPS
                let encounter = Encounter(
                    imageData: imageData,
                    occasion: "Met \(name)",
                    location: locationName,
                    latitude: capturedLocation?.coordinate.latitude,
                    longitude: capturedLocation?.coordinate.longitude,
                    date: Date()
                )

                // Create bounding boxes for detected faces
                var boundingBoxes: [FaceBoundingBox] = []
                for (index, face) in detectedFaces.enumerated() {
                    let box = FaceBoundingBox(
                        rect: face.normalizedBoundingBox,
                        personId: index == 0 ? person.id : nil,
                        personName: index == 0 ? person.name : nil,
                        confidence: nil,
                        isAutoAccepted: false
                    )
                    boundingBoxes.append(box)
                }
                encounter.faceBoundingBoxes = boundingBoxes

                encounter.people.append(person)
                person.encounters.append(encounter)

                // Link embedding to encounter
                if let embedding = person.embeddings.first {
                    embedding.encounterId = encounter.id
                    // Auto-assign as profile photo
                    if person.profileEmbeddingId == nil {
                        person.profileEmbeddingId = embedding.id
                    }
                    if let firstBox = boundingBoxes.first {
                        embedding.boundingBoxId = firstBox.id
                    }
                }

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

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        // Only downscale, never upscale
        if ratio >= 1.0 {
            return image
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
    @Binding var detectedFaces: [DetectedFace]
    let location: CLLocation?
    let onSave: (String, String?, String?) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var contextNote = ""
    @State private var locationName = ""
    @State private var isLoadingLocation = false
    @State private var isLocatingFace = false
    @State private var locateFaceMode = false
    @State private var locateFaceError: String?
    @State private var lastAddedFaceIndex: Int?
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Image with face indicators
            GeometryReader { geometry in
                let imageSize = image.size
                let viewSize = geometry.size

                // Calculate scaledToFit dimensions and offset
                let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let offsetX = (viewSize.width - scaledWidth) / 2
                let offsetY = (viewSize.height - scaledHeight) / 2

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if locateFaceMode {
                                handleLocateFaceTap(at: location, in: geometry.size, imageSize: image.size)
                            }
                        }

                    // Face detection overlays using normalized bounding box
                    ForEach(detectedFaces.indices, id: \.self) { index in
                        let face = detectedFaces[index]
                        let rect = face.normalizedBoundingBox

                        // Convert normalized coordinates to view coordinates with offset
                        let boxWidth = rect.width * scaledWidth
                        let boxHeight = rect.height * scaledHeight
                        let boxX = offsetX + rect.midX * scaledWidth
                        let boxY = offsetY + (1 - rect.midY) * scaledHeight

                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: boxWidth, height: boxHeight)
                            .position(x: boxX, y: boxY)
                    }
                }
            }
            .frame(maxHeight: 350)

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    // Face detection status
                    HStack {
                        if detectedFaces.isEmpty {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(AppColors.warning)
                            Text("No face detected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.warning)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                            Text("\(detectedFaces.count) face\(detectedFaces.count == 1 ? "" : "s") detected")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        // Missing faces button
                        Button {
                            locateFaceMode.toggle()
                            if !locateFaceMode {
                                locateFaceError = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isLocatingFace {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: locateFaceMode ? "xmark.circle" : "face.viewfinder")
                                }
                                Text(locateFaceMode ? "Cancel" : "Missing?")
                            }
                            .font(.caption)
                            .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
                        }
                        .disabled(isLocatingFace)
                    }

                    // Locate face mode indicator
                    if locateFaceMode {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.tap")
                                Text("Tap where you see a face in the photo")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.coral)

                            if let error = locateFaceError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.warning)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.coral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Undo last added face button
                    if lastAddedFaceIndex != nil {
                        Button {
                            undoLastAddedFace()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo last added face")
                            }
                            .font(.caption)
                            .foregroundStyle(AppColors.warning)
                        }
                        .padding(.vertical, 4)
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

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        isLocatingFace = true
        locateFaceError = nil

        Task {
            do {
                // Calculate scale and offset for scaledToFit
                let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let offsetX = (viewSize.width - scaledWidth) / 2
                let offsetY = (viewSize.height - scaledHeight) / 2

                // Convert tap location to image coordinates
                let imageX = (tapLocation.x - offsetX) / scale
                let imageY = (tapLocation.y - offsetY) / scale

                // Define crop region (centered on tap, sized relative to image)
                let cropSize = min(imageSize.width, imageSize.height) * 0.4
                let cropRect = CGRect(
                    x: max(0, imageX - cropSize / 2),
                    y: max(0, imageY - cropSize / 2),
                    width: min(cropSize, imageSize.width - max(0, imageX - cropSize / 2)),
                    height: min(cropSize, imageSize.height - max(0, imageY - cropSize / 2))
                )

                // Crop the image
                guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                    await MainActor.run {
                        locateFaceError = "Could not crop image region"
                        isLocatingFace = false
                    }
                    return
                }
                let croppedImage = UIImage(cgImage: cgImage)

                // Run face detection on cropped region
                let faceDetectionService = FaceDetectionService()
                let faces = try await faceDetectionService.detectFaces(in: croppedImage, options: .enhanced)

                if let face = faces.first {
                    // Translate bounding box from cropped coordinates to original image coordinates
                    // cropRect is in top-left coords, Vision normalizedBoundingBox is bottom-left coords
                    let cropNormRect = face.normalizedBoundingBox

                    // X coordinate (no flip needed)
                    let originalX = (cropRect.origin.x + cropNormRect.origin.x * cropRect.width) / imageSize.width
                    let originalWidth = (cropNormRect.width * cropRect.width) / imageSize.width

                    // Y coordinate: convert from Vision (bottom-left) coords
                    let cropBottomNorm = 1.0 - (cropRect.origin.y + cropRect.height) / imageSize.height
                    let cropHeightNorm = cropRect.height / imageSize.height
                    let originalY = cropBottomNorm + cropNormRect.origin.y * cropHeightNorm
                    let originalHeight = cropNormRect.height * cropHeightNorm

                    // Create translated coordinates (Vision normalized coords)
                    let translatedNormRect = CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight)

                    // Convert to pixel coords using VNImageRectForNormalizedRect equivalent
                    let translatedPixelRect = CGRect(
                        x: originalX * imageSize.width,
                        y: (1.0 - originalY - originalHeight) * imageSize.height, // Flip for pixel coords
                        width: originalWidth * imageSize.width,
                        height: originalHeight * imageSize.height
                    )

                    // Create a new DetectedFace with translated coordinates
                    let newFace = DetectedFace(
                        boundingBox: translatedPixelRect,
                        cropImage: face.cropImage,
                        normalizedBoundingBox: translatedNormRect
                    )

                    await MainActor.run {
                        detectedFaces.append(newFace)
                        lastAddedFaceIndex = detectedFaces.count - 1
                        locateFaceMode = false
                        isLocatingFace = false
                    }
                } else {
                    await MainActor.run {
                        locateFaceError = "No face found at that location"
                        isLocatingFace = false
                    }
                }
            } catch {
                await MainActor.run {
                    locateFaceError = "Detection failed: \(error.localizedDescription)"
                    isLocatingFace = false
                }
            }
        }
    }

    private func undoLastAddedFace() {
        guard let index = lastAddedFaceIndex, index < detectedFaces.count else {
            lastAddedFaceIndex = nil
            return
        }

        detectedFaces.remove(at: index)
        lastAddedFaceIndex = nil
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
