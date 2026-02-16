import UIKit
import CoreML

final class FaceEmbeddingService {

    static let shared = FaceEmbeddingService()

    private var model: MLModel?

    private init() {}

    /// Pre-load the CoreML model on a background thread.
    /// Call once at app startup so the model is ready when needed.
    func preload() {
        guard model == nil else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine

                guard let modelURL = Bundle.main.url(forResource: "FaceNet512", withExtension: "mlmodelc") else {
                    print("FaceNet512 model not found in bundle")
                    return
                }

                let loaded = try MLModel(contentsOf: modelURL, configuration: config)
                DispatchQueue.main.async {
                    self?.model = loaded
                }
            } catch {
                print("Failed to load FaceNet512 model: \(error)")
            }
        }
    }

    func generateEmbedding(for faceImage: UIImage) async throws -> [Float] {
        // If model hasn't been pre-loaded yet, load synchronously as fallback
        if model == nil {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            if let modelURL = Bundle.main.url(forResource: "FaceNet512", withExtension: "mlmodelc") {
                model = try MLModel(contentsOf: modelURL, configuration: config)
            }
        }

        guard let model = model else {
            throw EmbeddingError.modelNotLoaded
        }

        guard let inputArray = imageToMLMultiArray(faceImage) else {
            throw EmbeddingError.preprocessingFailed
        }

        let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
            "keras_tensor": MLFeatureValue(multiArray: inputArray)
        ])

        let output = try await model.prediction(from: inputFeature)

        guard let outputArray = output.featureValue(for: "Identity")?.multiArrayValue else {
            throw EmbeddingError.invalidOutput
        }

        return multiArrayToFloatArray(outputArray)
    }

    private func imageToMLMultiArray(_ image: UIImage) -> MLMultiArray? {
        let targetSize = CGSize(width: 160, height: 160)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = resizedImage?.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let multiArray = try? MLMultiArray(shape: [1, 160, 160, 3], dataType: .float32) else {
            return nil
        }

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                let r = Float(pixelData[pixelIndex]) / 255.0
                let g = Float(pixelData[pixelIndex + 1]) / 255.0
                let b = Float(pixelData[pixelIndex + 2]) / 255.0

                let rIndex = [0, y, x, 0] as [NSNumber]
                let gIndex = [0, y, x, 1] as [NSNumber]
                let bIndex = [0, y, x, 2] as [NSNumber]

                multiArray[rIndex] = NSNumber(value: r)
                multiArray[gIndex] = NSNumber(value: g)
                multiArray[bIndex] = NSNumber(value: b)
            }
        }

        return multiArray
    }

    private func multiArrayToFloatArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var result = [Float](repeating: 0, count: count)

        for i in 0..<count {
            result[i] = multiArray[i].floatValue
        }

        return normalizeL2(result)
    }

    private func normalizeL2(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

enum EmbeddingError: Error, LocalizedError {
    case modelNotLoaded
    case preprocessingFailed
    case inferenceError(Error)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "FaceNet model is not loaded"
        case .preprocessingFailed:
            return "Failed to preprocess image"
        case .inferenceError(let error):
            return "Embedding generation failed: \(error.localizedDescription)"
        case .invalidOutput:
            return "Invalid model output"
        }
    }
}
