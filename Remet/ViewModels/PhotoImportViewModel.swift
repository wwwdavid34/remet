import SwiftUI
import PhotosUI
import SwiftData
import CoreLocation

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
    var photoDate: Date?
    var photoLocation: CLLocation?

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

        // Extract date and location from PHAsset metadata
        if let assetId = assetIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = fetchResult.firstObject {
                photoDate = asset.creationDate
                photoLocation = asset.location
            }
        }

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
        photoDate = nil
        photoLocation = nil
    }
}
