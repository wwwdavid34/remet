import SwiftUI
import SwiftData

struct EncounterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPeople: [Person]
    @Bindable var encounter: Encounter

    @State private var isEditing = false
    @State private var showEditView = false
    @State private var selectedPerson: Person?
    @State private var showFullPhoto = false
    @State private var selectedPhotoIndex = 0
    @State private var selectedEncounterPhoto: EncounterPhoto?

    // Face labeling state
    @State private var showFaceLabelPicker = false
    @State private var selectedBoxId: UUID?
    @State private var selectedPhotoForLabeling: EncounterPhoto?
    @State private var showNewPersonSheet = false
    @State private var newPersonName = ""
    @State private var selectedFaceCrop: UIImage?
    @State private var potentialMatches: [MatchResult] = []
    @State private var isLoadingMatches = false


    // Session-level face embedding cache for realtime matching
    @State private var sessionEmbeddings: [UUID: (personId: UUID, embedding: [Float])] = [:]
    @State private var isPropagating = false

    // Manual face location state
    @State private var isLocatingFace = false
    @State private var locateFaceMode = false
    @State private var locateFacePhotoIndex: Int = 0
    @State private var locateFaceError: String?
    @State private var lastAddedFaceId: UUID?
    @State private var lastAddedFacePhotoId: UUID?

    // Re-detect faces state
    @State private var isRedetecting = false

    // Photo move/selection state
    @State private var isPhotoSelectMode = false
    @State private var selectedPhotoIds: Set<UUID> = []
    @State private var showMoveDestination = false

    // Remove person confirmation state
    @State private var personToRemove: Person?
    @State private var showRemovePersonConfirmation = false

    // Tag editing state
    @State private var showTagPicker = false
    @State private var selectedTags: [Tag] = []

    // Delete encounter state
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteEncounterConfirmation = false

    // Check if this encounter has multiple photos
    private var hasMultiplePhotos: Bool {
        !(encounter.photos ?? []).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoSection
                tagsSection
                peopleSection
                detailsSection
            }
            .padding()
            .onAppear {
                selectedTags = encounter.tags ?? []
            }
        }
        .navigationTitle(encounter.occasion ?? "Encounter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditView = true
                    } label: {
                        Label(String(localized: "Edit Details"), systemImage: "pencil")
                    }

                    Button {
                        locateFaceMode.toggle()
                        if !locateFaceMode {
                            locateFaceError = nil
                        }
                    } label: {
                        Label(
                            locateFaceMode ? String(localized: "Cancel Locate Face") : String(localized: "Locate Missing Face"),
                            systemImage: locateFaceMode ? "xmark.circle" : "person.crop.rectangle"
                        )
                    }
                    .disabled(isLocatingFace)

                    Button {
                        Task {
                            await redetectFaces()
                        }
                    } label: {
                        Label(String(localized: "Re-detect Faces"), systemImage: "faceid")
                    }
                    .disabled(isRedetecting)

                    if hasMultiplePhotos {
                        Divider()

                        Button {
                            withAnimation {
                                isPhotoSelectMode = true
                                selectedPhotoIds.removeAll()
                            }
                        } label: {
                            Label(String(localized: "Move Photos"), systemImage: "photo.on.rectangle.angled")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteEncounterConfirmation = true
                    } label: {
                        Label(String(localized: "Delete Encounter"), systemImage: "trash")
                    }
                } label: {
                    if isRedetecting || isLocatingFace {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationDestination(item: $selectedPerson) { person in
            PersonDetailView(person: person)
        }
        .fullScreenCover(isPresented: $showFullPhoto) {
            if hasMultiplePhotos {
                MultiPhotoFullView(
                    encounter: encounter,
                    initialIndex: selectedPhotoIndex,
                    onSelectPerson: { person in
                        showFullPhoto = false
                        selectedPerson = person
                    }
                )
            } else {
                FullPhotoView(encounter: encounter, onSelectPerson: { person in
                    showFullPhoto = false
                    selectedPerson = person
                })
            }
        }
        .sheet(isPresented: $showFaceLabelPicker) {
            faceLabelPickerSheet
        }
        .sheet(isPresented: $showNewPersonSheet) {
            newPersonSheet
        }
        .sheet(isPresented: $showTagPicker, onDismiss: {
            encounter.tags = selectedTags
            try? modelContext.save()
        }) {
            TagPickerView(selectedTags: $selectedTags, title: "Tags for Encounter")
        }
        .sheet(isPresented: $showEditView) {
            EncounterEditView(encounter: encounter, people: allPeople)
        }
        .sheet(isPresented: $showMoveDestination) {
            MovePhotosDestinationView(
                sourceEncounter: encounter,
                selectedPhotoIds: selectedPhotoIds
            ) { sourceDeleted in
                isPhotoSelectMode = false
                selectedPhotoIds.removeAll()
            }
        }
        .alert("Delete Encounter?", isPresented: $showDeleteEncounterConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(encounter)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This encounter and its photos will be permanently deleted.")
        }
    }

    // MARK: - Face Label Picker Sheet

    @ViewBuilder
    private var faceLabelPickerSheet: some View {
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
                                assignPersonToFace(match.person)
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

                // Other people (not in top matches)
                let matchedPersonIds = Set(potentialMatches.map { $0.person.id })
                let otherPeople = allPeople.filter { !matchedPersonIds.contains($0.id) }

                if !otherPeople.isEmpty {
                    Section("Other People") {
                        ForEach(otherPeople) { person in
                            Button {
                                assignPersonToFace(person)
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

                // Add new person option
                Section {
                    Button {
                        showFaceLabelPicker = false
                        showNewPersonSheet = true
                    } label: {
                        Label("Add New Person", systemImage: "person.badge.plus")
                    }
                }

                // Option to remove label
                if let boxId = selectedBoxId {
                    let hasLabel = findBox(by: boxId)?.personId != nil
                    if hasLabel {
                        Section {
                            Button(role: .destructive) {
                                removePersonFromFace()
                            } label: {
                                Label("Remove Label", systemImage: "xmark.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Who is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFaceLabelPicker = false
                        selectedBoxId = nil
                        selectedPhotoForLabeling = nil
                        selectedFaceCrop = nil
                        potentialMatches = []
                    }
                }
            }
            .onAppear {
                loadFaceCropAndMatches()
            }
        }
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
        guard let boxId = selectedBoxId,
              let box = findBox(by: boxId) else { return }

        // Get the source image
        let sourceImage: UIImage?
        if let photo = selectedPhotoForLabeling {
            sourceImage = UIImage(data: photo.imageData)
        } else {
            sourceImage = encounter.displayImageData.flatMap { UIImage(data: $0) }
        }

        guard let image = sourceImage else { return }

        // Extract face crop from bounding box
        let imageSize = image.size
        let cropRect = CGRect(
            x: box.x * imageSize.width,
            y: (1 - box.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )

        // Add some padding around the face
        let padding: CGFloat = 0.2
        let paddedRect = cropRect.insetBy(
            dx: -cropRect.width * padding,
            dy: -cropRect.height * padding
        ).intersection(CGRect(origin: .zero, size: imageSize))

        if let cgImage = image.cgImage?.cropping(to: paddedRect) {
            selectedFaceCrop = UIImage(cgImage: cgImage)
        }

        // Find potential matches (including session-tagged faces)
        guard let faceCrop = selectedFaceCrop else { return }

        isLoadingMatches = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: faceCrop)

                // First check session embeddings for quick matches from this editing session
                var sessionMatches: [MatchResult] = []
                for (_, cached) in sessionEmbeddings {
                    let similarity = cosineSimilarity(embedding, cached.embedding)
                    if similarity >= 0.5 {
                        if let person = allPeople.first(where: { $0.id == cached.personId }) {
                            let confidence: MatchConfidence = similarity >= 0.85 ? .high : (similarity >= 0.75 ? .ambiguous : .none)
                            sessionMatches.append(MatchResult(person: person, similarity: similarity, confidence: confidence))
                        }
                    }
                }

                // Get regular matches from stored embeddings
                // Boost persons already in this encounter to encourage consistent labeling
                let encounterPersonIds = Set((encounter.people ?? []).map { $0.id })
                let regularMatches = matchingService.findMatches(for: embedding, in: allPeople, topK: 5, threshold: 0.5, boostPersonIds: encounterPersonIds)

                // Merge matches, preferring higher similarity and removing duplicates
                var allMatches: [UUID: MatchResult] = [:]
                for match in sessionMatches {
                    if let existing = allMatches[match.person.id] {
                        if match.similarity > existing.similarity {
                            allMatches[match.person.id] = match
                        }
                    } else {
                        allMatches[match.person.id] = match
                    }
                }
                for match in regularMatches {
                    if let existing = allMatches[match.person.id] {
                        if match.similarity > existing.similarity {
                            allMatches[match.person.id] = match
                        }
                    } else {
                        allMatches[match.person.id] = match
                    }
                }

                // Sort by similarity and take top 5
                let sortedMatches = allMatches.values.sorted { $0.similarity > $1.similarity }

                await MainActor.run {
                    potentialMatches = Array(sortedMatches.prefix(5))
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
        NewPersonSheetContent(
            faceCropImage: selectedFaceCrop,
            name: $newPersonName,
            confirmLabel: "Add",
            onConfirm: { createAndAssignPerson() },
            onCancel: { newPersonName = ""; showNewPersonSheet = false }
        )
    }

    // MARK: - Face Labeling Helpers

    private func findBox(by id: UUID) -> FaceBoundingBox? {
        // Check in multi-photo encounter
        if let photo = selectedPhotoForLabeling {
            return photo.faceBoundingBoxes.first { $0.id == id }
        }
        // Check in legacy single-photo
        return encounter.faceBoundingBoxes.first { $0.id == id }
    }

    private func assignPersonToFace(_ person: Person) {
        guard let boxId = selectedBoxId else { return }

        if let photo = selectedPhotoForLabeling {
            // Multi-photo encounter
            var boxes = photo.faceBoundingBoxes
            if let index = boxes.firstIndex(where: { $0.id == boxId }) {
                boxes[index].personId = person.id
                boxes[index].personName = person.name
                photo.faceBoundingBoxes = boxes

                // Generate embedding and propagate to other photos
                propagateFaceLabelToOtherPhotos(
                    person: person,
                    sourceBox: boxes[index],
                    sourcePhoto: photo
                )
            }
        } else {
            // Legacy single-photo
            var boxes = encounter.faceBoundingBoxes
            if let index = boxes.firstIndex(where: { $0.id == boxId }) {
                boxes[index].personId = person.id
                boxes[index].personName = person.name
                encounter.faceBoundingBoxes = boxes
            }
        }

        // Link person to encounter if not already
        if !(encounter.people ?? []).contains(where: { $0.id == person.id }) {
            encounter.people = (encounter.people ?? []) + [person]
        }

        // Create embedding for this face assignment (pass boxId for re-label tracking)
        if let faceCrop = selectedFaceCrop, let boxId = selectedBoxId {
            addEmbeddingToPerson(person, faceCrop: faceCrop, boundingBoxId: boxId)
        }

        showFaceLabelPicker = false
        selectedBoxId = nil
        selectedPhotoForLabeling = nil
    }

    /// Add face embedding to person with auto-profile assignment
    /// Handles re-labeling by removing old embedding if face was previously assigned
    private func addEmbeddingToPerson(_ person: Person, faceCrop: UIImage, boundingBoxId: UUID) {
        // First, remove any existing embedding for this bounding box (handles re-labeling)
        removeExistingEmbedding(for: boundingBoxId)

        Task {
            let embeddingService = FaceEmbeddingService()
            do {
                let embedding = try await embeddingService.generateEmbedding(for: faceCrop)
                let vectorData = embedding.withUnsafeBytes { Data($0) }
                let imageData = faceCrop.jpegData(compressionQuality: 0.8) ?? Data()

                await MainActor.run {
                    let faceEmbedding = FaceEmbedding(
                        vector: vectorData,
                        faceCropData: imageData,
                        encounterId: encounter.id,
                        boundingBoxId: boundingBoxId
                    )
                    faceEmbedding.person = person
                    modelContext.insert(faceEmbedding)
                    person.lastSeenAt = Date()

                    // Auto-assign as profile photo if person has none
                    if person.profileEmbeddingId == nil {
                        person.profileEmbeddingId = faceEmbedding.id
                    }
                }
            } catch {
                print("Error adding embedding: \(error)")
            }
        }
    }

    /// Remove existing embedding for a bounding box (used when re-labeling faces)
    private func removeExistingEmbedding(for boundingBoxId: UUID) {
        let encId = encounter.id
        let descriptor = FetchDescriptor<FaceEmbedding>(
            predicate: #Predicate { embedding in
                embedding.boundingBoxId == boundingBoxId && embedding.encounterId == encId
            }
        )

        if let existingEmbeddings = try? modelContext.fetch(descriptor) {
            for embedding in existingEmbeddings {
                // If this was someone's profile photo, clear that reference
                if let oldPerson = embedding.person, oldPerson.profileEmbeddingId == embedding.id {
                    oldPerson.profileEmbeddingId = nil
                }
                modelContext.delete(embedding)
            }
        }
    }

    /// Propagate face label to similar faces in other photos of the same encounter
    private func propagateFaceLabelToOtherPhotos(person: Person, sourceBox: FaceBoundingBox, sourcePhoto: EncounterPhoto) {
        let otherPhotos = (encounter.photos ?? []).filter { $0.id != sourcePhoto.id }
        guard !otherPhotos.isEmpty else { return }

        isPropagating = true

        Task {
            defer {
                Task { @MainActor in
                    isPropagating = false
                }
            }

            do {
                let embeddingService = FaceEmbeddingService()
                let propagationThreshold: Float = min(AppSettings.shared.autoAcceptThreshold, 0.85)

                guard let sourceImage = UIImage(data: sourcePhoto.imageData) else { return }
                let sourceRect = extractFaceRect(box: sourceBox, imageSize: sourceImage.size)
                guard let sourceCGImage = sourceImage.cgImage?.cropping(to: sourceRect) else { return }
                let sourceFaceCrop = UIImage(cgImage: sourceCGImage)

                let sourceEmbedding = try await embeddingService.generateEmbedding(for: sourceFaceCrop)

                await MainActor.run {
                    sessionEmbeddings[sourceBox.id] = (personId: person.id, embedding: sourceEmbedding)
                }

                for photo in otherPhotos {
                    guard let photoImage = UIImage(data: photo.imageData) else { continue }

                    var updatedBoxes = photo.faceBoundingBoxes
                    var hasChanges = false

                    for (index, box) in updatedBoxes.enumerated() {
                        guard box.personId == nil else { continue }

                        let faceRect = extractFaceRect(box: box, imageSize: photoImage.size)
                        guard let faceCGImage = photoImage.cgImage?.cropping(to: faceRect) else { continue }
                        let faceCrop = UIImage(cgImage: faceCGImage)

                        let faceEmbedding = try await embeddingService.generateEmbedding(for: faceCrop)
                        let similarity = cosineSimilarity(sourceEmbedding, faceEmbedding)

                        if similarity >= propagationThreshold {
                            updatedBoxes[index].personId = person.id
                            updatedBoxes[index].personName = person.name
                            updatedBoxes[index].confidence = similarity
                            updatedBoxes[index].isAutoAccepted = true
                            hasChanges = true

                            await MainActor.run {
                                sessionEmbeddings[box.id] = (personId: person.id, embedding: faceEmbedding)
                            }
                        }
                    }

                    if hasChanges {
                        await MainActor.run {
                            photo.faceBoundingBoxes = updatedBoxes
                        }
                    }
                }
            } catch {
                // Silently handle errors
            }
        }
    }

    /// Extract face rect from bounding box (with padding)
    private func extractFaceRect(box: FaceBoundingBox, imageSize: CGSize) -> CGRect {
        let cropRect = CGRect(
            x: box.x * imageSize.width,
            y: (1 - box.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )

        // Add padding around the face
        let padding: CGFloat = 0.15
        return cropRect.insetBy(
            dx: -cropRect.width * padding,
            dy: -cropRect.height * padding
        ).intersection(CGRect(origin: .zero, size: imageSize))
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

    private func removePersonFromFace() {
        guard let boxId = selectedBoxId else { return }

        var removedPersonId: UUID?

        if let photo = selectedPhotoForLabeling {
            // Multi-photo encounter
            var boxes = photo.faceBoundingBoxes
            if let index = boxes.firstIndex(where: { $0.id == boxId }) {
                removedPersonId = boxes[index].personId
                boxes[index].personId = nil
                boxes[index].personName = nil
                photo.faceBoundingBoxes = boxes
            }
        } else {
            // Legacy single-photo
            var boxes = encounter.faceBoundingBoxes
            if let index = boxes.firstIndex(where: { $0.id == boxId }) {
                removedPersonId = boxes[index].personId
                boxes[index].personId = nil
                boxes[index].personName = nil
                encounter.faceBoundingBoxes = boxes
            }
        }

        // Check if person should be unlinked from encounter
        if let personId = removedPersonId {
            let stillHasFaces = checkPersonHasFacesInEncounter(personId)
            if !stillHasFaces {
                encounter.people = (encounter.people ?? []).filter { $0.id != personId }
            }
        }

        showFaceLabelPicker = false
        selectedBoxId = nil
        selectedPhotoForLabeling = nil
    }

    private func checkPersonHasFacesInEncounter(_ personId: UUID) -> Bool {
        // Check all photos
        for photo in encounter.photos ?? [] {
            if photo.faceBoundingBoxes.contains(where: { $0.personId == personId }) {
                return true
            }
        }
        // Check legacy
        if encounter.faceBoundingBoxes.contains(where: { $0.personId == personId }) {
            return true
        }
        return false
    }

    private func createAndAssignPerson() {
        let person = Person(name: newPersonName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(person)

        assignPersonToFace(person)

        newPersonName = ""
        showNewPersonSheet = false
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)

            InlineTagEditor(
                tags: encounter.tags ?? [],
                onAddTag: {
                    selectedTags = encounter.tags ?? []
                    showTagPicker = true
                },
                onRemoveTag: { tag in
                    encounter.tags = (encounter.tags ?? []).filter { $0.id != tag.id }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var photoSection: some View {
        if hasMultiplePhotos && isPhotoSelectMode {
            // Photo selection grid for move mode
            photoSelectionGrid
        } else if hasMultiplePhotos {
            // Multiple photos carousel
            VStack(spacing: 8) {
                TabView(selection: $selectedPhotoIndex) {
                    ForEach(Array(encounter.sortedPhotos.enumerated()), id: \.element.id) { index, photo in
                        photoCard(for: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 300)

                if isPropagating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Auto-tagging similar faces...")
                            .font(.caption2)
                            .foregroundStyle(AppColors.teal)
                    }
                } else if locateFaceMode {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap")
                            Text("Tap where you see a face")
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
                } else if lastAddedFaceId != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.success)
                        Text("Face added")
                            .font(.caption)
                            .foregroundStyle(AppColors.success)

                        Spacer()

                        Button {
                            undoLastAddedFace()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo")
                            }
                            .font(.caption)
                            .foregroundStyle(AppColors.coral)
                        }
                    }
                } else {
                    Text("\(selectedPhotoIndex + 1) of \((encounter.photos ?? []).count) photos • Tap to expand")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else if let imageData = encounter.displayImageData, let image = UIImage(data: imageData) {
            // Legacy single photo
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if locateFaceMode {
                            handleLocateFaceTap(at: location, in: geometry.size, imageSize: image.size, photo: nil, image: image)
                        } else if !isEditing {
                            showFullPhoto = true
                        }
                    }
                    .allowsHitTesting(!isEditing || locateFaceMode)
                    .overlay {
                        if isEditing || locateFaceMode || AppSettings.shared.showBoundingBoxes {
                            ForEach(encounter.faceBoundingBoxes) { box in
                                FaceBoxOverlay(
                                    box: box,
                                    imageSize: image.size,
                                    viewSize: geometry.size,
                                    onTap: {
                                        if !locateFaceMode {
                                            handleFaceBoxTap(box: box, photo: nil)
                                        }
                                    }
                                )
                            }
                        }
                    }
            }
            .aspectRatio(image.size, contentMode: .fit)

            if locateFaceMode {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                        Text("Tap where you see a face")
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
            } else if lastAddedFaceId != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text("Face added")
                        .font(.caption)
                        .foregroundStyle(AppColors.success)

                    Spacer()

                    Button {
                        undoLastAddedFace()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.coral)
                    }
                }
            } else if isEditing {
                Text("Tap any face to label or update")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else {
                Text("Tap photo to expand, tap face to view profile")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else {
            // No image data available - show placeholder
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Loading image...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    // MARK: - Photo Selection Grid (for Move)

    @ViewBuilder
    private var photoSelectionGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select photos to move")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") {
                    withAnimation {
                        isPhotoSelectMode = false
                        selectedPhotoIds.removeAll()
                    }
                }
                .font(.subheadline)
            }

            let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(encounter.sortedPhotos) { photo in
                    Button {
                        togglePhotoSelection(photo.id)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            if let image = UIImage(data: photo.imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minHeight: 100)
                                    .clipped()
                            }

                            Image(systemName: selectedPhotoIds.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedPhotoIds.contains(photo.id) ? AppColors.teal : .white)
                                .shadow(radius: 2)
                                .padding(6)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if selectedPhotoIds.contains(photo.id) {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.teal, lineWidth: 3)
                            }
                        }
                    }
                }
            }

            if !selectedPhotoIds.isEmpty {
                let allSelected = selectedPhotoIds.count == (encounter.photos ?? []).count
                Button {
                    showMoveDestination = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Move \(selectedPhotoIds.count) Photo\(selectedPhotoIds.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if allSelected {
                    Text("Moving all photos will delete this encounter")
                        .font(.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }
        }
    }

    private func togglePhotoSelection(_ id: UUID) {
        if selectedPhotoIds.contains(id) {
            selectedPhotoIds.remove(id)
        } else {
            selectedPhotoIds.insert(id)
        }
    }

    private func handleFaceBoxTap(box: FaceBoundingBox, photo: EncounterPhoto?) {
        if let personId = box.personId {
            // Already labeled - navigate to person profile (unless editing)
            if !isEditing {
                selectedPerson = (encounter.people ?? []).first { $0.id == personId }
            } else {
                // In edit mode, allow relabeling
                selectedBoxId = box.id
                selectedPhotoForLabeling = photo
                showFaceLabelPicker = true
            }
        } else {
            // Unlabeled face - always allow labeling
            selectedBoxId = box.id
            selectedPhotoForLabeling = photo
            showFaceLabelPicker = true
        }
    }

    @ViewBuilder
    private func photoCard(for photo: EncounterPhoto) -> some View {
        GeometryReader { geometry in
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if locateFaceMode {
                            handleLocateFaceTap(at: location, in: geometry.size, imageSize: image.size, photo: photo, image: image)
                        } else if !isEditing {
                            showFullPhoto = true
                        }
                    }
                    .allowsHitTesting(!isEditing || locateFaceMode)
                    .overlay {
                        if isEditing || locateFaceMode || AppSettings.shared.showBoundingBoxes {
                            ForEach(photo.faceBoundingBoxes) { box in
                                FaceBoxOverlay(
                                    box: box,
                                    imageSize: image.size,
                                    viewSize: geometry.size,
                                    onTap: {
                                        if !locateFaceMode {
                                            handleFaceBoxTap(box: box, photo: photo)
                                        }
                                    }
                                )
                            }
                        }
                    }
            } else {
                // Placeholder when image data not loaded yet
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Loading...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People")
                .font(.headline)

            if (encounter.people ?? []).isEmpty {
                Text("No people identified")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(encounter.people ?? []) { person in
                    HStack {
                        NavigationLink(value: person) {
                            HStack {
                                if let firstEmbedding = person.embeddings?.first,
                                   let image = UIImage(data: firstEmbedding.faceCropData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading) {
                                    Text(person.name)
                                        .fontWeight(.medium)

                                    if let company = person.company {
                                        Text(company)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if !isEditing {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .disabled(isEditing)

                        if isEditing {
                            Button {
                                personToRemove = person
                                showRemovePersonConfirmation = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .alert("Remove Person", isPresented: $showRemovePersonConfirmation) {
            Button("Cancel", role: .cancel) {
                personToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let person = personToRemove {
                    removePersonFromEncounter(person)
                }
                personToRemove = nil
            }
        } message: {
            if let person = personToRemove {
                Text("Remove \(person.name) from this encounter? This will unlink all their face labels from this encounter.")
            }
        }
        .navigationDestination(for: Person.self) { person in
            PersonDetailView(person: person)
        }
    }

    /// Remove a person from this encounter, clearing all associated links
    private func removePersonFromEncounter(_ person: Person) {
        let encounterId = encounter.id

        // Remove person's face labels from all bounding boxes in this encounter
        for photo in encounter.photos ?? [] {
            var boxes = photo.faceBoundingBoxes
            for i in boxes.indices where boxes[i].personId == person.id {
                boxes[i].personId = nil
                boxes[i].personName = nil
            }
            photo.faceBoundingBoxes = boxes
        }

        // Also check legacy single-photo bounding boxes
        var legacyBoxes = encounter.faceBoundingBoxes
        for i in legacyBoxes.indices where legacyBoxes[i].personId == person.id {
            legacyBoxes[i].personId = nil
            legacyBoxes[i].personName = nil
        }
        encounter.faceBoundingBoxes = legacyBoxes

        // Delete all embeddings linking this person to this encounter
        let embeddingsToDelete = (person.embeddings ?? []).filter { $0.encounterId == encounterId }
        for embedding in embeddingsToDelete {
            // Clear profile photo reference if needed
            if person.profileEmbeddingId == embedding.id {
                person.profileEmbeddingId = nil
            }
            modelContext.delete(embedding)
        }

        // Remove person from encounter's people list
        encounter.people = (encounter.people ?? []).filter { $0.id != person.id }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            if isEditing {
                editableDetails
            } else {
                readOnlyDetails
            }
        }
    }

    @ViewBuilder
    private var readOnlyDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(
                icon: "calendar",
                title: String(localized: "Date"),
                value: encounter.date.formatted(date: .long, time: .shortened)
            )

            if let occasion = encounter.occasion, !occasion.isEmpty {
                DetailRow(icon: "star", title: String(localized: "Occasion"), value: occasion)
            }

            if let location = encounter.location, !location.isEmpty {
                DetailRow(icon: "mappin", title: String(localized: "Location"), value: location)
            }

            // Show GPS coordinates with map link
            if encounter.hasCoordinates, let lat = encounter.latitude, let lon = encounter.longitude {
                HStack {
                    Label("GPS", systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.body)

                    Spacer()

                    if let url = encounter.mapsURL {
                        Link(destination: url) {
                            Image(systemName: "map")
                            Text("Open")
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let notes = encounter.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(notes)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Manual Face Location

    private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize, photo: EncounterPhoto?, image: UIImage) {
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
                let cropSize = min(imageSize.width, imageSize.height) * 0.4 // 40% of smaller dimension
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
                    // cropRect.maxY is the bottom of crop in top-left coords
                    // In Vision coords, crop bottom = 1 - cropRect.maxY/imageSize.height
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

                        // Automatically trigger labeling for the newly detected face
                        selectedBoxId = newBox.id
                        selectedPhotoForLabeling = photo
                        showFaceLabelPicker = true
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
           let photo = (encounter.photos ?? []).first(where: { $0.id == photoId }) {
            photo.faceBoundingBoxes.removeAll { $0.id == faceId }
        } else {
            encounter.faceBoundingBoxes.removeAll { $0.id == faceId }
        }

        lastAddedFaceId = nil
        lastAddedFacePhotoId = nil
    }

    /// Re-detect faces in all photos using tiled crop-detect-transfer approach
    /// This detects faces more reliably by scanning overlapping regions
    private func redetectFaces() async {
        isRedetecting = true
        defer {
            Task { @MainActor in
                isRedetecting = false
            }
        }

        // Handle multi-photo encounters
        for photo in encounter.photos ?? [] {
            guard let image = UIImage(data: photo.imageData) else { continue }
            let oldBoxes = photo.faceBoundingBoxes

            let newBoxes = await detectFacesWithTiling(in: image, oldBoxes: oldBoxes)

            await MainActor.run {
                photo.faceBoundingBoxes = newBoxes
            }
        }

        // Handle legacy single-photo encounter
        if (encounter.photos ?? []).isEmpty, let imageData = encounter.imageData, let image = UIImage(data: imageData) {
            let oldBoxes = encounter.faceBoundingBoxes

            let newBoxes = await detectFacesWithTiling(in: image, oldBoxes: oldBoxes)

            await MainActor.run {
                encounter.faceBoundingBoxes = newBoxes
            }
        }
    }

    /// Detect faces using tiled crop-detect-coordinate-transfer approach
    private func detectFacesWithTiling(in image: UIImage, oldBoxes: [FaceBoundingBox]) async -> [FaceBoundingBox] {
        let faceDetectionService = FaceDetectionService()
        let imageSize = image.size

        // First, run full-image detection
        var allDetectedBoxes: [FaceBoundingBox] = []

        do {
            let fullImageFaces = try await faceDetectionService.detectFaces(in: image, options: .enhanced)
            for face in fullImageFaces {
                let box = FaceBoundingBox(
                    rect: face.normalizedBoundingBox,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )
                allDetectedBoxes.append(box)
            }
        } catch {
            print("Full image detection error: \(error)")
        }

        // Then, run tiled detection with overlapping regions
        // Use a 3x3 grid with 50% overlap for better coverage
        let tileOverlap: CGFloat = 0.5
        let tilesPerAxis = 3

        for row in 0..<tilesPerAxis {
            for col in 0..<tilesPerAxis {
                // Calculate tile region with overlap
                let tileWidth = imageSize.width / CGFloat(tilesPerAxis - 1 + 1) * (1 + tileOverlap)
                let tileHeight = imageSize.height / CGFloat(tilesPerAxis - 1 + 1) * (1 + tileOverlap)

                let stepX = (imageSize.width - tileWidth) / CGFloat(max(1, tilesPerAxis - 1))
                let stepY = (imageSize.height - tileHeight) / CGFloat(max(1, tilesPerAxis - 1))

                let cropRect = CGRect(
                    x: CGFloat(col) * stepX,
                    y: CGFloat(row) * stepY,
                    width: min(tileWidth, imageSize.width - CGFloat(col) * stepX),
                    height: min(tileHeight, imageSize.height - CGFloat(row) * stepY)
                )

                // Skip tiles that are too small
                guard cropRect.width > 100 && cropRect.height > 100 else { continue }

                // Crop the tile
                guard let cgImage = image.cgImage?.cropping(to: cropRect) else { continue }
                let croppedImage = UIImage(cgImage: cgImage)

                do {
                    let faces = try await faceDetectionService.detectFaces(in: croppedImage, options: .enhanced)

                    for face in faces {
                        // Transform coordinates from tile space to original image space
                        let cropNormRect = face.normalizedBoundingBox

                        // X coordinate transformation
                        let originalX = (cropRect.origin.x + cropNormRect.origin.x * cropRect.width) / imageSize.width
                        let originalWidth = (cropNormRect.width * cropRect.width) / imageSize.width

                        // Y coordinate: convert from Vision (bottom-left) coords
                        let cropBottomNorm = 1.0 - (cropRect.origin.y + cropRect.height) / imageSize.height
                        let cropHeightNorm = cropRect.height / imageSize.height
                        let originalY = cropBottomNorm + cropNormRect.origin.y * cropHeightNorm
                        let originalHeight = cropNormRect.height * cropHeightNorm

                        let transformedBox = FaceBoundingBox(
                            rect: CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight),
                            personId: nil,
                            personName: nil,
                            confidence: nil,
                            isAutoAccepted: false
                        )

                        allDetectedBoxes.append(transformedBox)
                    }
                } catch {
                    // Continue with other tiles
                }
            }
        }

        // Deduplicate overlapping detections using NMS (Non-Maximum Suppression)
        let deduplicatedBoxes = nonMaximumSuppression(boxes: allDetectedBoxes, iouThreshold: 0.4)

        // Transfer person labels from old boxes to new boxes
        var finalBoxes = deduplicatedBoxes
        for oldBox in oldBoxes where oldBox.personId != nil {
            let oldRect = CGRect(x: oldBox.x, y: oldBox.y, width: oldBox.width, height: oldBox.height)

            var bestMatchIndex: Int?
            var bestIoU: CGFloat = 0.25 // Lower threshold since re-detection may shift boxes

            for (index, newBox) in finalBoxes.enumerated() where newBox.personId == nil {
                let newRect = CGRect(x: newBox.x, y: newBox.y, width: newBox.width, height: newBox.height)
                let iou = calculateIoU(oldRect, newRect)

                if iou > bestIoU {
                    bestIoU = iou
                    bestMatchIndex = index
                }
            }

            if let matchIndex = bestMatchIndex {
                finalBoxes[matchIndex].personId = oldBox.personId
                finalBoxes[matchIndex].personName = oldBox.personName
            }
        }

        return finalBoxes
    }

    /// Non-Maximum Suppression to remove duplicate detections
    private func nonMaximumSuppression(boxes: [FaceBoundingBox], iouThreshold: CGFloat) -> [FaceBoundingBox] {
        guard !boxes.isEmpty else { return [] }

        // Sort by area (larger boxes first - they're usually more reliable)
        let sortedBoxes = boxes.sorted {
            ($0.width * $0.height) > ($1.width * $1.height)
        }

        var selectedBoxes: [FaceBoundingBox] = []

        for box in sortedBoxes {
            let boxRect = CGRect(x: box.x, y: box.y, width: box.width, height: box.height)

            // Check if this box overlaps significantly with any selected box
            let overlapsWithSelected = selectedBoxes.contains { selected in
                let selectedRect = CGRect(x: selected.x, y: selected.y, width: selected.width, height: selected.height)
                return calculateIoU(boxRect, selectedRect) > iouThreshold
            }

            if !overlapsWithSelected {
                selectedBoxes.append(box)
            }
        }

        return selectedBoxes
    }

    /// Calculate Intersection over Union for two rectangles
    private func calculateIoU(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let intersection = rect1.intersection(rect2)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = rect1.width * rect1.height + rect2.width * rect2.height - intersectionArea

        return unionArea > 0 ? intersectionArea / unionArea : 0
    }

    @ViewBuilder
    private var editableDetails: some View {
        VStack(spacing: 12) {
            TextField("Occasion", text: Binding(
                get: { encounter.occasion ?? "" },
                set: { encounter.occasion = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Location", text: Binding(
                get: { encounter.location ?? "" },
                set: { encounter.location = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading) {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: Binding(
                    get: { encounter.notes ?? "" },
                    set: { encounter.notes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FaceBoxOverlay: View {
    let box: FaceBoundingBox
    let imageSize: CGSize
    let viewSize: CGSize
    var onTap: (() -> Void)? = nil

    var body: some View {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        let x = offsetX + box.x * scaledWidth
        let y = offsetY + (1 - box.y - box.height) * scaledHeight
        let width = box.width * scaledWidth
        let height = box.height * scaledHeight

        // Ensure minimum 44pt tap target per Apple HIG
        let tapWidth = max(width, 44)
        let tapHeight = max(height, 44)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(box.personId != nil ? Color.blue : Color.orange, lineWidth: 2)
                .frame(width: width, height: height)

            if let name = box.personName {
                Text(name)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(box.personId != nil ? Color.blue : Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .offset(y: 16)
            }
        }
        .frame(width: tapWidth, height: tapHeight)
        .contentShape(Rectangle())
        .position(x: x + width / 2, y: y + height / 2)
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Zoomable Container
struct ZoomableContainer<Content: View>: View {
    let content: () -> Content

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnifyGesture)
            .simultaneousGesture(dragGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    if scale > 1.01 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, 0.5), 5.0)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    if scale < 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.01 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                if scale <= 1.01 {
                    withAnimation(.spring(response: 0.3)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
}

// MARK: - Full Photo View (Legacy single photo)
struct FullPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let encounter: Encounter
    let onSelectPerson: (Person) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    if let imageData = encounter.displayImageData, let image = UIImage(data: imageData) {
                        ZoomableContainer {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                .overlay {
                                    if AppSettings.shared.showBoundingBoxes {
                                        GeometryReader { imageGeometry in
                                            ForEach(encounter.faceBoundingBoxes) { box in
                                                FaceBoxOverlay(
                                                    box: box,
                                                    imageSize: image.size,
                                                    viewSize: imageGeometry.size,
                                                    onTap: {
                                                        if let personId = box.personId,
                                                           let person = (encounter.people ?? []).first(where: { $0.id == personId }) {
                                                            onSelectPerson(person)
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Multi Photo Full View
struct MultiPhotoFullView: View {
    @Environment(\.dismiss) private var dismiss
    let encounter: Encounter
    let initialIndex: Int
    let onSelectPerson: (Person) -> Void

    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(encounter.sortedPhotos.enumerated()), id: \.element.id) { index, photo in
                        fullPhotoPage(for: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) / \((encounter.photos ?? []).count)")
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            currentIndex = initialIndex
        }
    }

    @ViewBuilder
    private func fullPhotoPage(for photo: EncounterPhoto) -> some View {
        GeometryReader { geometry in
            if let image = UIImage(data: photo.imageData) {
                ZoomableContainer {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .overlay {
                            if AppSettings.shared.showBoundingBoxes {
                                GeometryReader { imageGeometry in
                                    ForEach(photo.faceBoundingBoxes) { box in
                                        FaceBoxOverlay(
                                            box: box,
                                            imageSize: image.size,
                                            viewSize: imageGeometry.size,
                                            onTap: {
                                                if let personId = box.personId,
                                                   let person = (encounter.people ?? []).first(where: { $0.id == personId }) {
                                                    onSelectPerson(person)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
