import Foundation
import SwiftData

enum MatchConfidence {
    case high
    case ambiguous
    case none
}

struct MatchResult {
    let person: Person
    let similarity: Float
    let confidence: MatchConfidence
}

final class FaceMatchingService {

    private let highConfidenceThreshold: Float = 0.85
    private let ambiguousThreshold: Float = 0.75

    /// Boost applied to similarity scores for persons already in the encounter
    /// This helps ensure consistent labeling when a person appears multiple times
    private let encounterBoost: Float = 0.05

    func findMatches(
        for embedding: [Float],
        in people: [Person],
        topK: Int = 1,
        threshold: Float? = nil,
        boostPersonIds: Set<UUID> = []
    ) -> [MatchResult] {
        let minThreshold = threshold ?? ambiguousThreshold
        var results: [(person: Person, similarity: Float, boosted: Bool)] = []

        for person in people {
            let bestSimilarity = (person.embeddings ?? [])
                .map { cosineSimilarity(embedding, $0.embeddingVector) }
                .max() ?? 0

            // Apply boost for persons already in the encounter
            let shouldBoost = boostPersonIds.contains(person.id)
            let adjustedSimilarity = shouldBoost ? min(bestSimilarity + encounterBoost, 1.0) : bestSimilarity

            if adjustedSimilarity > minThreshold {
                results.append((person, adjustedSimilarity, shouldBoost))
            }
        }

        results.sort { $0.similarity > $1.similarity }

        return results.prefix(topK).map { result in
            MatchResult(
                person: result.person,
                similarity: result.similarity,
                confidence: confidenceLevel(for: result.similarity)
            )
        }
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    private func confidenceLevel(for similarity: Float) -> MatchConfidence {
        if similarity >= highConfidenceThreshold {
            return .high
        } else if similarity >= ambiguousThreshold {
            return .ambiguous
        } else {
            return .none
        }
    }
}
