import SwiftUI
import PhotosUI
import SwiftData

@Observable
final class PhotoImportViewModel {
    var selectedItem: PhotosPickerItem?
    var importedImage: UIImage?
    var detectedFaces: [DetectedFace] = []
    var isProcessing = false
    var errorMessage: String?
    var showFaceReview = false

    private let faceDetectionService = FaceDetectionService()

    func processSelectedPhoto() async {
        guard let item = selectedItem else { return }

        isProcessing = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not load image"
                isProcessing = false
                return
            }

            importedImage = image
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

    func reset() {
        selectedItem = nil
        importedImage = nil
        detectedFaces = []
        errorMessage = nil
        showFaceReview = false
    }
}
