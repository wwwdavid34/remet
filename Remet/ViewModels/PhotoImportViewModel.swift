import SwiftUI
import PhotosUI
import SwiftData

@Observable
final class PhotoImportViewModel {
    var importedImage: UIImage?
    var detectedFaces: [DetectedFace] = []
    var isProcessing = false
    var errorMessage: String?
    var showFaceReview = false
    var assetIdentifier: String?
    var showAlreadyImportedAlert = false
    var showPhotoPicker = false

    // Pending pick data — stored when photo is picked, processed after picker sheet dismisses
    var pendingImage: UIImage?
    var pendingAssetId: String?

    private let faceDetectionService = FaceDetectionService()

    func processPickedPhoto(image: UIImage, assetIdentifier: String?, modelContext: ModelContext) async {
        isProcessing = true
        errorMessage = nil
        self.assetIdentifier = assetIdentifier

        // Check if this photo was already imported
        if let assetId = assetIdentifier, isAssetAlreadyImported(assetId, modelContext: modelContext) {
            isProcessing = false
            showAlreadyImportedAlert = true
            return
        }

        importedImage = image

        do {
            detectedFaces = try await faceDetectionService.detectFaces(in: image)
            showFaceReview = !detectedFaces.isEmpty

            if detectedFaces.isEmpty {
                errorMessage = "No faces detected in this photo"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func isAssetAlreadyImported(_ assetId: String, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<EncounterPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else { return false }
        return photos.contains { $0.assetIdentifier == assetId }
    }

    func reset() {
        importedImage = nil
        detectedFaces = []
        errorMessage = nil
        showFaceReview = false
        assetIdentifier = nil
        showAlreadyImportedAlert = false
        pendingImage = nil
        pendingAssetId = nil
    }
}
