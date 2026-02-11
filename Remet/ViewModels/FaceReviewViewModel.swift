import SwiftUI
import SwiftData

struct FaceForReview: Identifiable {
    let id = UUID()
    let detectedFace: DetectedFace
    var matchResult: MatchResult?
    var assignedPerson: Person?
    var isProcessed = false
    var createdEmbedding: FaceEmbedding?
}

@Observable
final class FaceReviewViewModel {
    var facesForReview: [FaceForReview] = []
    var currentFaceIndex = 0
    var isProcessing = false
    var showNameInput = false
    var newPersonName = ""

    // Encounter creation
    var createdEncounter: Encounter?

    private let embeddingService = FaceEmbeddingService()
    private let matchingService = FaceMatchingService()

    var currentFace: FaceForReview? {
        guard currentFaceIndex < facesForReview.count else { return nil }
        let face = facesForReview[currentFaceIndex]
        // Return nil if already processed (triggers completion view)
        return face.isProcessed ? nil : face
    }

    var hasMoreFaces: Bool {
        // Check if there are any unprocessed faces after current index
        return facesForReview.dropFirst(currentFaceIndex + 1).contains { !$0.isProcessed }
    }

    var allFacesProcessed: Bool {
        facesForReview.allSatisfy { $0.isProcessed }
    }

    /// Index of next unprocessed face, if any
    private var nextUnprocessedIndex: Int? {
        facesForReview.indices.first { index in
            index > currentFaceIndex && !facesForReview[index].isProcessed
        }
    }

    func setupFaces(from detectedFaces: [DetectedFace]) {
        facesForReview = detectedFaces.map { FaceForReview(detectedFace: $0) }
        currentFaceIndex = 0
    }

    func processCurrentFace(people: [Person]) async {
        guard currentFaceIndex < facesForReview.count else { return }

        isProcessing = true

        do {
            let face = facesForReview[currentFaceIndex]
            let embedding = try await embeddingService.generateEmbedding(for: face.detectedFace.cropImage)
            let matches = matchingService.findMatches(for: embedding, in: people)

            if let topMatch = matches.first {
                facesForReview[currentFaceIndex].matchResult = topMatch
            }
        } catch {
            print("Error processing face: \(error)")
        }

        isProcessing = false
    }

    func confirmMatch(modelContext: ModelContext) {
        guard currentFaceIndex < facesForReview.count,
              let match = facesForReview[currentFaceIndex].matchResult else { return }

        addEmbeddingToPerson(match.person, modelContext: modelContext)
        facesForReview[currentFaceIndex].assignedPerson = match.person
        facesForReview[currentFaceIndex].isProcessed = true
        moveToNextFace()
    }

    func rejectMatch() {
        facesForReview[currentFaceIndex].matchResult = nil
    }

    func createNewPerson(modelContext: ModelContext) -> Person? {
        guard !newPersonName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let person = Person(name: newPersonName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(person)

        addEmbeddingToPerson(person, modelContext: modelContext)

        facesForReview[currentFaceIndex].assignedPerson = person
        facesForReview[currentFaceIndex].isProcessed = true

        newPersonName = ""
        showNameInput = false
        moveToNextFace()

        return person
    }

    func assignToExistingPerson(_ person: Person, modelContext: ModelContext) {
        addEmbeddingToPerson(person, modelContext: modelContext)
        facesForReview[currentFaceIndex].assignedPerson = person
        facesForReview[currentFaceIndex].isProcessed = true
        moveToNextFace()
    }

    private func addEmbeddingToPerson(_ person: Person, modelContext: ModelContext) {
        guard currentFaceIndex < facesForReview.count else { return }

        let faceIndex = currentFaceIndex
        let face = facesForReview[faceIndex]

        Task {
            do {
                let embedding = try await embeddingService.generateEmbedding(for: face.detectedFace.cropImage)
                let vectorData = embedding.withUnsafeBytes { Data($0) }
                let imageData = face.detectedFace.cropImage.jpegData(compressionQuality: 0.8) ?? Data()

                await MainActor.run {
                    let faceEmbedding = FaceEmbedding(
                        vector: vectorData,
                        faceCropData: imageData
                    )
                    faceEmbedding.person = person
                    modelContext.insert(faceEmbedding)
                    person.lastSeenAt = Date()

                    // Store the embedding for encounter creation
                    facesForReview[faceIndex].createdEmbedding = faceEmbedding
                }
            } catch {
                print("Error adding embedding: \(error)")
            }
        }
    }

    /// Create an encounter from the imported photo and identified faces
    func createEncounter(from image: UIImage, modelContext: ModelContext) -> Encounter {
        let settings = AppSettings.shared
        let resizedImage = resizeImage(image, targetSize: settings.photoTargetSize)
        let imageData = resizedImage.jpegData(compressionQuality: settings.photoJpegQuality) ?? Data()

        // Build face bounding boxes with person info
        var boundingBoxes: [FaceBoundingBox] = []
        for face in facesForReview {
            let box = FaceBoundingBox(
                rect: face.detectedFace.normalizedBoundingBox,
                personId: face.assignedPerson?.id,
                personName: face.assignedPerson?.name,
                confidence: face.matchResult?.similarity,
                isAutoAccepted: false
            )
            boundingBoxes.append(box)
        }

        // Create encounter
        let encounter = Encounter(
            imageData: imageData,
            occasion: nil,
            notes: nil,
            location: nil,
            date: Date()
        )
        encounter.faceBoundingBoxes = boundingBoxes

        // Link identified people
        let identifiedPeople = facesForReview.compactMap { $0.assignedPerson }
        let uniquePeople = Array(Set(identifiedPeople))
        encounter.people = uniquePeople

        // Update embeddings with encounter ID
        for face in facesForReview {
            if let embedding = face.createdEmbedding {
                embedding.encounterId = encounter.id
            }
        }

        modelContext.insert(encounter)
        try? modelContext.save()
        createdEncounter = encounter

        return encounter
    }

    private func moveToNextFace() {
        if let nextIndex = nextUnprocessedIndex {
            currentFaceIndex = nextIndex
        }
        // If no more unprocessed faces, currentFace will return nil
        // triggering the completion view
    }

    func skipCurrentFace() {
        facesForReview[currentFaceIndex].isProcessed = true
        moveToNextFace()
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
