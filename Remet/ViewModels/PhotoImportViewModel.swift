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

    // Multi-photo state
    var pendingImages: [(image: UIImage, assetId: String?)] = []
    var showGroupReview = false
    var scannedPhotos: [ScannedPhoto] = []
    var photoGroup: PhotoGroup?

    private let faceDetectionService = FaceDetectionService()

    func processPickedPhotos(images: [(image: UIImage, assetId: String?)], modelContext: ModelContext) async {
        isProcessing = true
        errorMessage = nil

        var photos: [ScannedPhoto] = []

        for (image, assetId) in images {
            // Skip already-imported photos
            if let id = assetId, isAssetAlreadyImported(id, modelContext: modelContext) {
                continue
            }

            // Extract metadata from PHAsset if available
            var date = Date()
            var location: CLLocation?
            if let id = assetId {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = fetchResult.firstObject {
                    date = asset.creationDate ?? Date()
                    location = asset.location
                }
            }

            // Run face detection
            var faces: [DetectedFace] = []
            do {
                faces = try await faceDetectionService.detectFaces(in: image)
            } catch {
                // Include photo with empty faces so user can manually tag
            }
            let scannedPhoto = ScannedPhoto(
                id: assetId ?? UUID().uuidString,
                asset: nil,
                image: image,
                detectedFaces: faces,
                date: date,
                location: location
            )
            photos.append(scannedPhoto)
        }

        if photos.isEmpty {
            errorMessage = "All selected photos have already been imported"
            isProcessing = false
            return
        }

        scannedPhotos = photos

        if photos.count == 1 {
            // Single photo — use existing single-photo review
            importedImage = photos[0].image
            detectedFaces = photos[0].detectedFaces
            assetIdentifier = photos[0].id
            photoDate = photos[0].date
            photoLocation = photos[0].location
            showFaceReview = true
        } else {
            // Multiple photos — use group review
            photoGroup = PhotoGroup(id: UUID(), photos: photos)
            showGroupReview = true
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
        pendingImages = []
        showGroupReview = false
        scannedPhotos = []
        photoGroup = nil
        photoDate = nil
        photoLocation = nil
    }
}
