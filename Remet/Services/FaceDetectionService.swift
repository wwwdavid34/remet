import UIKit
import Vision
import CoreImage

struct DetectedFace {
    let boundingBox: CGRect
    let cropImage: UIImage
    let normalizedBoundingBox: CGRect
}

struct FaceDetectionOptions {
    var enhanceImage: Bool = false
    var adjustBrightness: Bool = false
    var increaseContrast: Bool = false

    static let standard = FaceDetectionOptions()
    static let enhanced = FaceDetectionOptions(enhanceImage: true, adjustBrightness: true, increaseContrast: true)
}

final class FaceDetectionService {

    private let ciContext = CIContext()

    func detectFaces(in image: UIImage, options: FaceDetectionOptions = .standard) async throws -> [DetectedFace] {
        // Apply image enhancements if requested
        let processedImage: UIImage
        if options.enhanceImage {
            processedImage = enhanceImage(image, options: options)
        } else {
            processedImage = image
        }

        return try await performDetection(in: processedImage)
    }

    private func performDetection(in image: UIImage) async throws -> [DetectedFace] {
        // Normalize image orientation first - this ensures cgImage matches visual orientation
        let normalizedImage = normalizeOrientation(image)

        guard let cgImage = normalizedImage.cgImage else {
            throw FaceDetectionError.invalidImage
        }

        let request = VNDetectFaceRectanglesRequest()
        // Use .up orientation since image is already normalized
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        return results.compactMap { observation in
            let normalizedBox = observation.boundingBox
            let imageRect = convertToImageCoordinates(normalizedBox: normalizedBox, imageSize: imageSize)

            guard let croppedCGImage = cgImage.cropping(to: imageRect) else {
                return nil
            }

            let cropImage = UIImage(cgImage: croppedCGImage)

            return DetectedFace(
                boundingBox: imageRect,
                cropImage: cropImage,
                normalizedBoundingBox: normalizedBox
            )
        }
    }

    /// Enhance image for better face detection
    private func enhanceImage(_ image: UIImage, options: FaceDetectionOptions) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var outputImage = ciImage

        // Apply contrast enhancement
        if options.increaseContrast {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(1.1, forKey: kCIInputContrastKey) // Slight contrast boost
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Apply brightness adjustment
        if options.adjustBrightness {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.05, forKey: kCIInputBrightnessKey) // Slight brightness boost
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Apply sharpening for better edge detection
        if options.enhanceImage {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.4, forKey: kCIInputSharpnessKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Render the enhanced image
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Normalize image to .up orientation by redrawing if needed
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }

    private func convertToImageCoordinates(normalizedBox: CGRect, imageSize: CGSize) -> CGRect {
        // Add padding for better recognition (FaceNet works better with some context)
        let padding: CGFloat = 0.3
        let paddedBox = normalizedBox.insetBy(
            dx: -normalizedBox.width * padding,
            dy: -normalizedBox.height * padding
        )

        // Convert normalized bounding box to pixel coordinates
        // Vision uses bottom-left origin, CGImage uses top-left
        let cropRect = CGRect(
            x: paddedBox.origin.x * imageSize.width,
            y: (1 - paddedBox.origin.y - paddedBox.height) * imageSize.height,
            width: paddedBox.width * imageSize.width,
            height: paddedBox.height * imageSize.height
        )

        // Ensure rect is within image bounds
        return cropRect.intersection(
            CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
        )
    }

}

enum FaceDetectionError: Error, LocalizedError {
    case invalidImage
    case detectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .detectionFailed(let error):
            return "Face detection failed: \(error.localizedDescription)"
        }
    }
}
