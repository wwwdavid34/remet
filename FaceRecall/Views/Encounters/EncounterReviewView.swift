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
    @State private var showNewPersonSheet = false
    @State private var newPersonName = ""
    @State private var createdEmbeddings: [FaceEmbedding] = []

    // Face matching state for picker
    @State private var selectedFaceCrop: UIImage?
    @State private var potentialMatches: [MatchResult] = []
    @State private var isLoadingMatches = false

    private let scannerService = PhotoLibraryScannerService()
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
                                    selectedBoxIndex = index
                                    showPersonPicker = true
                                }
                            }
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
            Text("People in this photo")
                .font(.headline)

            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Analyzing faces...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(boundingBoxes.enumerated()), id: \.element.id) { index, box in
                    FaceRowView(
                        box: box,
                        index: index,
                        onTap: {
                            selectedBoxIndex = index
                            showPersonPicker = true
                        },
                        onClear: {
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
                let otherPeople = people.filter { !matchedPersonIds.contains($0.id) }

                if !otherPeople.isEmpty {
                    Section("Other People") {
                        ForEach(otherPeople) { person in
                            Button {
                                assignPerson(person)
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
                        showPersonPicker = false
                        showNewPersonSheet = true
                    } label: {
                        Label("Add New Person", systemImage: "person.badge.plus")
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
            .navigationTitle("Who is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPersonPicker = false
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

    private func removePersonFromFace() {
        guard let boxIndex = selectedBoxIndex,
              boxIndex < boundingBoxes.count else { return }

        boundingBoxes[boxIndex].personId = nil
        boundingBoxes[boxIndex].personName = nil
        boundingBoxes[boxIndex].confidence = nil
        boundingBoxes[boxIndex].isAutoAccepted = false

        showPersonPicker = false
        selectedFaceCrop = nil
        potentialMatches = []
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
        guard let boxIndex = selectedBoxIndex,
              boxIndex < scannedPhoto.detectedFaces.count else { return }

        let face = scannedPhoto.detectedFaces[boxIndex]
        selectedFaceCrop = face.cropImage

        // Find potential matches
        guard !people.isEmpty else { return }

        isLoadingMatches = true

        Task {
            do {
                let embeddingService = FaceEmbeddingService()
                let matchingService = FaceMatchingService()

                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                let matches = matchingService.findMatches(for: embedding, in: people, topK: 5, threshold: 0.5)

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
        NavigationStack {
            Form {
                if let index = selectedBoxIndex,
                   index < scannedPhoto.detectedFaces.count {
                    let face = scannedPhoto.detectedFaces[index]
                    HStack {
                        Spacer()
                        Image(uiImage: face.cropImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .clipShape(Circle())
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

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

        boundingBoxes[index].personId = person.id
        boundingBoxes[index].personName = person.name
        boundingBoxes[index].isAutoAccepted = false

        // Add embedding to person
        addEmbeddingToPerson(person, faceIndex: index)

        showPersonPicker = false
        selectedBoxIndex = nil
    }

    private func createAndAssignPerson() {
        guard let index = selectedBoxIndex else { return }

        let person = Person(name: newPersonName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(person)

        boundingBoxes[index].personId = person.id
        boundingBoxes[index].personName = person.name
        boundingBoxes[index].isAutoAccepted = false

        // Add embedding to person
        addEmbeddingToPerson(person, faceIndex: index)

        newPersonName = ""
        showNewPersonSheet = false
        selectedBoxIndex = nil
    }

    private func addEmbeddingToPerson(_ person: Person, faceIndex: Int) {
        guard faceIndex < scannedPhoto.detectedFaces.count else { return }
        let face = scannedPhoto.detectedFaces[faceIndex]

        Task {
            let embeddingService = FaceEmbeddingService()
            do {
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                let vectorData = embedding.withUnsafeBytes { Data($0) }
                let imageData = face.cropImage.jpegData(compressionQuality: 0.8) ?? Data()

                await MainActor.run {
                    let faceEmbedding = FaceEmbedding(
                        vector: vectorData,
                        faceCropData: imageData
                    )
                    faceEmbedding.person = person
                    modelContext.insert(faceEmbedding)
                    person.lastSeenAt = Date()
                    // Track embedding for later encounterId assignment
                    createdEmbeddings.append(faceEmbedding)
                }
            } catch {
                print("Error adding embedding: \(error)")
            }
        }
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
            imageData: imageData,
            occasion: occasion.isEmpty ? nil : occasion,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            latitude: latitude,
            longitude: longitude,
            date: scannedPhoto.date
        )

        encounter.faceBoundingBoxes = boundingBoxes

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

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isSelected ? 3 : 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(boxColor.opacity(0.1))
                )

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
        .frame(width: width, height: height)
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
