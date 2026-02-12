import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
import Photos

// MARK: - Face Assignment Model

struct QuickCaptureFaceAssignment: Identifiable {
    let id = UUID()
    let detectedFace: DetectedFace
    var matchSuggestions: [MatchResult] = []
    var assignedPerson: Person? = nil
    var isNewPerson = false
    var newPersonName: String? = nil
    var isProcessing = false

    var isAssigned: Bool {
        assignedPerson != nil || (isNewPerson && newPersonName != nil)
    }

    var displayName: String? {
        if let person = assignedPerson {
            return person.name
        }
        return newPersonName
    }
}

// MARK: - Quick Capture View

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
    @State private var pendingSave: (context: String?, location: String?, assignments: [QuickCaptureFaceAssignment])?
    @StateObject private var locationManager = LocationManager()

    private let limitChecker = LimitChecker()

    private var limitStatus: LimitChecker.LimitStatus {
        limitChecker.canAddPerson(currentCount: people.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if limitStatus.isBlocked {
                    LimitReachedView {
                        showPaywall = true
                    }
                } else if let image = capturedImage {
                    QuickCaptureReviewView(
                        image: image,
                        detectedFaces: $detectedFaces,
                        existingPeople: people.filter { !($0.embeddings ?? []).isEmpty },
                        location: capturedLocation,
                        onSave: { context, locationName, assignments in
                            if !AppSettings.shared.hasShownCameraRollHint {
                                pendingSave = (context, locationName, assignments)
                                showCameraRollHint = true
                            } else {
                                if AppSettings.shared.savePhotosToCameraRoll {
                                    savePhotoToCameraRoll(image, location: capturedLocation)
                                }
                                saveEncounter(context: context, locationName: locationName, assignments: assignments)
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
                    if let image = capturedImage {
                        savePhotoToCameraRoll(image, location: capturedLocation)
                    }
                    if let save = pendingSave {
                        saveEncounter(context: save.context, locationName: save.location, assignments: save.assignments)
                    }
                    pendingSave = nil
                }
                Button("No Thanks", role: .cancel) {
                    AppSettings.shared.hasShownCameraRollHint = true
                    if let save = pendingSave {
                        saveEncounter(context: save.context, locationName: save.location, assignments: save.assignments)
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

    private func savePhotoToCameraRoll(_ image: UIImage, location: CLLocation?) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }

            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if let imageData = image.jpegData(compressionQuality: 1.0) {
                    request.addResource(with: .photo, data: imageData, options: nil)
                }
                if let location = location {
                    request.location = location
                }
                request.creationDate = Date()
            } completionHandler: { _, error in
                if let error = error {
                    print("Error saving photo to camera roll: \(error)")
                }
            }
        }
    }

    // MARK: - Unified Save

    private func saveEncounter(context: String?, locationName: String?, assignments: [QuickCaptureFaceAssignment]) {
        guard capturedImage != nil else { return }
        isProcessing = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                var createdPeople: [(person: Person, faceAssignment: QuickCaptureFaceAssignment)] = []
                var existingPeople: [(person: Person, faceAssignment: QuickCaptureFaceAssignment)] = []

                // Process each assigned face
                for assignment in assignments where assignment.isAssigned {
                    if assignment.isNewPerson, let name = assignment.newPersonName {
                        // Create new person
                        let person = Person(name: name, contextTag: context)
                        if let locationName = locationName, !locationName.isEmpty {
                            person.howWeMet = "Met at \(locationName)"
                        }
                        let srData = SpacedRepetitionData()
                        srData.person = person
                        person.spacedRepetitionData = srData
                        createdPeople.append((person, assignment))
                    } else if let person = assignment.assignedPerson {
                        existingPeople.append((person, assignment))
                    }
                }

                // Generate embeddings and link to people
                var allPeople: [Person] = []
                var embeddingResults: [(embedding: FaceEmbedding, person: Person, assignmentIndex: Int)] = []

                for (person, assignment) in createdPeople + existingPeople {
                    let faceImage = assignment.detectedFace.cropImage
                    let embedding = try await embeddingService.generateEmbedding(for: faceImage)
                    if let faceData = faceImage.jpegData(compressionQuality: 0.8) {
                        let faceEmbedding = FaceEmbedding(
                            vector: embedding.withUnsafeBytes { Data($0) },
                            faceCropData: faceData
                        )
                        faceEmbedding.person = person
                        person.embeddings = (person.embeddings ?? []) + [faceEmbedding]

                        if let idx = assignments.firstIndex(where: { $0.id == assignment.id }) {
                            embeddingResults.append((faceEmbedding, person, idx))
                        }
                    }
                    if !allPeople.contains(where: { $0.id == person.id }) {
                        allPeople.append(person)
                    }
                }

                // Prepare encounter image
                let settings = AppSettings.shared
                let resizedImage = resizeImage(capturedImage!, targetSize: settings.photoTargetSize)
                guard let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) else {
                    await MainActor.run { isProcessing = false }
                    return
                }

                // Build bounding boxes for ALL faces (assigned and unassigned)
                var boundingBoxes: [FaceBoundingBox] = []
                for assignment in assignments {
                    let person = assignment.assignedPerson ?? createdPeople.first(where: { $0.faceAssignment.id == assignment.id })?.person
                    let box = FaceBoundingBox(
                        rect: assignment.detectedFace.normalizedBoundingBox,
                        personId: person?.id,
                        personName: person?.name ?? assignment.newPersonName,
                        confidence: assignment.matchSuggestions.first?.similarity,
                        isAutoAccepted: false
                    )
                    boundingBoxes.append(box)
                }

                // Build occasion string
                let names = allPeople.map { $0.name }
                let occasion: String?
                if names.isEmpty {
                    occasion = context
                } else if names.count == 1 {
                    occasion = "Met \(names[0])"
                } else {
                    occasion = "Met \(names.dropLast().joined(separator: ", ")) & \(names.last!)"
                }

                let encounter = Encounter(
                    imageData: imageData,
                    occasion: occasion,
                    location: locationName,
                    latitude: capturedLocation?.coordinate.latitude,
                    longitude: capturedLocation?.coordinate.longitude,
                    date: Date()
                )
                encounter.faceBoundingBoxes = boundingBoxes

                // Link people to encounter
                for person in allPeople {
                    encounter.people = (encounter.people ?? []) + [person]
                    person.encounters = (person.encounters ?? []) + [encounter]
                    person.lastSeenAt = Date()
                }

                // Link embeddings to encounter and set profile photos
                for result in embeddingResults {
                    result.embedding.encounterId = encounter.id
                    if let box = boundingBoxes[safe: result.assignmentIndex] {
                        result.embedding.boundingBoxId = box.id
                    }
                    // Auto-assign profile photo for new people
                    if result.person.profileEmbeddingId == nil {
                        result.person.profileEmbeddingId = result.embedding.id
                    }
                }

                await MainActor.run {
                    for (person, _) in createdPeople {
                        modelContext.insert(person)
                    }
                    modelContext.insert(encounter)
                    try? modelContext.save()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error saving encounter: \(error)")
                }
            }
        }
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

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

// MARK: - Safe Array Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                    Button {
                        flashEnabled.toggle()
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }

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

