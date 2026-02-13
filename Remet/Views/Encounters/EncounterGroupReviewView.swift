import SwiftUI
import SwiftData
import CoreLocation

struct EncounterGroupReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let photoGroup: PhotoGroup
    let people: [Person]
    let onSave: (Encounter) -> Void

    @State private var selectedPhotoIndex = 0
    @State private var photoFaceData: [String: [FaceBoundingBox]] = [:]  // photoId -> boxes
    @State private var isProcessing = true
    @State private var occasion: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""

    @State private var selectedBoxIndex: Int?
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

    // Manual face location state
    @State private var isLocatingFace = false
    @State private var locateFaceMode = false
    @State private var locateFaceError: String?
    @State private var lastAddedFaceId: UUID?
    @State private var lastAddedFacePhotoId: String?

    // Focus state for name input


    private let scannerService = PhotoLibraryScannerService()
    private var autoAcceptThreshold: Float { AppSettings.shared.autoAcceptThreshold }

    private var currentPhoto: ScannedPhoto? {
        guard selectedPhotoIndex < photoGroup.photos.count else { return nil }
        return photoGroup.photos[selectedPhotoIndex]
    }

    private var currentBoundingBoxes: [FaceBoundingBox] {
        guard let photo = currentPhoto else { return [] }
        return photoFaceData[photo.id] ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoCarousel
                    if !isProcessing {
                        facesSection
                    }
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
                await processAllPhotos()
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
    private var photoCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(photoGroup.photos.enumerated()), id: \.element.id) { index, photo in
                    photoWithOverlays(photo: photo, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 350)

            // Photo indicator
            Text("\(selectedPhotoIndex + 1) of \(photoGroup.photos.count) photos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func photoWithOverlays(photo: ScannedPhoto, index: Int) -> some View {
        GeometryReader { geometry in
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if locateFaceMode {
                            handleLocateFaceTap(at: location, in: geometry.size, imageSize: image.size, photo: photo, image: image)
                        }
                    }
                    .overlay {
                        let boxes = photoFaceData[photo.id] ?? []
                        ForEach(Array(boxes.enumerated()), id: \.element.id) { boxIndex, box in
                            FaceBoundingBoxOverlay(
                                box: box,
                                isSelected: selectedPhotoIndex == index && selectedBoxIndex == boxIndex,
                                imageSize: image.size,
                                viewSize: geometry.size
                            )
                            .onTapGesture {
                                if !locateFaceMode {
                                    selectedPhotoIndex = index
                                    selectedBoxIndex = boxIndex
                                    showPersonPicker = true
                                }
                            }
                        }
                    }
            } else {
                // Placeholder while photo loads from iCloud
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading photo...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Photo may be downloading from iCloud")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var facesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People in this encounter")
                    .font(.headline)

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
                        Text(locateFaceMode ? "Cancel" : "Missing faces?")
                    }
                    .font(.caption)
                    .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
                }
                .disabled(isLocatingFace || isProcessing)
            }

            // Locate face mode indicator
            if locateFaceMode {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                        Text("Tap where you see a face in the photo above")
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
            if lastAddedFaceId != nil {
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

            if isProcessing || isLocatingFace {
                HStack {
                    ProgressView()
                    Text(isLocatingFace ? "Looking for face..." : "Analyzing faces...")
                        .foregroundStyle(.secondary)
                }
            } else if !locateFaceMode {
                // Show unique people across all photos
                let allPeople = collectUniquePeople()
                if allPeople.isEmpty {
                    Text("No faces identified yet. Tap faces to identify.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allPeople, id: \.id) { person in
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

                            Text(person.name)
                                .fontWeight(.medium)

                            Spacer()

                            // Count appearances
                            let count = countPersonAppearances(person.id)
                            Text("\(count) photo\(count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Unidentified faces count
                let unidentifiedCount = countUnidentifiedFaces()
                if unidentifiedCount > 0 {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("\(unidentifiedCount) unidentified face\(unidentifiedCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
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
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            // Date and location info
            HStack {
                Image(systemName: "calendar")
                Text(photoGroup.date.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let loc = photoGroup.location {
                HStack {
                    Image(systemName: "location.fill")
                    Text(String(format: "%.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude))
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
                if let photo = currentPhoto,
                   let boxIndex = selectedBoxIndex,
                   let boxes = photoFaceData[photo.id],
                   boxIndex < boxes.count,
                   boxes[boxIndex].personId != nil {
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
        guard let photo = currentPhoto,
              let boxIndex = selectedBoxIndex,
              var boxes = photoFaceData[photo.id],
              boxIndex < boxes.count else { return }

        let boxId = boxes[boxIndex].id
        removeExistingEmbedding(for: boxId)

        boxes[boxIndex].personId = nil
        boxes[boxIndex].personName = nil
        boxes[boxIndex].confidence = nil
        boxes[boxIndex].isAutoAccepted = false
        photoFaceData[photo.id] = boxes

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
        guard let photo = currentPhoto,
              let boxIndex = selectedBoxIndex,
              boxIndex < photo.detectedFaces.count else { return }

        let face = photo.detectedFaces[boxIndex]
        selectedFaceCrop = face.cropImage

        // Find potential matches
        guard !people.isEmpty else { return }

        isLoadingMatches = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                // Boost persons already assigned to faces in this encounter
                let assignedPersonIds = Set(photoFaceData.values.flatMap { $0 }.compactMap { $0.personId })
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

    @ViewBuilder
    private var newPersonSheet: some View {
        let cropImage: UIImage? = {
            guard let photo = currentPhoto,
                  let idx = selectedBoxIndex,
                  idx < photo.detectedFaces.count else { return nil }
            return photo.detectedFaces[idx].cropImage
        }()
        NewPersonSheetContent(
            faceCropImage: cropImage,
            name: $newPersonName,
            confirmLabel: "Add",
            onConfirm: { createAndAssignPerson() },
            onCancel: { newPersonName = ""; showNewPersonSheet = false }
        )
    }

    // MARK: - Helper Functions

    private func processAllPhotos() async {
        for photo in photoGroup.photos {
            let boxes = await scannerService.matchFacesToPeople(
                in: photo,
                people: people,
                autoAcceptThreshold: autoAcceptThreshold
            )

            await MainActor.run {
                photoFaceData[photo.id] = boxes
            }
        }

        // Reverse geocode first location
        if let loc = photoGroup.location {
            let locationName = await reverseGeocode(loc)
            await MainActor.run {
                if let name = locationName {
                    location = name
                }
                isProcessing = false
            }
        } else {
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize, photo: ScannedPhoto, image: UIImage) {
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

                    let newBox = FaceBoundingBox(
                        rect: CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight),
                        personId: nil,
                        personName: nil,
                        confidence: nil,
                        isAutoAccepted: false
                    )

                    await MainActor.run {
                        var boxes = photoFaceData[photo.id] ?? []
                        boxes.append(newBox)
                        photoFaceData[photo.id] = boxes
                        lastAddedFaceId = newBox.id
                        lastAddedFacePhotoId = photo.id
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
        guard let faceId = lastAddedFaceId,
              let photoId = lastAddedFacePhotoId else { return }

        if var boxes = photoFaceData[photoId] {
            boxes.removeAll { $0.id == faceId }
            photoFaceData[photoId] = boxes
        }

        lastAddedFaceId = nil
        lastAddedFacePhotoId = nil
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first {
                    var components: [String] = []
                    if let name = placemark.name { components.append(name) }
                    if let locality = placemark.locality, !components.contains(locality) {
                        components.append(locality)
                    }
                    continuation.resume(returning: components.joined(separator: ", "))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func collectUniquePeople() -> [Person] {
        var personIds = Set<UUID>()
        var uniquePeople: [Person] = []

        for (_, boxes) in photoFaceData {
            for box in boxes {
                if let personId = box.personId, !personIds.contains(personId) {
                    personIds.insert(personId)
                    if let person = people.first(where: { $0.id == personId }) {
                        uniquePeople.append(person)
                    }
                }
            }
        }

        return uniquePeople
    }

    private func countPersonAppearances(_ personId: UUID) -> Int {
        var count = 0
        for (_, boxes) in photoFaceData {
            if boxes.contains(where: { $0.personId == personId }) {
                count += 1
            }
        }
        return count
    }

    private func countUnidentifiedFaces() -> Int {
        var count = 0
        for (_, boxes) in photoFaceData {
            count += boxes.filter { $0.personId == nil }.count
        }
        return count
    }

    private func assignPerson(_ person: Person) {
        guard let photo = currentPhoto, let boxIndex = selectedBoxIndex else { return }
        guard var boxes = photoFaceData[photo.id], boxIndex < boxes.count else { return }

        // Remove old embedding if re-labeling
        let boxId = boxes[boxIndex].id
        removeExistingEmbedding(for: boxId)

        boxes[boxIndex].personId = person.id
        boxes[boxIndex].personName = person.name
        boxes[boxIndex].isAutoAccepted = false
        photoFaceData[photo.id] = boxes

        addEmbeddingToPerson(person, photo: photo, faceIndex: boxIndex)

        // Propagate to other photos with similar faces
        propagatePersonToOtherPhotos(person: person, sourcePhoto: photo, sourceFaceIndex: boxIndex)

        showPersonPicker = false
        selectedBoxIndex = nil
    }

    private func createAndAssignPerson() {
        guard let photo = currentPhoto, let boxIndex = selectedBoxIndex else { return }

        let person = Person(name: newPersonName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(person)
        createdPersons.append(person)

        guard var boxes = photoFaceData[photo.id], boxIndex < boxes.count else { return }

        boxes[boxIndex].personId = person.id
        boxes[boxIndex].personName = person.name
        boxes[boxIndex].isAutoAccepted = false
        photoFaceData[photo.id] = boxes

        addEmbeddingToPerson(person, photo: photo, faceIndex: boxIndex)

        // Propagate to other photos with similar faces
        propagatePersonToOtherPhotos(person: person, sourcePhoto: photo, sourceFaceIndex: boxIndex)

        newPersonName = ""
        showNewPersonSheet = false
        selectedBoxIndex = nil
    }

    private func addEmbeddingToPerson(_ person: Person, photo: ScannedPhoto, faceIndex: Int) {
        guard faceIndex < photo.detectedFaces.count,
              let boxes = photoFaceData[photo.id],
              faceIndex < boxes.count else { return }
        let face = photo.detectedFaces[faceIndex]
        let boxId = boxes[faceIndex].id

        Task {
            let embeddingService = FaceEmbeddingService()
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

                    createdEmbeddings.append(faceEmbedding)
                }
            } catch {
                print("Error adding embedding: \(error)")
            }
        }
    }

    /// Propagate a person label to similar unidentified faces in other photos
    private func propagatePersonToOtherPhotos(person: Person, sourcePhoto: ScannedPhoto, sourceFaceIndex: Int) {
        guard sourceFaceIndex < sourcePhoto.detectedFaces.count else { return }
        let sourceFace = sourcePhoto.detectedFaces[sourceFaceIndex]

        Task {
            let embeddingService = FaceEmbeddingService()
            let matchingService = FaceMatchingService()

            do {
                // Generate embedding for the source face
                let sourceEmbedding = try await embeddingService.generateEmbedding(for: sourceFace.cropImage)

                // Check each other photo for similar unidentified faces
                for otherPhoto in photoGroup.photos where otherPhoto.id != sourcePhoto.id {
                    // Get current boxes for this photo
                    guard let initialBoxes = await MainActor.run(body: { photoFaceData[otherPhoto.id] }) else { continue }

                    // Track which indices to update and their new values
                    var updates: [(index: Int, similarity: Float)] = []

                    for (index, box) in initialBoxes.enumerated() {
                        // Skip if already identified
                        guard box.personId == nil else { continue }
                        guard index < otherPhoto.detectedFaces.count else { continue }

                        let otherFace = otherPhoto.detectedFaces[index]

                        // Generate embedding for this face and compare
                        let otherEmbedding = try await embeddingService.generateEmbedding(for: otherFace.cropImage)
                        let similarity = matchingService.cosineSimilarity(sourceEmbedding, otherEmbedding)

                        // If similar enough, mark for update
                        if similarity >= autoAcceptThreshold {
                            updates.append((index: index, similarity: similarity))
                        }
                    }

                    // Apply all updates for this photo at once
                    if !updates.isEmpty {
                        await MainActor.run {
                            guard var boxes = photoFaceData[otherPhoto.id] else { return }
                            for update in updates {
                                boxes[update.index].personId = person.id
                                boxes[update.index].personName = person.name
                                boxes[update.index].confidence = update.similarity
                                boxes[update.index].isAutoAccepted = true
                            }
                            photoFaceData[otherPhoto.id] = boxes
                        }

                        // Add embeddings for matched faces
                        for update in updates {
                            addEmbeddingToPerson(person, photo: otherPhoto, faceIndex: update.index)
                        }
                    }
                }
            } catch {
                print("Error propagating person to other photos: \(error)")
            }
        }
    }

    private func saveEncounter() {
        let settings = AppSettings.shared

        // Dedup safety net: photos should already be filtered before review,
        // but check again to prevent DB-level duplicates silently.
        let existingAssetIds = fetchExistingAssetIds()

        let encounter = Encounter(
            occasion: occasion.isEmpty ? nil : occasion,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            latitude: photoGroup.location?.coordinate.latitude,
            longitude: photoGroup.location?.coordinate.longitude,
            date: photoGroup.date
        )

        // Create EncounterPhoto for each photo
        for photo in photoGroup.photos {
            // Safety net: skip if somehow already in DB (should not happen after pre-filtering)
            if existingAssetIds.contains(photo.id) {
                continue
            }

            guard let originalImage = photo.image else { continue }
            let resizedImage = resizeImage(originalImage, targetSize: settings.photoTargetSize)
            guard let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) else { continue }

            let encounterPhoto = EncounterPhoto(
                imageData: imageData,
                date: photo.date,
                latitude: photo.location?.coordinate.latitude,
                longitude: photo.location?.coordinate.longitude,
                assetIdentifier: photo.id
            )

            // Set face bounding boxes
            if let boxes = photoFaceData[photo.id] {
                encounterPhoto.faceBoundingBoxes = boxes
            }

            encounterPhoto.encounter = encounter
            encounter.photos = (encounter.photos ?? []) + [encounterPhoto]
        }

        // Set thumbnail from first photo (always use compact size for thumbnails)
        if let firstPhoto = photoGroup.photos.first?.image {
            let thumbnailImage = resizeImage(firstPhoto, targetSize: CGSize(width: 256, height: 256))
            encounter.thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.5)
        }

        // Link people to encounter
        let linkedPeople = collectUniquePeople()
        encounter.people = linkedPeople

        // Update embeddings with encounter ID
        for embedding in createdEmbeddings {
            embedding.encounterId = encounter.id
        }

        onSave(encounter)
        dismiss()
    }

    /// Fetch all asset identifiers already stored in the database to prevent duplicate imports.
    private func fetchExistingAssetIds() -> Set<String> {
        let descriptor = FetchDescriptor<EncounterPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else { return [] }
        return Set(photos.compactMap { $0.assetIdentifier })
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
}
