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

/// Groups match suggestions with the detected face crop
struct FaceMatchResult: Identifiable {
    let id = UUID()
    let faceCrop: UIImage
    let suggestions: [MatchSuggestion]

    /// Whether this face has any matches
    var hasMatches: Bool {
        !suggestions.isEmpty
    }

    /// Best match if available
    var bestMatch: MatchSuggestion? {
        suggestions.first
    }
}

/// State machine for memory scan workflow
enum ScanState: Equatable {
    case idle
    case scanning
    case processing
    case results([FaceMatchResult])
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

    /// Last processed face crops (kept only for display during results)
    /// For single-face scans (like live camera), this contains one image
    var lastProcessedFaceCrops: [UIImage] = []

    /// Convenience for single face (backwards compatibility with live scan)
    var lastProcessedFaceCrop: UIImage? {
        lastProcessedFaceCrops.first
    }

    // MARK: - Private Properties

    private let faceDetectionService = FaceDetectionService()
    private let faceEmbeddingService = FaceEmbeddingService.shared
    private let faceMatchingService = FaceMatchingService()

    /// Maximum number of match suggestions to return
    private let maxSuggestions = 3

    /// Minimum threshold for showing matches (lower to be inclusive for varied conditions)
    private let suggestionThreshold: Float = 0.45

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
        lastProcessedFaceCrops = []

        do {
            // Step 1: Detect all faces in image
            let detectedFaces = try await faceDetectionService.detectFaces(in: image)

            guard !detectedFaces.isEmpty else {
                scanState = .noFaceDetected
                return
            }

            // Store all face crops for display
            lastProcessedFaceCrops = detectedFaces.map { $0.cropImage }

            // Step 2: Get people with embeddings
            let peopleWithEmbeddings = people.filter { !($0.embeddings ?? []).isEmpty }

            guard !peopleWithEmbeddings.isEmpty else {
                // No people to match against - return results with no matches
                let results = detectedFaces.map { face in
                    FaceMatchResult(faceCrop: face.cropImage, suggestions: [])
                }
                scanState = .results(results)
                return
            }

            // Step 3: Process each detected face
            var faceResults: [FaceMatchResult] = []

            for face in detectedFaces {
                // Generate embedding for this face (ephemeral - not persisted)
                let embedding = try await faceEmbeddingService.generateEmbedding(for: face.cropImage)

                // Find matches for this face
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

                faceResults.append(FaceMatchResult(
                    faceCrop: face.cropImage,
                    suggestions: suggestions
                ))
            }

            scanState = .results(faceResults)

            // Privacy invariant: embeddings are now out of scope and will be deallocated

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
        lastProcessedFaceCrops = []
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