// MARK: - Quick Capture Review (Tap-to-Assign)

struct QuickCaptureReviewView: View {
    let image: UIImage
    @Binding var detectedFaces: [DetectedFace]
    let existingPeople: [Person]
    let location: CLLocation?
    let onSave: (String?, String?, [QuickCaptureFaceAssignment]) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var faceAssignments: [QuickCaptureFaceAssignment] = []
    @State private var selectedFaceIndex: Int?
    @State private var contextNote = ""
    @State private var locationName = ""
    @State private var isLoadingLocation = false
    @State private var locateFaceMode = false
    @State private var isLocatingFace = false
    @State private var locateFaceError: String?
    @State private var lastAddedFaceIndex: Int?

    private let faceMatchingService = FaceMatchingService()
    private let faceEmbeddingService = FaceEmbeddingService()

    private var assignedCount: Int {
        faceAssignments.filter(\.isAssigned).count
    }

    private var canSave: Bool {
        assignedCount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Photo with tappable face boxes
            photoWithFaceOverlay

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    faceStatusBar

                    if locateFaceMode {
                        locateFaceModeIndicator
                    }

                    if lastAddedFaceIndex != nil {
                        undoButton
                    }

                    // Context
                    TextField("Context (e.g., Met at conference)", text: $contextNote)
                        .textFieldStyle(.roundedBorder)

                    // Location
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

                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Retake") {
                            onRetake()
                        }
                        .buttonStyle(.bordered)

