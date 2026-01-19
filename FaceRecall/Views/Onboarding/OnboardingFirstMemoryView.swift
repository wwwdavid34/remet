import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingFirstMemoryView: View {
    @Environment(\.modelContext) private var modelContext

    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotosPicker = false
    @State private var showFaceReview = false
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(String(localized: "Add Your First Memory"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(localized: "Import a photo with people you've met. We'll help you tag faces and remember their names."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)

            Spacer()

            // Photo import area
            VStack(spacing: 24) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.teal, lineWidth: 2)
                        )
                } else {
                    // Placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColors.teal.opacity(0.6))

                        Text(String(localized: "Choose a photo with people you know"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 280, height: 200)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Photo picker button
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                        Text(selectedImage == nil ? String(localized: "Choose Photo") : String(localized: "Choose Different"))
                    }
                    .font(.headline)
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if selectedImage != nil {
                    Button {
                        showFaceReview = true
                    } label: {
                        Text(String(localized: "Continue"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button(action: onSkip) {
                    Text(String(localized: "Skip for Now"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, selectedImage == nil ? 0 : 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .onChange(of: selectedItem) { _, newItem in
            loadImage(from: newItem)
        }
        .sheet(isPresented: $showFaceReview) {
            if let image = selectedImage {
                OnboardingFaceReviewView(
                    image: image,
                    onComplete: {
                        showFaceReview = false
                        onComplete()
                    },
                    onCancel: {
                        showFaceReview = false
                    }
                )
            }
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        isProcessing = true

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    isProcessing = false
                }
            } else {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Simplified Face Review for Onboarding

struct OnboardingFaceReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var existingPeople: [Person]

    let image: UIImage
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var detectedFaces: [DetectedFace] = []
    @State private var faceAssignments: [Int: FaceAssignment] = [:]
    @State private var isProcessing = false
    @State private var occasion = ""
    @State private var location = ""
    @State private var isMatching = false

    /// People with embeddings that can be matched (including "Me")
    private var matchablePeople: [Person] {
        existingPeople.filter { !$0.embeddings.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image with face indicators
                GeometryReader { geometry in
                    let imageSize = image.size
                    let viewSize = geometry.size
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

                        ForEach(detectedFaces.indices, id: \.self) { index in
                            let face = detectedFaces[index]
                            let rect = face.normalizedBoundingBox
                            let boxWidth = rect.width * scaledWidth
                            let boxHeight = rect.height * scaledHeight
                            let boxX = offsetX + rect.midX * scaledWidth
                            let boxY = offsetY + (1 - rect.midY) * scaledHeight

                            Rectangle()
                                .stroke(faceAssignments[index] != nil ? AppColors.teal : AppColors.coral, lineWidth: 2)
                                .frame(width: boxWidth, height: boxHeight)
                                .position(x: boxX, y: boxY)

                            // Face number badge
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(faceAssignments[index] != nil ? AppColors.teal : AppColors.coral))
                                .position(x: boxX - boxWidth/2 + 10, y: boxY - boxHeight/2 + 10)
                        }
                    }
                }
                .frame(maxHeight: 280)

                // Face assignment list
                List {
                    if detectedFaces.isEmpty || isMatching {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(isMatching ? String(localized: "Matching faces...") : String(localized: "Detecting faces..."))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            TextField(String(localized: "Occasion (e.g., Team lunch)"), text: $occasion)
                                .submitLabel(.next)
                            TextField(String(localized: "Location (optional)"), text: $location)
                                .submitLabel(.done)
                                .onSubmit {
                                    hideKeyboard()
                                }
                        } header: {
                            Text(String(localized: "Details"))
                        }

                        Section {
                            ForEach(detectedFaces.indices, id: \.self) { index in
                                FaceAssignmentRow(
                                    index: index,
                                    face: detectedFaces[index],
                                    assignment: Binding(
                                        get: { faceAssignments[index] },
                                        set: { faceAssignments[index] = $0 }
                                    ),
                                    existingPeople: existingPeople.filter { !$0.embeddings.isEmpty }
                                )
                            }
                        } header: {
                            Text(String(localized: "Faces (\(detectedFaces.count))"))
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(String(localized: "Tag Faces"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        saveEncounter()
                    }
                    .fontWeight(.semibold)
                    .disabled(faceAssignments.isEmpty || occasion.isEmpty)
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView(String(localized: "Saving..."))
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            detectFaces()
        }
    }

    private func detectFaces() {
        Task {
            do {
                let faceDetectionService = FaceDetectionService()
                let faces = try await faceDetectionService.detectFaces(in: image)
                await MainActor.run {
                    detectedFaces = faces
                    isMatching = true
                }

                // Auto-match faces against existing people (including "Me")
                await matchFacesAutomatically(faces: faces)

                await MainActor.run {
                    isMatching = false
                }
            } catch {
                await MainActor.run {
                    detectedFaces = []
                    isMatching = false
                }
            }
        }
    }

    private func matchFacesAutomatically(faces: [DetectedFace]) async {
        guard !matchablePeople.isEmpty else { return }

        let embeddingService = FaceEmbeddingService()
        let matchingService = FaceMatchingService()
        let autoAcceptThreshold = AppSettings.shared.autoAcceptThreshold

        for (index, face) in faces.enumerated() {
            do {
                // Generate embedding for this face
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)

                // Find best match among all people (including "Me")
                let matches = matchingService.findMatches(
                    for: embedding,
                    in: matchablePeople,
                    topK: 1,
                    threshold: Float(autoAcceptThreshold)
                )

                if let bestMatch = matches.first {
                    await MainActor.run {
                        // Auto-assign this face to the matched person
                        faceAssignments[index] = FaceAssignment(
                            name: bestMatch.person.name,
                            existingPerson: bestMatch.person,
                            isAutoMatched: true,
                            confidence: bestMatch.similarity
                        )
                    }
                }
            } catch {
                // Skip this face if embedding fails
                continue
            }
        }
    }

    private func saveEncounter() {
        guard !faceAssignments.isEmpty else { return }
        isProcessing = true

        Task {
            do {
                // Prepare image data
                let settings = AppSettings.shared
                let resizedImage = resizeImage(image, targetSize: settings.photoTargetSize)
                guard let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) else {
                    await MainActor.run { isProcessing = false }
                    return
                }

                // Create encounter
                let encounter = Encounter(
                    imageData: imageData,
                    occasion: occasion,
                    location: location.isEmpty ? nil : location,
                    date: Date()
                )

                // Process each face assignment
                let embeddingService = FaceEmbeddingService()
                var boundingBoxes: [FaceBoundingBox] = []

                for (index, face) in detectedFaces.enumerated() {
                    guard let assignment = faceAssignments[index] else {
                        // Unassigned face
                        let box = FaceBoundingBox(
                            rect: face.normalizedBoundingBox,
                            personId: nil,
                            personName: nil,
                            confidence: nil,
                            isAutoAccepted: false
                        )
                        boundingBoxes.append(box)
                        continue
                    }

                    let person: Person
                    if let existingPerson = assignment.existingPerson {
                        person = existingPerson
                    } else {
                        // Create new person
                        person = Person(name: assignment.name)

                        // Initialize spaced repetition
                        let srData = SpacedRepetitionData()
                        srData.person = person
                        person.spacedRepetitionData = srData

                        modelContext.insert(person)
                    }

                    // Generate embedding
                    let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                    if let faceData = face.cropImage.jpegData(compressionQuality: 0.8) {
                        let faceEmbedding = FaceEmbedding(
                            vector: embedding.withUnsafeBytes { Data($0) },
                            faceCropData: faceData
                        )
                        faceEmbedding.person = person
                        faceEmbedding.encounterId = encounter.id
                        person.embeddings.append(faceEmbedding)

                        if person.profileEmbeddingId == nil {
                            person.profileEmbeddingId = faceEmbedding.id
                        }
                    }

                    // Link person to encounter
                    if !encounter.people.contains(where: { $0.id == person.id }) {
                        encounter.people.append(person)
                        person.encounters.append(encounter)
                    }

                    let box = FaceBoundingBox(
                        rect: face.normalizedBoundingBox,
                        personId: person.id,
                        personName: person.name,
                        confidence: nil,
                        isAutoAccepted: false
                    )
                    boundingBoxes.append(box)
                }

                encounter.faceBoundingBoxes = boundingBoxes

                await MainActor.run {
                    modelContext.insert(encounter)
                    try? modelContext.save()
                    isProcessing = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        if ratio >= 1.0 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Face Assignment Model

struct FaceAssignment {
    var name: String
    var existingPerson: Person?
    var isAutoMatched: Bool = false
    var confidence: Float? = nil
}

// MARK: - Face Assignment Row

struct FaceAssignmentRow: View {
    let index: Int
    let face: DetectedFace
    @Binding var assignment: FaceAssignment?
    let existingPeople: [Person]

    @State private var name = ""
    @State private var showPeoplePicker = false

    /// Sort "Me" at the top, then alphabetically
    private var sortedPeople: [Person] {
        existingPeople.sorted { p1, p2 in
            if p1.isMe { return true }
            if p2.isMe { return false }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail
            Image(uiImage: face.cropImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(assignment != nil ? AppColors.teal : AppColors.coral, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(String(localized: "Face \(index + 1)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let assigned = assignment, assigned.isAutoMatched {
                        Text(String(localized: "Auto"))
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.teal)
                            .clipShape(Capsule())
                    }
                }

                if let assigned = assignment {
                    HStack(spacing: 6) {
                        Text(assigned.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Show "Me" badge if it's the user's profile
                        if assigned.existingPerson?.isMe == true {
                            Text(String(localized: "You"))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.softPurple)
                                .clipShape(Capsule())
                        }

                        // Show confidence if auto-matched
                        if let confidence = assigned.confidence {
                            Text("\(Int(confidence * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    TextField(String(localized: "Enter name"), text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .onChange(of: name) { _, newValue in
                            if !newValue.isEmpty {
                                assignment = FaceAssignment(name: newValue, existingPerson: nil)
                            } else {
                                assignment = nil
                            }
                        }
                }
            }

            Spacer()

            if assignment != nil {
                Button {
                    assignment = nil
                    name = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            } else if !existingPeople.isEmpty {
                Button {
                    showPeoplePicker = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .foregroundStyle(AppColors.teal)
                }
            }
        }
        .sheet(isPresented: $showPeoplePicker) {
            NavigationStack {
                List(sortedPeople) { person in
                    Button {
                        assignment = FaceAssignment(name: person.name, existingPerson: person)
                        name = person.name
                        showPeoplePicker = false
                    } label: {
                        HStack {
                            if let embedding = person.profileEmbedding,
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

                            Text(person.name)
                                .foregroundStyle(.primary)

                            if person.isMe {
                                Text(String(localized: "You"))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.softPurple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "Select Person"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) {
                            showPeoplePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    OnboardingFirstMemoryView(onComplete: {}, onSkip: {})
}
