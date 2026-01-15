import SwiftUI
import SwiftData

struct EncounterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPeople: [Person]
    @Bindable var encounter: Encounter

    @State private var isEditing = false
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

    // Check if this encounter has multiple photos
    private var hasMultiplePhotos: Bool {
        !encounter.photos.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoSection
                peopleSection
                detailsSection
            }
            .padding()
        }
        .navigationTitle(encounter.occasion ?? "Encounter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
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

        // Find potential matches
        guard let faceCrop = selectedFaceCrop, !allPeople.isEmpty else { return }

        isLoadingMatches = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: faceCrop)
                let matches = matchingService.findMatches(for: embedding, in: allPeople, topK: 5, threshold: 0.5)

                await MainActor.run {
                    potentialMatches = Array(matches.prefix(5)) // Top 5 matches
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
        NavigationStack {
            Form {
                TextField("Name", text: $newPersonName)
                    .textContentType(.name)
            }
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
                    Button("Add") {
                        createAndAssignPerson()
                    }
                    .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
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
        if !encounter.people.contains(where: { $0.id == person.id }) {
            encounter.people.append(person)
        }

        showFaceLabelPicker = false
        selectedBoxId = nil
        selectedPhotoForLabeling = nil
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
                encounter.people.removeAll { $0.id == personId }
            }
        }

        showFaceLabelPicker = false
        selectedBoxId = nil
        selectedPhotoForLabeling = nil
    }

    private func checkPersonHasFacesInEncounter(_ personId: UUID) -> Bool {
        // Check all photos
        for photo in encounter.photos {
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
    private var photoSection: some View {
        if hasMultiplePhotos {
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

                Text("\(selectedPhotoIndex + 1) of \(encounter.photos.count) photos • Tap to expand")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if let imageData = encounter.displayImageData, let image = UIImage(data: imageData) {
            // Legacy single photo
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isEditing {
                            showFullPhoto = true
                        }
                    }
                    .allowsHitTesting(!isEditing)
                    .overlay {
                        GeometryReader { geometry in
                            ForEach(encounter.faceBoundingBoxes) { box in
                                FaceBoxOverlay(
                                    box: box,
                                    imageSize: image.size,
                                    viewSize: geometry.size,
                                    onTap: {
                                        handleFaceBoxTap(box: box, photo: nil)
                                    }
                                )
                            }
                        }
                    }
            }

            if isEditing {
                Text("Tap any face to label or update")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else {
                Text("Tap photo to expand, tap face to view profile")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func handleFaceBoxTap(box: FaceBoundingBox, photo: EncounterPhoto?) {
        if let personId = box.personId {
            // Already labeled - navigate to person profile (unless editing)
            if !isEditing {
                selectedPerson = encounter.people.first { $0.id == personId }
            } else {
                // In edit mode, allow relabeling
                selectedBoxId = box.id
                selectedPhotoForLabeling = photo
                showFaceLabelPicker = true
            }
        } else if isEditing {
            // Unlabeled face in edit mode - show picker
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
                    .onTapGesture {
                        if !isEditing {
                            showFullPhoto = true
                        }
                    }
                    .allowsHitTesting(!isEditing)
                    .overlay {
                        ForEach(photo.faceBoundingBoxes) { box in
                            FaceBoxOverlay(
                                box: box,
                                imageSize: image.size,
                                viewSize: geometry.size,
                                onTap: {
                                    handleFaceBoxTap(box: box, photo: photo)
                                }
                            )
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

            if encounter.people.isEmpty {
                Text("No people identified")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(encounter.people) { person in
                    NavigationLink(value: person) {
                        HStack {
                            if let firstEmbedding = person.embeddings.first,
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

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationDestination(for: Person.self) { person in
            PersonDetailView(person: person)
        }
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
                title: "Date",
                value: encounter.date.formatted(date: .long, time: .shortened)
            )

            if let occasion = encounter.occasion, !occasion.isEmpty {
                DetailRow(icon: "star", title: "Occasion", value: occasion)
            }

            if let location = encounter.location, !location.isEmpty {
                DetailRow(icon: "mappin", title: "Location", value: location)
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

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(box.personId != nil ? Color.blue : Color.orange, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                )

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
        .frame(width: width, height: height)
        .position(x: x + width / 2, y: y + height / 2)
        .onTapGesture {
            onTap?()
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
            GeometryReader { geometry in
                if let imageData = encounter.displayImageData, let image = UIImage(data: imageData) {
                    ZStack {
                        Color.black.ignoresSafeArea()

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                GeometryReader { imageGeometry in
                                    ForEach(encounter.faceBoundingBoxes) { box in
                                        FaceBoxOverlay(
                                            box: box,
                                            imageSize: image.size,
                                            viewSize: imageGeometry.size,
                                            onTap: {
                                                if let personId = box.personId,
                                                   let person = encounter.people.first(where: { $0.id == personId }) {
                                                    onSelectPerson(person)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
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
                    Text("\(currentIndex + 1) / \(encounter.photos.count)")
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        GeometryReader { imageGeometry in
                            ForEach(photo.faceBoundingBoxes) { box in
                                FaceBoxOverlay(
                                    box: box,
                                    imageSize: image.size,
                                    viewSize: imageGeometry.size,
                                    onTap: {
                                        if let personId = box.personId,
                                           let person = encounter.people.first(where: { $0.id == personId }) {
                                            onSelectPerson(person)
                                        }
                                    }
                                )
                            }
                        }
                    }
            }
        }
    }
}
