import SwiftUI
import PhotosUI

/// Match suggestion for ephemeral scan results
struct MatchSuggestion: Identifiable {
    let id = UUID()
    let person: Person
    let similarity: Float
    let confidence: MatchConfidence

    /// Non-assertive confidence text per privacy guidelines
    var confidenceText: String {
        switch confidence {
        case .high:
            return "Likely"
        case .ambiguous:
            return "Possibly"
        case .none:
            return "Maybe"
        }
    }

    /// Confidence color for UI
    var confidenceColor: Color {
        switch confidence {
        case .high:
            return .green
        case .ambiguous:
            return AppColors.warning
        case .none:
            return .gray
        }
    }

    /// Similarity as percentage string
    var similarityText: String {
        "\(Int(similarity * 100))% match"
    }
}

/// State machine for memory scan workflow
enum ScanState: Equatable {
    case idle
    case scanning
    case processing
    case results([MatchSuggestion])
    case noFaceDetected
    case error(String)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning), (.processing, .processing), (.noFaceDetected, .noFaceDetected):
            return true
        case (.results(let a), .results(let b)):
            return a.map { $0.id } == b.map { $0.id }
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// View model for ephemeral face scanning features
/// Handles both Live Memory Scan and Ephemeral Image Match
///
/// Privacy Invariants:
/// - All image processing is ephemeral (in-memory only)
/// - No embeddings are persisted
/// - No images are saved to disk
/// - Photo picker selection is cleared after use
@Observable
final class MemoryScanViewModel {

    // MARK: - Published State

    var scanState: ScanState = .idle
    var scanProgress: Double = 0

    /// Photo picker selection (for Ephemeral Image Match)
    var selectedPhotoItem: PhotosPickerItem?

    /// Last processed image (kept only for display during results)
    var lastProcessedFaceCrop: UIImage?

    // MARK: - Private Properties

    private let faceDetectionService = FaceDetectionService()
    private let faceEmbeddingService = FaceEmbeddingService()
    private let faceMatchingService = FaceMatchingService()

    /// Maximum number of match suggestions to return
    private let maxSuggestions = 3

    /// Minimum threshold for showing matches (lower than normal to be inclusive)
    private let suggestionThreshold: Float = 0.65

    // MARK: - Public Methods

    /// Process an image ephemerally for face matching
    /// No data is persisted - embeddings are discarded after matching
    ///
    /// - Parameters:
    ///   - image: The image to process (will be processed in memory only)
    ///   - people: People with embeddings to match against
    @MainActor
    func processImageEphemerally(_ image: UIImage, people: [Person]) async {
        scanState = .processing

        do {
            // Step 1: Detect faces in image
            let detectedFaces = try await faceDetectionService.detectFaces(in: image)

            guard let firstFace = detectedFaces.first else {
                scanState = .noFaceDetected
                return
            }

            // Keep face crop for display (ephemeral - will be discarded when view dismisses)
            lastProcessedFaceCrop = firstFace.cropImage

            // Step 2: Generate embedding (ephemeral - not persisted)
            let embedding = try await faceEmbeddingService.generateEmbedding(for: firstFace.cropImage)

            // Step 3: Find matches
            let peopleWithEmbeddings = people.filter { !$0.embeddings.isEmpty }

            guard !peopleWithEmbeddings.isEmpty else {
                scanState = .results([])
                return
            }

            let matches = faceMatchingService.findMatches(
                for: embedding,
                in: peopleWithEmbeddings,
                topK: maxSuggestions,
                threshold: suggestionThreshold
            )

            // Convert to suggestions
            let suggestions = matches.map { match in
                MatchSuggestion(
                    person: match.person,
                    similarity: match.similarity,
                    confidence: match.confidence
                )
            }

            scanState = .results(suggestions)

            // Privacy invariant: embedding is now out of scope and will be deallocated

        } catch {
            scanState = .error(error.localizedDescription)
        }
    }

    /// Load and process image from PhotosPickerItem (for Ephemeral Image Match)
    @MainActor
    func processSelectedPhoto(people: [Person]) async {
        guard let item = selectedPhotoItem else { return }

        scanState = .processing

        do {
            // Load image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanState = .error("Could not load selected image")
                // Privacy invariant: clear selection
                selectedPhotoItem = nil
                return
            }

            // Privacy invariant: clear selection immediately after loading
            selectedPhotoItem = nil

            // Process the image
            await processImageEphemerally(image, people: people)

        } catch {
            scanState = .error("Failed to load image: \(error.localizedDescription)")
            // Privacy invariant: clear selection
            selectedPhotoItem = nil
        }
    }

    /// Reset state for a new scan
    @MainActor
    func reset() {
        scanState = .idle
        scanProgress = 0
        selectedPhotoItem = nil
        lastProcessedFaceCrop = nil
    }

    /// Update scan progress (called from camera manager)
    @MainActor
    func updateProgress(_ progress: Double) {
        scanProgress = progress
    }

    /// Set state to scanning (called when camera scan starts)
    @MainActor
    func startScanning() {
        scanState = .scanning
        scanProgress = 0
    }
}
