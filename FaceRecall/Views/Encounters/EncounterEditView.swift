import SwiftUI
import SwiftData

/// Unified encounter editing view that mirrors the creation flow UI/UX
struct EncounterEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var encounter: Encounter
    let people: [Person]

    @State private var selectedPhotoIndex = 0
    @State private var isProcessing = false
    @State private var occasion: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""

    @State private var selectedBoxId: UUID?
    @State private var selectedPhotoForLabeling: EncounterPhoto?
    @State private var showPersonPicker = false
    @State private var showNewPersonSheet = false
    @State private var newPersonName = ""

    // Face matching state
    @State private var selectedFaceCrop: UIImage?
    @State private var potentialMatches: [MatchResult] = []
    @State private var isLoadingMatches = false

    // Manual face location state
    @State private var isLocatingFace = false
    @State private var locateFaceMode = false
    @State private var locateFaceError: String?
    @State private var lastAddedFaceId: UUID?
    @State private var lastAddedFacePhotoId: UUID?

    // Re-detection state
    @State private var isRedetecting = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    private var autoAcceptThreshold: Float { AppSettings.shared.autoAcceptThreshold }

    // Support both multi-photo and legacy single-photo encounters
    private var hasMultiplePhotos: Bool {
        !encounter.photos.isEmpty
    }

    private var currentPhoto: EncounterPhoto? {
        guard hasMultiplePhotos, selectedPhotoIndex < encounter.photos.count else { return nil }
        return encounter.photos[selectedPhotoIndex]
    }

    private var currentBoundingBoxes: [FaceBoundingBox] {
        if let photo = currentPhoto {
            return photo.faceBoundingBoxes
        }
        return encounter.faceBoundingBoxes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if hasMultiplePhotos {
                        photoCarousel
                    } else {
                        legacyPhotoSection
                    }

                    facesSection
                    encounterDetailsSection
                }
                .padding()
            }
            .navigationTitle("Edit Encounter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadEncounterData()
            }
            .sheet(isPresented: $showPersonPicker) {
                personPickerSheet
            }
            .sheet(isPresented: $showNewPersonSheet) {
                newPersonSheet
            }
        }
    }

    // MARK: - Photo Display

    @ViewBuilder
    private var photoCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(encounter.photos.enumerated()), id: \.element.id) { index, photo in
                    photoWithOverlays(photo: photo, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 350)

            Text("\(selectedPhotoIndex + 1) of \(encounter.photos.count) photos")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Toolbar buttons
            HStack(spacing: 16) {
                // Re-detect faces button
                Button {
                    Task {
                        await redetectFaces()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isRedetecting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        Text("Re-detect")
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.teal)
                }
                .disabled(isRedetecting || isLocatingFace)

                Divider()
                    .frame(height: 16)

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
                        Text(locateFaceMode ? "Cancel" : "Missing faces?")
                    }
                    .font(.caption)
                    .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
                }
                .disabled(isLocatingFace || isRedetecting)
            }
        }
    }

    @ViewBuilder
    private func photoWithOverlays(photo: EncounterPhoto, index: Int) -> some View {
        GeometryReader { geometry in
            if let image = UIImage(data: photo.imageData) {
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
                        ForEach(Array(photo.faceBoundingBoxes.enumerated()), id: \.element.id) { boxIndex, box in
                            FaceBoundingBoxOverlay(
                                box: box,
                                isSelected: selectedBoxId == box.id,
                                imageSize: image.size,
                                viewSize: geometry.size
                            )
                            .onTapGesture {
                                if !locateFaceMode {
                                    selectedBoxId = box.id
                                    selectedPhotoForLabeling = photo
                                    loadFaceCropAndMatches(box: box, image: image)
                                    showPersonPicker = true
                                }
                            }
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var legacyPhotoSection: some View {
        VStack(spacing: 8) {
            if let imageData = encounter.displayImageData,
               let image = UIImage(data: imageData) {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if locateFaceMode {
                                handleLocateFaceTap(at: location, in: geometry.size, imageSize: image.size, photo: nil, image: image)
                            }
                        }
                        .overlay {
                            ForEach(encounter.faceBoundingBoxes) { box in
                                FaceBoundingBoxOverlay(
                                    box: box,
                                    isSelected: selectedBoxId == box.id,
                                    imageSize: image.size,
                                    viewSize: geometry.size
                                )
                                .onTapGesture {
                                    if !locateFaceMode {
                                        selectedBoxId = box.id
                                        selectedPhotoForLabeling = nil
                                        loadFaceCropAndMatches(box: box, image: image)
                                        showPersonPicker = true
                                    }
                                }
                            }
                        }
                }
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Toolbar buttons
            HStack(spacing: 16) {
                Button {
                    Task {
                        await redetectFaces()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isRedetecting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        Text("Re-detect")
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.teal)
                }
                .disabled(isRedetecting || isLocatingFace)

                Divider()
                    .frame(height: 16)

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
                        Text(locateFaceMode ? "Cancel" : "Missing faces?")
                    }
                    .font(.caption)
                    .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
                }
                .disabled(isLocatingFace || isRedetecting)
            }
        }
    }

    // MARK: - Faces Section

    @ViewBuilder
    private var facesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People in this encounter")
                .font(.headline)

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
                    Text(isLocatingFace ? "Looking for face..." : "Processing...")
                        .foregroundStyle(.secondary)
                }
            } else if !locateFaceMode {
                // Show people in encounter
                if encounter.people.isEmpty {
                    Text("No people identified yet. Tap faces to identify.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(encounter.people) { person in
                        HStack {
                            if let firstEmbedding = person.embeddings.first,
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
                            Text("\(count) face\(count == 1 ? "" : "s")")
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

    // MARK: - Encounter Details Section

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

            // Date info
            HStack {
                Image(systemName: "calendar")
                Text(encounter.date.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let lat = encounter.latitude, let lon = encounter.longitude {
                HStack {
                    Image(systemName: "location.fill")
                    Text(String(format: "%.5f, %.5f", lat, lon))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Person Picker Sheet

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
                                matchRow(match: match)
                            }
                        }
                    }
                }

                // All people
                Section("All People") {
                    ForEach(people.filter { person in
                        !potentialMatches.contains { $0.person.id == person.id }
                    }) { person in
                        Button {
                            assignPerson(person)
                        } label: {
                            personRow(person: person)
                        }
                    }

                    // Create new person
                    Button {
                        showPersonPicker = false
                        showNewPersonSheet = true
                    } label: {
                        Label("Create New Person", systemImage: "plus.circle.fill")
                            .foregroundStyle(AppColors.teal)
                    }
                }
            }
            .navigationTitle("Who is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPersonPicker = false
                    }
                }
            }
        }
        .onAppear {
            if selectedFaceCrop == nil, let boxId = selectedBoxId {
                loadSelectedFaceCrop(boxId: boxId)
            }
        }
    }

    @ViewBuilder
    private func matchRow(match: MatchResult) -> some View {
        HStack {
            if let firstEmbedding = match.person.embeddings.first,
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
                    .foregroundStyle(.primary)

                if AppSettings.shared.showConfidenceScores {
                    Text("\(Int(match.similarity * 100))% match")
                        .font(.caption)
                        .foregroundStyle(match.confidence == .high ? AppColors.success : .orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func personRow(person: Person) -> some View {
        HStack {
            if let firstEmbedding = person.embeddings.first,
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

            Text(person.name)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - New Person Sheet

    @ViewBuilder
    private var newPersonSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let faceCrop = selectedFaceCrop {
                    Image(uiImage: faceCrop)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.teal, lineWidth: 3)
                        )
                }

                TextField("Enter name", text: $newPersonName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPersonName = ""
                        showNewPersonSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNewPerson()
                    }
                    .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }

    // MARK: - Helper Methods

    private func loadEncounterData() {
        occasion = encounter.occasion ?? ""
        notes = encounter.notes ?? ""
        location = encounter.location ?? ""
    }

    private func saveChanges() {
        encounter.occasion = occasion.isEmpty ? nil : occasion
        encounter.notes = notes.isEmpty ? nil : notes
        encounter.location = location.isEmpty ? nil : location
    }

    private func loadFaceCropAndMatches(box: FaceBoundingBox, image: UIImage) {
        // Extract face crop
        let imageSize = image.size
        let cropRect = CGRect(
            x: box.x * imageSize.width,
            y: (1 - box.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )

        let padding: CGFloat = 0.2
        let paddedRect = cropRect.insetBy(
            dx: -cropRect.width * padding,
            dy: -cropRect.height * padding
        ).intersection(CGRect(origin: .zero, size: imageSize))

        if let cgImage = image.cgImage?.cropping(to: paddedRect) {
            selectedFaceCrop = UIImage(cgImage: cgImage)
            findMatches(for: selectedFaceCrop!)
        }
    }

    private func loadSelectedFaceCrop(boxId: UUID) {
        // Find the box and image
        if let photo = selectedPhotoForLabeling,
           let box = photo.faceBoundingBoxes.first(where: { $0.id == boxId }),
           let image = UIImage(data: photo.imageData) {
            loadFaceCropAndMatches(box: box, image: image)
        } else if let box = encounter.faceBoundingBoxes.first(where: { $0.id == boxId }),
                  let imageData = encounter.displayImageData,
                  let image = UIImage(data: imageData) {
            loadFaceCropAndMatches(box: box, image: image)
        }
    }

    private func findMatches(for faceCrop: UIImage) {
        isLoadingMatches = true
        potentialMatches = []

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: faceCrop)
                let encounterPersonIds = Set(encounter.people.map { $0.id })
                let matches = matchingService.findMatches(for: embedding, in: people, topK: 5, threshold: 0.5, boostPersonIds: encounterPersonIds)

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

    private func assignPerson(_ person: Person) {
        guard let boxId = selectedBoxId else { return }

        // Update the bounding box
        if let photo = selectedPhotoForLabeling,
           let boxIndex = photo.faceBoundingBoxes.firstIndex(where: { $0.id == boxId }) {
            photo.faceBoundingBoxes[boxIndex].personId = person.id
            photo.faceBoundingBoxes[boxIndex].personName = person.name
        } else if let boxIndex = encounter.faceBoundingBoxes.firstIndex(where: { $0.id == boxId }) {
            encounter.faceBoundingBoxes[boxIndex].personId = person.id
            encounter.faceBoundingBoxes[boxIndex].personName = person.name
        }

        // Link person to encounter if not already
        if !encounter.people.contains(where: { $0.id == person.id }) {
            encounter.people.append(person)
        }

        // Create embedding for the person if we have a face crop
        if let faceCrop = selectedFaceCrop {
            createEmbeddingForPerson(person, faceCrop: faceCrop)
        }

        showPersonPicker = false
        selectedBoxId = nil
        selectedFaceCrop = nil
        potentialMatches = []
    }

    private func createNewPerson() {
        let name = newPersonName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let person = Person(name: name)
        modelContext.insert(person)

        assignPerson(person)

        newPersonName = ""
        showNewPersonSheet = false
    }

    private func createEmbeddingForPerson(_ person: Person, faceCrop: UIImage) {
        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let embedding = try await embeddingService.generateEmbedding(for: faceCrop)

                guard let cropData = faceCrop.jpegData(compressionQuality: 0.8) else { return }

                // Convert embedding array to Data
                let vectorData = embedding.withUnsafeBytes { Data($0) }

                let faceEmbedding = FaceEmbedding(
                    vector: vectorData,
                    faceCropData: cropData,
                    encounterId: encounter.id
                )

                await MainActor.run {
                    person.embeddings.append(faceEmbedding)
                }
            } catch {
                print("Error creating embedding: \(error)")
            }
        }
    }

    private func countPersonAppearances(_ personId: UUID) -> Int {
        var count = 0
        for photo in encounter.photos {
            count += photo.faceBoundingBoxes.filter { $0.personId == personId }.count
        }
        count += encounter.faceBoundingBoxes.filter { $0.personId == personId }.count
        return count
    }

    private func countUnidentifiedFaces() -> Int {
        var count = 0
        for photo in encounter.photos {
            count += photo.faceBoundingBoxes.filter { $0.personId == nil }.count
        }
        count += encounter.faceBoundingBoxes.filter { $0.personId == nil }.count
        return count
    }

    // MARK: - Manual Face Location

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize, photo: EncounterPhoto?, image: UIImage) {
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

                    let newBox = FaceBoundingBox(
                        rect: CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight),
                        personId: nil,
                        personName: nil,
                        confidence: nil,
                        isAutoAccepted: false
                    )

                    await MainActor.run {
                        if let photo = photo {
                            photo.faceBoundingBoxes.append(newBox)
                            lastAddedFacePhotoId = photo.id
                        } else {
                            encounter.faceBoundingBoxes.append(newBox)
                            lastAddedFacePhotoId = nil
                        }
                        lastAddedFaceId = newBox.id
                        locateFaceMode = false
                        isLocatingFace = false

                        // Automatically trigger labeling
                        selectedBoxId = newBox.id
                        selectedPhotoForLabeling = photo
                        if let img = photo != nil ? UIImage(data: photo!.imageData) : UIImage(data: encounter.displayImageData ?? Data()) {
                            loadFaceCropAndMatches(box: newBox, image: img)
                        }
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

    private func undoLastAddedFace() {
        guard let faceId = lastAddedFaceId else { return }

        if let photoId = lastAddedFacePhotoId,
           let photo = encounter.photos.first(where: { $0.id == photoId }) {
            photo.faceBoundingBoxes.removeAll { $0.id == faceId }
        } else {
            encounter.faceBoundingBoxes.removeAll { $0.id == faceId }
        }

        lastAddedFaceId = nil
        lastAddedFacePhotoId = nil
    }

    // MARK: - Re-detection

    private func redetectFaces() async {
        isRedetecting = true

        let faceDetectionService = FaceDetectionService()

        // Re-detect for multi-photo encounters
        for photo in encounter.photos {
            if let image = UIImage(data: photo.imageData) {
                do {
                    let faces = try await faceDetectionService.detectFaces(in: image, options: .enhanced)

                    // Preserve existing labels by matching boxes
                    var newBoxes: [FaceBoundingBox] = []
                    for face in faces {
                        var newBox = FaceBoundingBox(
                            rect: face.normalizedBoundingBox,
                            personId: nil,
                            personName: nil,
                            confidence: nil,
                            isAutoAccepted: false
                        )

                        // Try to find matching existing box
                        for existingBox in photo.faceBoundingBoxes {
                            let iou = calculateIoU(existingBox.rect, newBox.rect)
                            if iou > 0.25 {
                                newBox.personId = existingBox.personId
                                newBox.personName = existingBox.personName
                                newBox.isAutoAccepted = existingBox.isAutoAccepted
                                break
                            }
                        }

                        newBoxes.append(newBox)
                    }

                    await MainActor.run {
                        photo.faceBoundingBoxes = newBoxes
                    }
                } catch {
                    print("Re-detection failed for photo: \(error)")
                }
            }
        }

        // Re-detect for legacy single-photo encounters
        if let imageData = encounter.displayImageData,
           let image = UIImage(data: imageData) {
            do {
                let faces = try await faceDetectionService.detectFaces(in: image, options: .enhanced)

                var newBoxes: [FaceBoundingBox] = []
                for face in faces {
                    var newBox = FaceBoundingBox(
                        rect: face.normalizedBoundingBox,
                        personId: nil,
                        personName: nil,
                        confidence: nil,
                        isAutoAccepted: false
                    )

                    for existingBox in encounter.faceBoundingBoxes {
                        let iou = calculateIoU(existingBox.rect, newBox.rect)
                        if iou > 0.25 {
                            newBox.personId = existingBox.personId
                            newBox.personName = existingBox.personName
                            newBox.isAutoAccepted = existingBox.isAutoAccepted
                            break
                        }
                    }

                    newBoxes.append(newBox)
                }

                await MainActor.run {
                    encounter.faceBoundingBoxes = newBoxes
                }
            } catch {
                print("Re-detection failed for legacy photo: \(error)")
            }
        }

        await MainActor.run {
            isRedetecting = false
        }
    }

    private func calculateIoU(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let intersection = rect1.intersection(rect2)
        if intersection.isNull {
            return 0
        }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = rect1.width * rect1.height + rect2.width * rect2.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }
}

#Preview {
    EncounterEditView(
        encounter: Encounter(date: Date()),
        people: []
    )
}
