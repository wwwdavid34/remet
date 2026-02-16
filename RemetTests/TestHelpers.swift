import XCTest
import SwiftData
@testable import Remet

/// Shared test helpers for creating in-memory SwiftData containers and synthetic test data
enum TestHelpers {

    /// Create an in-memory ModelContainer with all Remet model types
    @MainActor
    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Person.self,
            FaceEmbedding.self,
            ImportedPhoto.self,
            Encounter.self,
            EncounterPhoto.self,
            Tag.self,
            InteractionNote.self,
            SpacedRepetitionData.self,
            QuizAttempt.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Synthetic Embedding Vectors

    /// Create a normalized 512-dimensional vector with a known direction.
    /// Use different `seed` values to get vectors with predictable similarity.
    static func makeEmbeddingVector(seed: Int, dimensions: Int = 512) -> [Float] {
        var vector = [Float](repeating: 0, count: dimensions)
        // Place energy in a few dimensions based on seed
        for i in 0..<dimensions {
            vector[i] = sin(Float(i + seed) * 0.1) * cos(Float(seed) * 0.3)
        }
        // L2 normalize
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    /// Create two vectors with a specific approximate cosine similarity.
    /// `similarity` should be between 0 and 1.
    static func makeVectorPair(similarity: Float, dimensions: Int = 512) -> (a: [Float], b: [Float]) {
        // Start with a base vector
        let base = makeEmbeddingVector(seed: 42, dimensions: dimensions)

        // Create a perpendicular-ish noise vector
        let noise = makeEmbeddingVector(seed: 999, dimensions: dimensions)

        // Mix: b = similarity * base + (1-similarity) * noise, then normalize
        let mixFactor = similarity
        var b = [Float](repeating: 0, count: dimensions)
        for i in 0..<dimensions {
            b[i] = mixFactor * base[i] + (1 - mixFactor) * noise[i]
        }
        // Normalize b
        let norm = sqrt(b.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            b = b.map { $0 / norm }
        }

        return (base, b)
    }

    /// Convert a [Float] vector to Data (matching FaceEmbedding.vector storage format)
    static func vectorToData(_ vector: [Float]) -> Data {
        vector.withUnsafeBytes { Data($0) }
    }

    // MARK: - Person Factory

    /// Create a Person with a synthetic face embedding in the given context
    @MainActor
    static func makePerson(
        name: String,
        relationship: String? = nil,
        contextTag: String? = nil,
        company: String? = nil,
        isFavorite: Bool = false,
        embeddingSeed: Int? = nil,
        in context: ModelContext
    ) -> Person {
        let person = Person(
            name: name,
            relationship: relationship,
            contextTag: contextTag,
            company: company
        )
        person.isFavorite = isFavorite
        context.insert(person)

        if let seed = embeddingSeed {
            let vector = makeEmbeddingVector(seed: seed)
            let embedding = FaceEmbedding(
                vector: vectorToData(vector),
                faceCropData: Data() // Empty for tests — no actual image needed
            )
            embedding.person = person
            person.embeddings = [embedding]
            context.insert(embedding)
        }

        return person
    }

    /// Create a Tag in the given context
    @MainActor
    static func makeTag(name: String, in context: ModelContext) -> Tag {
        let tag = Tag(name: name)
        context.insert(tag)
        return tag
    }
}
