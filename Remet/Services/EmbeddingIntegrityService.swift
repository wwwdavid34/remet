import Foundation
import SwiftData

/// Detects and removes orphaned face embeddings from the pre-v1.1.0 re-labeling bug.
///
/// Before v1.1.0, re-assigning a face bounding box to a different person created a new
/// embedding for the new person but did not delete the old embedding from the previous person.
/// This left "orphaned" embeddings — wrong face data permanently linked to the wrong person.
///
/// Detection: For each embedding with a `boundingBoxId`, cross-reference against the bounding
/// box's current `personId` in encounters/photos. If they disagree, the embedding is orphaned.
enum EmbeddingIntegrityService {

    struct CleanupResult {
        let orphansRemoved: Int
        let peopleAffected: Int
    }

    /// Scan people's embeddings and remove any orphaned by the pre-v1.1.0 re-labeling bug.
    ///
    /// Call at quiz start to ensure only correctly-assigned faces are sampled.
    /// Returns the cleaned list of people (those who still have embeddings after cleanup).
    @MainActor
    static func cleanAndFilter(
        people: [Person],
        using modelContext: ModelContext
    ) -> (people: [Person], result: CleanupResult) {
        let boxOwnership = buildBoundingBoxOwnership(using: modelContext)

        var totalOrphans = 0
        var affectedPeople = 0

        for person in people {
            let orphans = findOrphanedEmbeddings(for: person, boxOwnership: boxOwnership)
            if !orphans.isEmpty {
                affectedPeople += 1
                totalOrphans += orphans.count
                for embedding in orphans {
                    modelContext.delete(embedding)
                }
            }
        }

        if totalOrphans > 0 {
            try? modelContext.save()
        }

        let result = CleanupResult(orphansRemoved: totalOrphans, peopleAffected: affectedPeople)
        let cleaned = people.filter { !($0.embeddings ?? []).isEmpty }
        return (cleaned, result)
    }

    // MARK: - Internal

    /// Build a lookup of boundingBoxId → current owner personId.
    /// Uses two collections to distinguish "box exists with no owner" from "box not found".
    @MainActor
    private static func buildBoundingBoxOwnership(
        using modelContext: ModelContext
    ) -> BoundingBoxOwnership {
        let descriptor = FetchDescriptor<Encounter>()
        guard let encounters = try? modelContext.fetch(descriptor) else {
            return BoundingBoxOwnership()
        }

        var ownership = BoundingBoxOwnership()

        for encounter in encounters {
            // Legacy single-photo bounding boxes
            for box in encounter.faceBoundingBoxes {
                ownership.register(boxId: box.id, personId: box.personId)
            }
            // Multi-photo bounding boxes
            for photo in encounter.photos ?? [] {
                for box in photo.faceBoundingBoxes {
                    ownership.register(boxId: box.id, personId: box.personId)
                }
            }
        }

        return ownership
    }

    /// Find embeddings on a person that are orphaned (bounding box now belongs to someone else).
    private static func findOrphanedEmbeddings(
        for person: Person,
        boxOwnership: BoundingBoxOwnership
    ) -> [FaceEmbedding] {
        guard let embeddings = person.embeddings else { return [] }

        return embeddings.filter { embedding in
            guard let boxId = embedding.boundingBoxId else {
                // No boundingBoxId — pre-tracking embedding, can't verify
                return false
            }

            switch boxOwnership.owner(of: boxId) {
            case .ownedBy(let ownerId):
                // Box belongs to a different person → orphaned
                return ownerId != person.id
            case .unowned:
                // Box exists but personId is nil (label was cleared) → orphaned
                return true
            case .notFound:
                // Box not in any encounter (encounter deleted?) → keep embedding
                return false
            }
        }
    }
}

// MARK: - Bounding Box Ownership Lookup

extension EmbeddingIntegrityService {

    struct BoundingBoxOwnership {
        private var boxToPersonId: [UUID: UUID] = [:]
        private var allKnownBoxIds: Set<UUID> = []

        mutating func register(boxId: UUID, personId: UUID?) {
            allKnownBoxIds.insert(boxId)
            if let personId {
                boxToPersonId[boxId] = personId
            }
        }

        enum OwnershipStatus {
            case ownedBy(UUID)
            case unowned      // box exists but no personId
            case notFound      // box not in any encounter
        }

        func owner(of boxId: UUID) -> OwnershipStatus {
            if let personId = boxToPersonId[boxId] {
                return .ownedBy(personId)
            } else if allKnownBoxIds.contains(boxId) {
                return .unowned
            } else {
                return .notFound
            }
        }
    }
}
