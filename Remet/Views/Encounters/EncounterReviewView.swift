import SwiftUI
import SwiftData
import CoreLocation

struct EncounterReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let scannedPhoto: ScannedPhoto
    let people: [Person]
    let onSave: (Encounter) -> Void

    @State private var boundingBoxes: [FaceBoundingBox] = []
    @State private var selectedBoxIndex: Int?
    @State private var isProcessing = true
    @State private var occasion: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""

    @State private var showPersonPicker = false
    @State private var labelSearchText = ""
    @State private var showNewPersonSheet = false
    @State private var newPersonName = ""
    @State private var createdEmbeddings: [FaceEmbedding] = []
    @State private var createdPersons: [Person] = []

    // Face matching state for picker
    @State private var selectedFaceCrop: UIImage?
    @State private var potentialMatches: [MatchResult] = []
    @State private var isLoadingMatches = false
    // Locate face mode
    @State private var locateFaceMode = false
    @State private var locateFaceError: String?
    @State private var isLocatingFace = false
    @State private var lastAddedFaceIndex: Int?
    @State private var localDetectedFaces: [DetectedFace] = []

    // Zoom state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero

    // Focus state for name input


    private let scannerService = PhotoLibraryScannerService()
    private let faceDetectionService = FaceDetectionService()
    private var autoAcceptThreshold: Float { AppSettings.shared.autoAcceptThreshold }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoWithOverlays
                    facesSection
                    encounterDetailsSection
                }
                .padding()
            }
            .navigationTitle("Review Encounter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupCreatedPersons()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEncounter()
                    }
                    .disabled(isProcessing)
                }
            }
            .task {
                await processPhoto()
            }
            .sheet(isPresented: $showPersonPicker) {
                personPickerSheet
            }
            .sheet(isPresented: $showNewPersonSheet) {
                newPersonSheet
            }
        }
    }

    @ViewBuilder
    private var photoWithOverlays: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = scannedPhoto.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            ForEach(Array(boundingBoxes.enumerated()), id: \.element.id) { index, box in
                                FaceBoundingBoxOverlay(
                                    box: box,
                                    isSelected: selectedBoxIndex == index,
                                    imageSize: image.size,
                                    viewSize: geometry.size
                                )
                                .onTapGesture {
                                    if !locateFaceMode {
                                        selectedBoxIndex = index
                                        showPersonPicker = true
                                    }
                                }
                            }
                            .allowsHitTesting(!locateFaceMode)
                        }
                        .scaleEffect(zoomScale)
                        .offset(zoomOffset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = lastZoomScale * value.magnification
                                    zoomScale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastZoomScale = zoomScale
                                    if zoomScale <= 1.0 {
                                        withAnimation(.spring(duration: 0.3)) {
                                            zoomOffset = .zero
                                            lastDragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            zoomScale > 1.0 ?
                            DragGesture()
                                .onChanged { value in
                                    zoomOffset = CGSize(
                                        width: lastDragOffset.width + value.translation.width,
                                        height: lastDragOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastDragOffset = zoomOffset
                                }
                            : nil
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(duration: 0.3)) {
                                zoomScale = 1.0
                                lastZoomScale = 1.0
                                zoomOffset = .zero
                                lastDragOffset = .zero
                            }
                        }
                        .onTapGesture { location in
                            if locateFaceMode {
                                // Invert center-anchor scale + offset to get original view coordinates
                                let cx = geometry.size.width / 2
                                let cy = geometry.size.height / 2
                                let adjustedLocation = CGPoint(
                                    x: (location.x - zoomOffset.width - cx) / zoomScale + cx,
                                    y: (location.y - zoomOffset.height - cy) / zoomScale + cy
                                )
                                handleLocateFaceTap(
                                    at: adjustedLocation,
                                    in: geometry.size,
                                    imageSize: image.size
                                )
                            }
                        }
                }

                // Reset zoom button
                if zoomScale > 1.0 {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    zoomScale = 1.0
                                    lastZoomScale = 1.0
                                    zoomOffset = .zero
                                    lastDragOffset = .zero
                                }
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.caption)
                                    .padding(6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(scannedPhoto.image?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var facesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People in this photo")
                    .font(.headline)
                Spacer()

                // Missing faces button
                if !isProcessing {
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

            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Analyzing faces...")
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else if boundingBoxes.isEmpty {
                // No faces detected — prompt to use locate mode
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(AppColors.warning)
                        Text("No faces detected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.warning)
                    }

                    Text("Tap \"Missing?\" above then tap a face in the photo.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    if locateFaceMode {
                        locateFaceModeIndicator
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                if locateFaceMode {
                    locateFaceModeIndicator
                }

                ForEach(Array(boundingBoxes.enumerated()), id: \.element.id) { index, box in
                    FaceRowView(
                        box: box,
                        index: index,
                        onTap: {
                            selectedBoxIndex = index
                            showPersonPicker = true
                        },
                        onClear: {
                            removeExistingEmbedding(for: box.id)
                            boundingBoxes[index].personId = nil
                            boundingBoxes[index].personName = nil
                            boundingBoxes[index].confidence = nil
                            boundingBoxes[index].isAutoAccepted = false
                        }
                    )
                }
            }
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
    private var encounterDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encounter Details")
                .font(.headline)

            TextField("Occasion (e.g., Team lunch, Conference)", text: $occasion)
                .textFieldStyle(.roundedBorder)

            TextField("Location", text: $location)
                .textFieldStyle(.roundedBorder)

            Text("Notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Image(systemName: "calendar")
                Text(scannedPhoto.date.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Show GPS coordinates if available
            if let location = scannedPhoto.location {
                HStack {
                    Image(systemName: "location.fill")
                    Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                    Spacer()
                    if let url = URL(string: "https://maps.apple.com/?ll=\(location.coordinate.latitude),\(location.coordinate.longitude)") {
                        Link("Open Map", destination: url)
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var personPickerSheet: some View {
        NavigationStack {
            List {
                // Show the face being labeled
                Section {
                    HStack {
                        Spacer()
                        if let faceCrop = selectedFaceCrop {
                            Image(uiImage: faceCrop)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange, lineWidth: 3)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay {
                                    ProgressView()
                                }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Suggested matches
                if isLoadingMatches {
                    Section("Finding Matches...") {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if !potentialMatches.isEmpty {
                    Section("Suggested Matches") {
                        ForEach(potentialMatches, id: \.person.id) { match in
                            Button {
                                assignPerson(match.person)
                            } label: {
                                HStack {
                                    if let firstEmbedding = match.person.embeddings?.first,
                                       let image = UIImage(data: firstEmbedding.faceCropData) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundStyle(.secondary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(match.person.name)
                                            .fontWeight(.medium)
                                        if let company = match.person.company {
                                            Text(company)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    // Confidence badge
                                    Text("\(Int(match.similarity * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(confidenceColor(for: match.similarity))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                // Add new person option
                Section {
                    Button {
                        showPersonPicker = false
                        showNewPersonSheet = true
                    } label: {
                        Label("Add New Person", systemImage: "person.badge.plus")
                    }
                }

                // Other people (not in top matches), filtered by search
                let matchedPersonIds = Set(potentialMatches.map { $0.person.id })
                let otherPeople = people.filter { person in
                    guard !matchedPersonIds.contains(person.id) else { return false }
                    if labelSearchText.isEmpty { return true }
                    return person.name.localizedCaseInsensitiveContains(labelSearchText) ||
                        person.company?.localizedCaseInsensitiveContains(labelSearchText) == true
                }

                if !otherPeople.isEmpty {
                    Section("Other People") {
                        ForEach(otherPeople) { person in
                            Button {
                                assignPerson(person)
                            } label: {
                                HStack {
                                    if let firstEmbedding = person.embeddings?.first,
                                       let image = UIImage(data: firstEmbedding.faceCropData) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(person.name)
                                        if let company = person.company {
                                            Text(company)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                // Remove label option (if face is already tagged)
                if let boxIndex = selectedBoxIndex,
                   boxIndex < boundingBoxes.count,
                   boundingBoxes[boxIndex].personId != nil {
                    Section {
                        Button(role: .destructive) {
                            removePersonFromFace()
                        } label: {
                            Label("Remove Label", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .searchable(text: $labelSearchText, prompt: "Search people")
            .navigationTitle("Who is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPersonPicker = false
                        selectedFaceCrop = nil
                        potentialMatches = []
                        labelSearchText = ""
                    }
                }
            }
            .onAppear {
                labelSearchText = ""
                loadFaceCropAndMatches()
            }
        }
    }

    private func removePersonFromFace() {
        guard let boxIndex = selectedBoxIndex,
              boxIndex < boundingBoxes.count else { return }

        let boxId = boundingBoxes[boxIndex].id
        removeExistingEmbedding(for: boxId)

        boundingBoxes[boxIndex].personId = nil
        boundingBoxes[boxIndex].personName = nil
        boundingBoxes[boxIndex].confidence = nil
        boundingBoxes[boxIndex].isAutoAccepted = false

        showPersonPicker = false
        selectedFaceCrop = nil
        potentialMatches = []
    }

    /// Remove any existing embedding created during this review session for the given bounding box
    private func removeExistingEmbedding(for boundingBoxId: UUID) {
        guard let index = createdEmbeddings.firstIndex(where: { $0.boundingBoxId == boundingBoxId }) else { return }
        let embedding = createdEmbeddings[index]
        embedding.person = nil
        modelContext.delete(embedding)
        createdEmbeddings.remove(at: index)
    }

    private func confidenceColor(for similarity: Float) -> Color {
        if similarity >= 0.85 {
            return .green
        } else if similarity >= 0.70 {
            return .orange
        } else {
            return .red
        }
    }

    private func loadFaceCropAndMatches() {
        let faces = localDetectedFaces.isEmpty ? scannedPhoto.detectedFaces : localDetectedFaces
        guard let boxIndex = selectedBoxIndex,
              boxIndex < faces.count else { return }

        let face = faces[boxIndex]
        selectedFaceCrop = face.cropImage

        // Find potential matches
        guard !people.isEmpty else { return }

        isLoadingMatches = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService.shared
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                // Boost persons already assigned to faces in this encounter
                let assignedPersonIds = Set(boundingBoxes.compactMap { $0.personId })
                let matches = matchingService.findMatches(for: embedding, in: people, topK: 5, threshold: 0.5, boostPersonIds: assignedPersonIds)

                await MainActor.run {
                    potentialMatches = matches
                    isLoadingMatches = false
                }
            } catch {
                await MainActor.run {
                    isLoadingMatches = false
                }
                print("Error finding matches: \(error)")
            }
        }
    }

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        guard let image = scannedPhoto.image else { return }
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

                // Smaller crop for precision; shrinks further when zoomed in
                let baseCropFraction: CGFloat = 0.2
                let cropSize = min(imageSize.width, imageSize.height) * baseCropFraction / zoomScale
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

                // Upscale cropped region 3× for more confident face detection
                let upscaleSize = CGSize(
                    width: CGFloat(cgImage.width) * 3.0,
                    height: CGFloat(cgImage.height) * 3.0
                )
                let renderer = UIGraphicsImageRenderer(size: upscaleSize)
                let croppedImage = renderer.image { _ in
                    UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: upscaleSize))
                }

                let faces = try await faceDetectionService.detectFaces(in: croppedImage, options: .enhanced)

                if let face = faces.first {
                    let cropNormRect = face.normalizedBoundingBox
                    let originalX = (cropRect.origin.x + cropNormRect.origin.x * cropRect.width) / imageSize.width
                    let originalWidth = (cropNormRect.width * cropRect.width) / imageSize.width
                    let cropBottomNorm = 1.0 - (cropRect.origin.y + cropRect.height) / imageSize.height
                    let cropHeightNorm = cropRect.height / imageSize.height
                    let originalY = cropBottomNorm + cropNormRect.origin.y * cropHeightNorm
                    let originalHeight = cropNormRect.height * cropHeightNorm

                    let translatedNormRect = CGRect(
                        x: originalX, y: originalY,
                        width: originalWidth, height: originalHeight
                    )

                    let newBox = FaceBoundingBox(
                        rect: translatedNormRect,
                        personId: nil,
                        personName: nil,
                        confidence: nil,
                        isAutoAccepted: false
                    )

                    let translatedPixelRect = CGRect(
                        x: originalX * imageSize.width,
                        y: (1.0 - originalY - originalHeight) * imageSize.height,
                        width: originalWidth * imageSize.width,
                        height: originalHeight * imageSize.height
                    )
                    let newDetectedFace = DetectedFace(
                        boundingBox: translatedPixelRect,
                        cropImage: face.cropImage,
                        normalizedBoundingBox: translatedNormRect
                    )

                    // Reject if >60% of either box's area is overlapped
                    let isDuplicate = await MainActor.run {
                        boundingBoxes.contains { existing in
                            let existingRect = existing.rect
                            let intersection = existingRect.intersection(translatedNormRect)
                            guard !intersection.isNull else { return false }
                            let intersectionArea = intersection.width * intersection.height
                            let newArea = translatedNormRect.width * translatedNormRect.height
                            let existingArea = existingRect.width * existingRect.height
                            guard newArea > 0, existingArea > 0 else { return false }
                            let overlapOfNew = intersectionArea / newArea
                            let overlapOfExisting = intersectionArea / existingArea
                            return max(overlapOfNew, overlapOfExisting) > 0.6
                        }
                    }

                    if isDuplicate {
                        await MainActor.run {
                            locateFaceError = "A face already exists at that location"
                            isLocatingFace = false
                        }
                        return
                    }

                    await MainActor.run {
                        boundingBoxes.append(newBox)
                        localDetectedFaces.append(newDetectedFace)
                        let newIndex = boundingBoxes.count - 1
                        lastAddedFaceIndex = newIndex
                        locateFaceMode = false
                        isLocatingFace = false

                        selectedBoxIndex = newIndex
                        loadFaceCropAndMatches()
                        showPersonPicker = true
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

    @ViewBuilder
    private var newPersonSheet: some View {
        let faces = localDetectedFaces.isEmpty ? scannedPhoto.detectedFaces : localDetectedFaces
        let cropImage: UIImage? = {
            guard let idx = selectedBoxIndex, idx < faces.count else { return nil }
            return faces[idx].cropImage
        }()
        NewPersonSheetContent(
            faceCropImage: cropImage,
            name: $newPersonName,
            confirmLabel: "Add",
            onConfirm: { createAndAssignPerson() },
            onCancel: { newPersonName = ""; showNewPersonSheet = false }
        )
    }

    private func processPhoto() async {
        let boxes = await scannerService.matchFacesToPeople(
            in: scannedPhoto,
            people: people,
            autoAcceptThreshold: autoAcceptThreshold
        )

        // Reverse geocode location if available
        var locationName: String?
        if let photoLocation = scannedPhoto.location {
            locationName = await reverseGeocode(photoLocation)
        }

        await MainActor.run {
            boundingBoxes = boxes
            localDetectedFaces = scannedPhoto.detectedFaces
            if let name = locationName {
                location = name
            }
            isProcessing = false
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    var components: [String] = []
                    if let name = placemark.name {
                        components.append(name)
                    }
                    if let locality = placemark.locality {
                        if !components.contains(locality) {
                            components.append(locality)
                        }
                    }
                    if let administrativeArea = placemark.administrativeArea {
                        if !components.contains(administrativeArea) {
                            components.append(administrativeArea)
                        }
                    }
                    continuation.resume(returning: components.joined(separator: ", "))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func assignPerson(_ person: Person) {
        guard let index = selectedBoxIndex else { return }

        // Remove old embedding if re-labeling
        let boxId = boundingBoxes[index].id
        removeExistingEmbedding(for: boxId)

        boundingBoxes[index].personId = person.id
        boundingBoxes[index].personName = person.name
        boundingBoxes[index].isAutoAccepted = false

        // Add embedding to person
        addEmbeddingToPerson(person, faceIndex: index)

        // Auto-propagate label to similar faces in the same encounter
        propagateLabelToSimilarFaces(person: person, sourceFaceIndex: index)

        showPersonPicker = false
        selectedBoxIndex = nil
    }

    private func createAndAssignPerson() {
        guard let index = selectedBoxIndex else { return }

        let person = Person(name: newPersonName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(person)
        createdPersons.append(person)

        boundingBoxes[index].personId = person.id
        boundingBoxes[index].personName = person.name
        boundingBoxes[index].isAutoAccepted = false

        // Add embedding to person
        addEmbeddingToPerson(person, faceIndex: index)

        // Auto-propagate label to similar faces in the same encounter
        propagateLabelToSimilarFaces(person: person, sourceFaceIndex: index)

        newPersonName = ""
        showNewPersonSheet = false
        selectedBoxIndex = nil
    }

    /// Automatically label similar faces in the same encounter
    private func propagateLabelToSimilarFaces(person: Person, sourceFaceIndex: Int) {
        let faces = localDetectedFaces.isEmpty ? scannedPhoto.detectedFaces : localDetectedFaces
        guard sourceFaceIndex < faces.count else { return }

        let sourceFace = faces[sourceFaceIndex]

        Task {
            let embeddingService = FaceEmbeddingService.shared

            do {
                // Generate embedding for the source face
                let sourceEmbedding = try await embeddingService.generateEmbedding(for: sourceFace.cropImage)

                // Check all other unlabeled faces
                for (otherIndex, otherFace) in faces.enumerated() {
                    // Skip the source face and already labeled faces
                    guard otherIndex != sourceFaceIndex,
                          otherIndex < boundingBoxes.count,
                          boundingBoxes[otherIndex].personId == nil else {
                        continue
                    }

                    // Generate embedding for this face
                    let otherEmbedding = try await embeddingService.generateEmbedding(for: otherFace.cropImage)

                    // Calculate similarity
                    let similarity = cosineSimilarity(sourceEmbedding, otherEmbedding)

                    // If similarity is high enough, auto-label this face
                    if similarity >= autoAcceptThreshold {
                        await MainActor.run {
                            boundingBoxes[otherIndex].personId = person.id
                            boundingBoxes[otherIndex].personName = person.name
                            boundingBoxes[otherIndex].confidence = similarity
                            boundingBoxes[otherIndex].isAutoAccepted = true
                        }

                        // Also add this face's embedding to the person
                        let boxId = await MainActor.run { boundingBoxes[otherIndex].id }
                        await addEmbeddingToPersonAsync(person, face: otherFace, boundingBoxId: boxId)
                    }
                }
            } catch {
                print("Error propagating labels: \(error)")
            }
        }
    }

    /// Calculate cosine similarity between two embedding vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    /// Add embedding to person asynchronously (for propagated faces)
    private func addEmbeddingToPersonAsync(_ person: Person, face: DetectedFace, boundingBoxId: UUID) async {
        let embeddingService = FaceEmbeddingService.shared

        do {
            let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
            let vectorData = embedding.withUnsafeBytes { Data($0) }
            let imageData = face.cropImage.jpegData(compressionQuality: 0.8) ?? Data()

            await MainActor.run {
                let faceEmbedding = FaceEmbedding(
                    vector: vectorData,
                    faceCropData: imageData,
                    boundingBoxId: boundingBoxId
                )
                faceEmbedding.person = person
                modelContext.insert(faceEmbedding)
                person.lastSeenAt = Date()

                // Auto-assign as profile photo if person has none
                if person.profileEmbeddingId == nil {
                    person.profileEmbeddingId = faceEmbedding.id
                }

                // Track for encounterId assignment on save
                createdEmbeddings.append(faceEmbedding)
            }
        } catch {
            print("Error adding embedding for propagated face: \(error)")
        }
    }

    private func addEmbeddingToPerson(_ person: Person, faceIndex: Int) {
        // Use localDetectedFaces if available (after re-detection), otherwise use original
        let faces = localDetectedFaces.isEmpty ? scannedPhoto.detectedFaces : localDetectedFaces
        guard faceIndex < faces.count, faceIndex < boundingBoxes.count else { return }
        let face = faces[faceIndex]
        let boxId = boundingBoxes[faceIndex].id

        Task {
            let embeddingService = FaceEmbeddingService.shared
            do {
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                let vectorData = embedding.withUnsafeBytes { Data($0) }
                let imageData = face.cropImage.jpegData(compressionQuality: 0.8) ?? Data()

                await MainActor.run {
                    let faceEmbedding = FaceEmbedding(
                        vector: vectorData,
                        faceCropData: imageData,
                        boundingBoxId: boxId
                    )
                    faceEmbedding.person = person
                    modelContext.insert(faceEmbedding)
                    person.lastSeenAt = Date()

                    // Auto-assign as profile photo if person has none
                    if person.profileEmbeddingId == nil {
                        person.profileEmbeddingId = faceEmbedding.id
                    }

                    // Track embedding for later encounterId assignment
                    createdEmbeddings.append(faceEmbedding)
                }
            } catch {
                print("Error adding embedding: \(error)")
            }
        }
    }

    /// Clean up persons created during this session when user cancels
    private func cleanupCreatedPersons() {
        for person in createdPersons {
            // Delete embeddings first (should cascade, but be explicit)
            for embedding in person.embeddings ?? [] {
                modelContext.delete(embedding)
            }
            modelContext.delete(person)
        }
        createdPersons.removeAll()
    }

    private func saveEncounter() {
        let settings = AppSettings.shared
        guard let originalImage = scannedPhoto.image else { return }
        let resizedImage = resizeImage(originalImage, targetSize: settings.photoTargetSize)
        guard let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) else { return }

        // Extract GPS coordinates from photo metadata
        let latitude = scannedPhoto.location?.coordinate.latitude
        let longitude = scannedPhoto.location?.coordinate.longitude

        let encounter = Encounter(
            occasion: occasion.isEmpty ? nil : occasion,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            latitude: latitude,
            longitude: longitude,
            date: scannedPhoto.date
        )

        // Create EncounterPhoto with assetIdentifier for dedup
        let encounterPhoto = EncounterPhoto(
            imageData: imageData,
            date: scannedPhoto.date,
            latitude: latitude,
            longitude: longitude,
            assetIdentifier: scannedPhoto.id
        )
        encounterPhoto.faceBoundingBoxes = boundingBoxes
        encounterPhoto.encounter = encounter
        encounter.photos = [encounterPhoto]

        // Set thumbnail
        let thumbnailImage = resizeImage(originalImage, targetSize: CGSize(width: 256, height: 256))
        encounter.thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.5)

        // Link people to encounter
        let linkedPeople = boundingBoxes.compactMap { box -> Person? in
            guard let personId = box.personId else { return nil }
            return people.first { $0.id == personId }
        }
        encounter.people = linkedPeople

        // Update embeddings with encounter ID for source tracking
        for embedding in createdEmbeddings {
            embedding.encounterId = encounter.id
        }

        onSave(encounter)
        dismiss()
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

struct FaceBoundingBoxOverlay: View {
    let box: FaceBoundingBox
    let isSelected: Bool
    let imageSize: CGSize
    let viewSize: CGSize

    // Minimum tap target size (Apple HIG recommends 44x44)
    private let minTapTarget: CGFloat = 44

    var body: some View {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Convert normalized coordinates to view coordinates
        let x = offsetX + box.x * scaledWidth
        let y = offsetY + (1 - box.y - box.height) * scaledHeight
        let width = box.width * scaledWidth
        let height = box.height * scaledHeight

        // Calculate tap target size (at least minTapTarget)
        let tapWidth = max(width, minTapTarget)
        let tapHeight = max(height, minTapTarget)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isSelected ? 3 : 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(boxColor.opacity(0.1))
                )
                .frame(width: width, height: height)

            if let name = box.personName {
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
        // Use larger frame for tap target while keeping visual size
        .frame(width: tapWidth, height: tapHeight)
        .contentShape(Rectangle()) // Ensure entire frame is tappable
        .position(x: x + width / 2, y: y + height / 2)
    }

    private var boxColor: Color {
        if box.isAutoAccepted {
            return .green
        } else if box.personId != nil {
            return .blue
        } else {
            return .orange
        }
    }
}

struct FaceRowView: View {
    let box: FaceBoundingBox
    let index: Int
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading) {
                if let name = box.personName {
                    Text(name)
                        .fontWeight(.medium)

                    if let confidence = box.confidence {
                        HStack(spacing: 4) {
                            Text("\(Int(confidence * 100))% match")
                            if box.isAutoAccepted {
                                Text("• Auto-accepted")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown person")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if box.personId != nil {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onTap()
            } label: {
                Image(systemName: box.personId == nil ? "plus.circle.fill" : "pencil.circle.fill")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        if box.isAutoAccepted {
            return .green
        } else if box.personId != nil {
            return .blue
        } else {
            return .orange
        }
    }
}