                        Button("Save Encounter") {
                            onSave(
                                contextNote.isEmpty ? nil : contextNote,
                                locationName.isEmpty ? nil : locationName,
                                faceAssignments
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            initializeFaceAssignments()
            reverseGeocodeIfNeeded()
        }
        .onChange(of: detectedFaces.count) { _, _ in
            syncFaceAssignments()
        }
        .sheet(isPresented: Binding(
            get: { selectedFaceIndex != nil },
            set: { if !$0 { selectedFaceIndex = nil } }
        )) {
            if let index = selectedFaceIndex, index < faceAssignments.count {
                FaceAssignmentSheet(
                    assignment: $faceAssignments[index],
                    existingPeople: existingPeople,
                    onDismiss: { selectedFaceIndex = nil }
                )
            }
        }
    }

    // MARK: - Photo Overlay

    @ViewBuilder
    private var photoWithFaceOverlay: some View {
        GeometryReader { geometry in
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
                .overlay {
                    // Face box overlays — matching FaceBoundingBoxOverlay style
                    ForEach(faceAssignments.indices, id: \.self) { index in
                        faceBoxOverlay(at: index, in: geometry.size)
                    }
                    .allowsHitTesting(!locateFaceMode)
                }
        }
        .frame(maxHeight: 350)
    }

    @ViewBuilder
    private func faceBoxOverlay(at index: Int, in viewSize: CGSize) -> some View {
        let assignment = faceAssignments[index]
        let imageSize = image.size
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        let rect = assignment.detectedFace.normalizedBoundingBox
        let boxWidth = rect.width * scaledWidth
        let boxHeight = rect.height * scaledHeight
        let boxX = offsetX + rect.midX * scaledWidth
        let boxY = offsetY + (1 - rect.midY) * scaledHeight

        let isSelected = selectedFaceIndex == index
        let boxColor = faceBoxColor(for: assignment)

        // Minimum 44pt tap target
        let tapWidth = max(boxWidth, 44)
        let tapHeight = max(boxHeight, 44)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isSelected ? 3 : 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(boxColor.opacity(0.1))
                )
                .frame(width: boxWidth, height: boxHeight)

