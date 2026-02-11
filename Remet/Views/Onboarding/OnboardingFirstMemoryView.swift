import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingFirstMemoryView: View {
    @Environment(\.modelContext) private var modelContext

    let currentStep: Int
    let totalSteps: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotosPicker = false
    @State private var showFaceReview = false
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.top, 16)

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
    @State private var selectedFaceIndex: Int? = nil
    @FocusState private var focusedFaceIndex: Int?

    /// People with embeddings that can be matched (including "Me")
    private var matchablePeople: [Person] {
        existingPeople.filter { !($0.embeddings ?? []).isEmpty }
    }

    /// Count of unassigned faces
    private var unassignedCount: Int {
        detectedFaces.indices.filter { faceAssignments[$0] == nil }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructional tip banner
                if !detectedFaces.isEmpty && !isMatching {
                    instructionBanner
                }

                // Image with face indicators
                faceImageOverlay
                    .frame(maxHeight: 260)

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
                            HStack {
                                Text(String(localized: "Occasion"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(localized: "Required"))
                                    .font(.caption)
                                    .foregroundStyle(occasion.isEmpty ? AppColors.coral : .clear)
                            }
                            TextField(String(localized: "e.g., Team lunch, Birthday party"), text: $occasion)
                                .submitLabel(.next)
                            TextField(String(localized: "Location (optional)"), text: $location)
                                .submitLabel(.done)
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
                                    existingPeople: existingPeople.filter { !($0.embeddings ?? []).isEmpty },
                                    isHighlighted: selectedFaceIndex == index || focusedFaceIndex == index,
                                    focusBinding: $focusedFaceIndex,
                                    faceIndex: index
                                )
                            }
                        } header: {
                            HStack {
                                Text(String(localized: "Faces (\(detectedFaces.count))"))
                                if unassignedCount > 0 {
                                    Text("• \(unassignedCount) need names")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.coral)
                                }
                            }
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
                        focusedFaceIndex = nil
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        focusedFaceIndex = nil
                        saveEncounter()
                    }
                    .fontWeight(.semibold)
                    .disabled(faceAssignments.isEmpty || occasion.isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "Done")) {
                        focusedFaceIndex = nil
                    }
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
        .onChange(of: focusedFaceIndex) { _, newValue in
            // Sync selection when focus changes
            selectedFaceIndex = newValue
        }
    }

    // MARK: - Face Image Overlay

    @ViewBuilder
    private var faceImageOverlay: some View {
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
                    faceRectangleOverlay(
                        index: index,
                        scaledWidth: scaledWidth,
                        scaledHeight: scaledHeight,
                        offsetX: offsetX,
                        offsetY: offsetY
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func faceRectangleOverlay(
        index: Int,
        scaledWidth: CGFloat,
        scaledHeight: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let face = detectedFaces[index]
        let rect = face.normalizedBoundingBox
        let boxWidth = rect.width * scaledWidth
        let boxHeight = rect.height * scaledHeight
        let boxX = offsetX + rect.midX * scaledWidth
        let boxY = offsetY + (1 - rect.midY) * scaledHeight
        let isSelected = selectedFaceIndex == index || focusedFaceIndex == index
        let isAssigned = faceAssignments[index] != nil

        // Tappable face rectangle
        Rectangle()
            .stroke(
                isSelected ? AppColors.warmYellow : (isAssigned ? AppColors.teal : AppColors.coral),
                lineWidth: isSelected ? 3 : 2
            )
            .background(
                Rectangle()
                    .fill(isSelected ? AppColors.warmYellow.opacity(0.15) : Color.clear)
            )
            .frame(width: boxWidth, height: boxHeight)
            .position(x: boxX, y: boxY)
            .onTapGesture {
                selectFace(at: index)
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)

        // Face number badge
        Text("\(index + 1)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(6)
            .background(
                Circle().fill(
                    isSelected ? AppColors.warmYellow : (isAssigned ? AppColors.teal : AppColors.coral)
                )
            )
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .position(x: boxX - boxWidth/2 + 10, y: boxY - boxHeight/2 + 10)
            .onTapGesture {
                selectFace(at: index)
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Instruction Banner

    @ViewBuilder
    private var instructionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(AppColors.teal)

            Text(String(localized: "Tap a face to add their name"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Color legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.teal).frame(width: 8, height: 8)
                    Text(String(localized: "Named"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.coral).frame(width: 8, height: 8)
                    Text(String(localized: "Unnamed"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Face Selection

    private func selectFace(at index: Int) {
        selectedFaceIndex = index
        // Trigger focus on the corresponding input field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedFaceIndex = index
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
                        person.embeddings = (person.embeddings ?? []) + [faceEmbedding]

                        if person.profileEmbeddingId == nil {
                            person.profileEmbeddingId = faceEmbedding.id
                        }
                    }

                    // Link person to encounter
                    if !(encounter.people ?? []).contains(where: { $0.id == person.id }) {
                        encounter.people = (encounter.people ?? []) + [person]
                        person.encounters = (person.encounters ?? []) + [encounter]
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
    var isHighlighted: Bool = false
    var focusBinding: FocusState<Int?>.Binding?
    var faceIndex: Int = 0

    @State private var name = ""
    @State private var isEditing = false
    @State private var showPeoplePicker = false
    @FocusState private var isNameFocused: Bool

    /// Sort "Me" at the top, then alphabetically
    private var sortedPeople: [Person] {
        existingPeople.sorted { p1, p2 in
            if p1.isMe { return true }
            if p2.isMe { return false }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }
    }

    /// Whether to show the text field (no assignment, or editing a new person name)
    private var showTextField: Bool {
        assignment == nil || (assignment?.existingPerson == nil && isEditing)
    }

    /// Name text field with proper focus handling
    @ViewBuilder
    private var nameTextField: some View {
        let baseField = TextField(String(localized: "Enter name"), text: $name)
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)
            .submitLabel(.done)
            .onSubmit {
                commitName()
            }
            .onChange(of: isNameFocused) { _, focused in
                if focused {
                    isEditing = true
                } else {
                    commitName()
                }
            }

        if let binding = focusBinding {
            baseField
                .focused(binding, equals: faceIndex)
                .onChange(of: binding.wrappedValue) { _, newValue in
                    if newValue == faceIndex {
                        isEditing = true
                        isNameFocused = true
                    }
                }
        } else {
            baseField
                .focused($isNameFocused)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail with highlight ring
            ZStack {
                if isHighlighted {
                    Circle()
                        .fill(AppColors.warmYellow.opacity(0.3))
                        .frame(width: 58, height: 58)
                }

                Image(uiImage: face.cropImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                isHighlighted ? AppColors.warmYellow : (assignment != nil ? AppColors.teal : AppColors.coral),
                                lineWidth: isHighlighted ? 3 : 2
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(String(localized: "Face \(index + 1)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let assigned = assignment, assigned.isAutoMatched {
                        Text(String(localized: "Auto-matched"))
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.teal)
                            .clipShape(Capsule())
                            .help(String(localized: "Recognized from previous photos"))
                    }
                }

                if showTextField {
                    // Text field for entering new name
                    nameTextField
                } else if let assigned = assignment {
                    // Show assigned name (for existing people or confirmed new names)
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

                        // Show confidence if auto-matched with explanation
                        if let confidence = assigned.confidence {
                            HStack(spacing: 2) {
                                Text("\(Int(confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .help(String(localized: "Match confidence based on facial similarity"))
                        }
                    }
                    .onTapGesture {
                        // Allow editing of new person names (not existing people)
                        if assigned.existingPerson == nil {
                            isEditing = true
                            isNameFocused = true
                        }
                    }
                }
            }

            Spacer()

            if assignment != nil {
                Button {
                    assignment = nil
                    name = ""
                    isEditing = false
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
        .onAppear {
            // Initialize name from existing assignment if any
            if let assigned = assignment {
                name = assigned.name
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
        .listRowBackground(
            isHighlighted ? AppColors.warmYellow.opacity(0.1) : Color.clear
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }

    private func commitName() {
        isEditing = false
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            assignment = FaceAssignment(name: trimmedName, existingPerson: nil)
        } else {
            assignment = nil
        }
    }
}

#Preview {
    OnboardingFirstMemoryView(currentStep: 3, totalSteps: 5, onComplete: {}, onSkip: {})
}