            if let name = assignment.displayName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(boxColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .offset(y: 16)
            }
        }
        .frame(width: tapWidth, height: tapHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFaceIndex = index
        }
        .position(x: boxX, y: boxY)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func faceBoxColor(for assignment: QuickCaptureFaceAssignment) -> Color {
        if assignment.isProcessing {
            return AppColors.teal
        } else if assignment.isAssigned {
            return assignment.isNewPerson ? .green : .blue
        } else {
            return .orange
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var faceStatusBar: some View {
        HStack {
            if faceAssignments.isEmpty {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(AppColors.warning)
                Text("No face detected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.warning)
            } else {
                Image(systemName: assignedCount > 0 ? "checkmark.circle" : "face.smiling")
                    .foregroundStyle(assignedCount > 0 ? .green : .secondary)

                let faceText = "\(faceAssignments.count) face\(faceAssignments.count == 1 ? "" : "s")"
                let assignedText = "\(assignedCount) identified"
                Text("\(faceText) \u{00B7} \(assignedText)")
                    .font(.subheadline)
                    .foregroundStyle(assignedCount > 0 ? .green : .secondary)
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
                        Image(systemName: locateFaceMode ? "xmark.circle" : "person.crop.rectangle")
                    }
                    Text(locateFaceMode ? "Cancel" : "Missing?")
                }
                .font(.caption)
                .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
            }
            .disabled(isLocatingFace)
        }
    }

    @ViewBuilder
    private var locateFaceModeIndicator: some View {
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

    @ViewBuilder
    private var undoButton: some View {
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

    // MARK: - Face Processing

    private func initializeFaceAssignments() {
        faceAssignments = detectedFaces.map { QuickCaptureFaceAssignment(detectedFace: $0) }
        processAllFaces()
        reverseGeocodeIfNeeded()
    }

    private func syncFaceAssignments() {
        // Add new faces that aren't already tracked
        let existingFaceCount = faceAssignments.count
        if detectedFaces.count > existingFaceCount {
            for i in existingFaceCount..<detectedFaces.count {
                var newAssignment = QuickCaptureFaceAssignment(detectedFace: detectedFaces[i])
                newAssignment.isProcessing = true
                faceAssignments.append(newAssignment)
                processface(at: faceAssignments.count - 1)
            }
        }
    }

    private func processAllFaces() {
        for i in faceAssignments.indices {
            faceAssignments[i].isProcessing = true
            processface(at: i)
        }
    }

    private func processface(at index: Int) {
        guard index < faceAssignments.count else { return }
        let faceImage = faceAssignments[index].detectedFace.cropImage

        Task {
            do {
                let embedding = try await faceEmbeddingService.generateEmbedding(for: faceImage)
                let matches = faceMatchingService.findMatches(
                    for: embedding,
                    in: existingPeople,
                    topK: 3,
                    threshold: 0.65
                )

                await MainActor.run {
                    guard index < faceAssignments.count else { return }
                    faceAssignments[index].matchSuggestions = matches
                    faceAssignments[index].isProcessing = false
                    autoTriggerIfSingleFace()
                }
            } catch {
                await MainActor.run {
                    guard index < faceAssignments.count else { return }
                    faceAssignments[index].isProcessing = false
                    autoTriggerIfSingleFace()
                }
            }
        }
    }

    private func autoTriggerIfSingleFace() {
        // Auto-open assignment sheet when exactly 1 face and all done processing
        guard faceAssignments.count == 1,
              !faceAssignments[0].isProcessing,
              !faceAssignments[0].isAssigned,
              selectedFaceIndex == nil else { return }
        selectedFaceIndex = 0
    }

    // MARK: - Location

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

    // MARK: - Locate Face

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        isLocatingFace = true
        locateFaceError = nil

        Task {
            do {
                let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let offsetX = (viewSize.width - scaledWidth) / 2
                let offsetY = (viewSize.height - scaledHeight) / 2

                let imageX = (tapLocation.x - offsetX) / scale
                let imageY = (tapLocation.y - offsetY) / scale

                let cropSize = min(imageSize.width, imageSize.height) * 0.4
                let cropRect = CGRect(
                    x: max(0, imageX - cropSize / 2),
                    y: max(0, imageY - cropSize / 2),
                    width: min(cropSize, imageSize.width - max(0, imageX - cropSize / 2)),
                    height: min(cropSize, imageSize.height - max(0, imageY - cropSize / 2))
                )

                guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                    await MainActor.run {
                        locateFaceError = "Could not crop image region"
                        isLocatingFace = false
                    }
                    return
                }
                let croppedImage = UIImage(cgImage: cgImage)

                let faceDetectionService = FaceDetectionService()
                let faces = try await faceDetectionService.detectFaces(in: croppedImage, options: .enhanced)

                if let face = faces.first {
                    let cropNormRect = face.normalizedBoundingBox
                    let originalX = (cropRect.origin.x + cropNormRect.origin.x * cropRect.width) / imageSize.width
                    let originalWidth = (cropNormRect.width * cropRect.width) / imageSize.width
                    let cropBottomNorm = 1.0 - (cropRect.origin.y + cropRect.height) / imageSize.height
                    let cropHeightNorm = cropRect.height / imageSize.height
                    let originalY = cropBottomNorm + cropNormRect.origin.y * cropHeightNorm
                    let originalHeight = cropNormRect.height * cropHeightNorm

                    let translatedNormRect = CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight)
                    let translatedPixelRect = CGRect(
                        x: originalX * imageSize.width,
                        y: (1.0 - originalY - originalHeight) * imageSize.height,
                        width: originalWidth * imageSize.width,
                        height: originalHeight * imageSize.height
                    )

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
        if index < faceAssignments.count {
            faceAssignments.remove(at: index)
        }
        lastAddedFaceIndex = nil
    }
}

// MARK: - Face Assignment Sheet

struct FaceAssignmentSheet: View {
    @Binding var assignment: QuickCaptureFaceAssignment
    let existingPeople: [Person]
    let onDismiss: () -> Void

    @State private var newPersonName = ""
    @State private var showNameInput = false
    @State private var showPeoplePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Face crop
                    Image(uiImage: assignment.detectedFace.cropImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 4)

                    if assignment.isAssigned {
                        currentAssignmentView
                    } else if assignment.isProcessing {
                        ProgressView("Analyzing face...")
                    } else {
                        assignmentOptionsView
                    }
                }
                .padding()
            }
            .navigationTitle("Identify Face")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
            .sheet(isPresented: $showPeoplePicker) {
                peoplePickerSheet
            }
        }
    }

    // MARK: - Current Assignment

    @ViewBuilder
    private var currentAssignmentView: some View {
        VStack(spacing: 16) {
            HStack {
                if let person = assignment.assignedPerson,
                   let embedding = person.profileEmbedding,
                   let uiImage = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.teal.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(AppColors.teal)
                        }
                }

                VStack(alignment: .leading) {
                    Text(assignment.displayName ?? "")
                        .font(.headline)
                    if assignment.isNewPerson {
                        Text("New person")
                            .font(.caption)
                            .foregroundStyle(AppColors.teal)
                    } else {
                        Text("Existing person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button {
                    // Clear assignment
                    assignment.assignedPerson = nil
                    assignment.isNewPerson = false
                    assignment.newPersonName = nil
                } label: {
                    Label("Remove", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.coral)
            }
        }
    }

    // MARK: - Assignment Options

    @ViewBuilder
    private var assignmentOptionsView: some View {
        VStack(spacing: 16) {
            // Match suggestions
            if !assignment.matchSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Possible matches")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.teal)

                    ForEach(assignment.matchSuggestions.prefix(3), id: \.person.id) { match in
                        matchSuggestionRow(for: match)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Add new person
            if showNameInput {
                newPersonInputView
            } else {
                Button {
                    showNameInput = true
                } label: {
                    Label("Add New Person", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Choose existing person
            if !existingPeople.isEmpty {
                Button {
                    showPeoplePicker = true
                } label: {
                    Label("Choose Existing Person", systemImage: "person.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Match Suggestion Row

    @ViewBuilder
    private func matchSuggestionRow(for match: MatchResult) -> some View {
        Button {
            assignment.assignedPerson = match.person
            assignment.isNewPerson = false
            assignment.newPersonName = nil
        } label: {
            HStack(spacing: 10) {
                if let embedding = match.person.profileEmbedding,
                   let uiImage = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.teal.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(AppColors.teal)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.person.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(confidenceLabel(match.confidence, similarity: match.similarity))
                        .font(.caption)
                        .foregroundStyle(confidenceColor(match.confidence))
                }

                Spacer()

                Text("\(Int(match.similarity * 100))%")
                    .font(.headline)
                    .foregroundStyle(confidenceColor(match.confidence))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - New Person Input

    @ViewBuilder
    private var newPersonInputView: some View {
        VStack(spacing: 12) {
            TextField("Name", text: $newPersonName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    newPersonName = ""
                    showNameInput = false
                }
                .buttonStyle(.bordered)

                Button("Confirm") {
                    let trimmed = newPersonName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    assignment.isNewPerson = true
                    assignment.newPersonName = trimmed
                    assignment.assignedPerson = nil
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - People Picker

    @ViewBuilder
    private var peoplePickerSheet: some View {
        NavigationStack {
            List(existingPeople) { person in
                Button {
                    assignment.assignedPerson = person
                    assignment.isNewPerson = false
                    assignment.newPersonName = nil
                    showPeoplePicker = false
                    onDismiss()
                } label: {
                    HStack(spacing: 12) {
                        if let embedding = person.profileEmbedding,
                           let uiImage = UIImage(data: embedding.faceCropData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                        }
                        Text(person.name)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Choose Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPeoplePicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func confidenceLabel(_ confidence: MatchConfidence, similarity: Float) -> String {
        switch confidence {
        case .high:
            return "High confidence · \(Int(similarity * 100))%"
        case .ambiguous:
            return "Possible match · \(Int(similarity * 100))%"
        case .none:
            return "Low confidence · \(Int(similarity * 100))%"
        }
    }

    private func confidenceColor(_ confidence: MatchConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .ambiguous: return .orange
        case .none: return .red
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

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
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

    func flipCamera() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        currentCameraPosition = currentCameraPosition == .back ? .front : .back

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
