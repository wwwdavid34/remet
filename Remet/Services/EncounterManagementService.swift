import Foundation
import SwiftData

/// Handles merge and move operations for encounters and photos.
/// Keeps data integrity logic out of views.
struct EncounterManagementService {

    let modelContext: ModelContext

    // MARK: - Merge Encounters

    /// Merge multiple encounters into a primary one.
    /// Photos, people, tags, and embeddings are transferred; secondaries are deleted.
    func mergeEncounters(
        primary: Encounter,
        secondaries: [Encounter],
        combineNotes: Bool
    ) {
        for secondary in secondaries {
            // Combine notes
            if combineNotes {
                appendNotes(from: secondary, to: primary)
            }

            // Move all photos (must happen before deleting secondary)
            for photo in secondary.photos ?? [] {
                photo.encounter = primary
            }

            // Merge people (add any not already linked)
            let existingPersonIds = Set((primary.people ?? []).map { $0.id })
            for person in secondary.people ?? [] where !existingPersonIds.contains(person.id) {
                primary.people = (primary.people ?? []) + [person]
            }

            // Merge tags
            let existingTagIds = Set((primary.tags ?? []).map { $0.id })
            for tag in secondary.tags ?? [] where !existingTagIds.contains(tag.id) {
                primary.tags = (primary.tags ?? []) + [tag]
            }

            // Update FaceEmbedding.encounterId from secondary → primary
            updateEmbeddingEncounterIds(from: secondary.id, to: primary.id)

            // Delete the now-empty secondary encounter
            modelContext.delete(secondary)
        }

        // Regenerate thumbnail from earliest photo
        updateEncounterThumbnail(primary)
    }

    // MARK: - Move Photos

    /// Move selected photos from one encounter to another.
    /// Returns true if the source encounter was deleted (no photos left).
    @discardableResult
    func movePhotos(
        photoIds: Set<UUID>,
        from source: Encounter,
        to destination: Encounter
    ) -> Bool {
        let photosToMove = (source.photos ?? []).filter { photoIds.contains($0.id) }

        // Skip duplicates (same assetIdentifier already in destination)
        let destAssetIds = Set((destination.photos ?? []).compactMap { $0.assetIdentifier })

        for photo in photosToMove {
            if let assetId = photo.assetIdentifier, destAssetIds.contains(assetId) {
                continue // skip duplicate
            }

            // Update embedding encounterId for this photo's bounding boxes
            for box in photo.faceBoundingBoxes {
                updateEmbeddingIds(boundingBoxId: box.id, from: source.id, to: destination.id)
            }

            photo.encounter = destination
        }

        // Reconcile people on both encounters
        updateEncounterPeople(source)
        updateEncounterPeople(destination)

        // Regenerate thumbnails
        updateEncounterThumbnail(source)
        updateEncounterThumbnail(destination)

        // If source has no photos left, delete it
        if (source.photos ?? []).isEmpty && source.imageData == nil {
            modelContext.delete(source)
            return true
        }

        return false
    }

    /// Move selected photos to a new encounter.
    /// Returns the newly created encounter, or nil if source was deleted as a result.
    @discardableResult
    func movePhotosToNewEncounter(
        photoIds: Set<UUID>,
        from source: Encounter
    ) -> (newEncounter: Encounter, sourceDeleted: Bool) {
        // Determine date/location from earliest selected photo
        let selectedPhotos = (source.photos ?? [])
            .filter { photoIds.contains($0.id) }
            .sorted { $0.date < $1.date }

        let earliest = selectedPhotos.first

        let newEncounter = Encounter(
            latitude: earliest?.latitude,
            longitude: earliest?.longitude,
            date: earliest?.date ?? Date()
        )
        modelContext.insert(newEncounter)

        let sourceDeleted = movePhotos(photoIds: photoIds, from: source, to: newEncounter)

        return (newEncounter, sourceDeleted)
    }

    // MARK: - Helpers

    /// Rebuild encounter.people from face bounding box personIds across all photos.
    func updateEncounterPeople(_ encounter: Encounter) {
        var personIds = Set<UUID>()

        // Collect personIds from all photos
        for photo in encounter.photos ?? [] {
            for box in photo.faceBoundingBoxes {
                if let pid = box.personId {
                    personIds.insert(pid)
                }
            }
        }

        // Also check legacy bounding boxes
        for box in encounter.faceBoundingBoxes {
            if let pid = box.personId {
                personIds.insert(pid)
            }
        }

        // Remove people no longer referenced
        encounter.people = (encounter.people ?? []).filter { personIds.contains($0.id) }

        // Add people that are referenced but not yet linked
        let existingIds = Set((encounter.people ?? []).map { $0.id })
        let missingIds = personIds.subtracting(existingIds)

        if !missingIds.isEmpty {
            let descriptor = FetchDescriptor<Person>(
                predicate: #Predicate { person in
                    missingIds.contains(person.id)
                }
            )
            if let people = try? modelContext.fetch(descriptor) {
                for person in people {
                    encounter.people = (encounter.people ?? []) + [person]
                }
            }
        }
    }

    /// Set encounter thumbnail from the earliest photo by date.
    func updateEncounterThumbnail(_ encounter: Encounter) {
        let sorted = (encounter.photos ?? []).sorted { $0.date < $1.date }
        encounter.thumbnailData = sorted.first?.imageData ?? encounter.imageData
    }

    /// Update FaceEmbedding records: change encounterId from old to new
    /// for all embeddings matching the old encounterId.
    private func updateEmbeddingEncounterIds(from oldId: UUID, to newId: UUID) {
        let descriptor = FetchDescriptor<FaceEmbedding>(
            predicate: #Predicate { embedding in
                embedding.encounterId == oldId
            }
        )
        guard let embeddings = try? modelContext.fetch(descriptor) else { return }
        for embedding in embeddings {
            embedding.encounterId = newId
        }
    }

    /// Update FaceEmbedding records for a specific bounding box,
    /// changing encounterId from old to new.
    private func updateEmbeddingIds(boundingBoxId: UUID, from oldId: UUID, to newId: UUID) {
        let descriptor = FetchDescriptor<FaceEmbedding>(
            predicate: #Predicate { embedding in
                embedding.boundingBoxId == boundingBoxId && embedding.encounterId == oldId
            }
        )
        guard let embeddings = try? modelContext.fetch(descriptor) else { return }
        for embedding in embeddings {
            embedding.encounterId = newId
        }
    }

    /// Append notes from source encounter to destination, handling nil/empty gracefully.
    private func appendNotes(from source: Encounter, to destination: Encounter) {
        guard let sourceNotes = source.notes, !sourceNotes.isEmpty else { return }

        if let existingNotes = destination.notes, !existingNotes.isEmpty {
            destination.notes = existingNotes + "\n\n" + sourceNotes
        } else {
            destination.notes = sourceNotes
        }
    }

    // MARK: - Merge People

    /// Merge multiple people into a primary one.
    /// Embeddings, encounters, tags, notes, and related data are transferred; secondaries are deleted.
    func mergePeople(
        primary: Person,
        secondaries: [Person],
        combineNotes: Bool
    ) {
        for secondary in secondaries {
            // Preserve "Me" flag: if a secondary is "Me", transfer to primary
            if secondary.isMe {
                secondary.isMe = false
                primary.isMe = true
            }

            // Combine notes
            if combineNotes {
                appendPersonNotes(from: secondary, to: primary)
            }

            // Move all face embeddings to primary
            for embedding in secondary.embeddings ?? [] {
                embedding.person = primary
            }

            // Merge encounters (add any not already linked)
            let existingEncounterIds = Set((primary.encounters ?? []).map { $0.id })
            for encounter in secondary.encounters ?? [] where !existingEncounterIds.contains(encounter.id) {
                primary.encounters = (primary.encounters ?? []) + [encounter]
            }

            // Merge tags
            let existingTagIds = Set((primary.tags ?? []).map { $0.id })
            for tag in secondary.tags ?? [] where !existingTagIds.contains(tag.id) {
                primary.tags = (primary.tags ?? []) + [tag]
            }

            // Move interaction notes
            for note in secondary.interactionNotes ?? [] {
                note.person = primary
            }

            // Move quiz attempts
            for attempt in secondary.quizAttempts ?? [] {
                attempt.person = primary
            }

            // Discard secondary's spaced repetition data (keep primary's)
            if let srData = secondary.spacedRepetitionData {
                modelContext.delete(srData)
            }

            // Fill empty optional fields from secondary
            if primary.relationship == nil { primary.relationship = secondary.relationship }
            if primary.contextTag == nil { primary.contextTag = secondary.contextTag }
            if primary.company == nil { primary.company = secondary.company }
            if primary.jobTitle == nil { primary.jobTitle = secondary.jobTitle }
            if primary.email == nil { primary.email = secondary.email }
            if primary.phone == nil { primary.phone = secondary.phone }
            if primary.birthday == nil { primary.birthday = secondary.birthday }
            if primary.linkedIn == nil { primary.linkedIn = secondary.linkedIn }
            if primary.twitter == nil { primary.twitter = secondary.twitter }
            if primary.facebookURL == nil { primary.facebookURL = secondary.facebookURL }
            if primary.howWeMet == nil { primary.howWeMet = secondary.howWeMet }
            if primary.contactIdentifier == nil { primary.contactIdentifier = secondary.contactIdentifier }

            // Union interests and talking points (deduplicate)
            let mergedInterests = Array(Set(primary.interests + secondary.interests))
            if mergedInterests.count > primary.interests.count {
                primary.interests = mergedInterests
            }

            let mergedTalkingPoints = Array(Set(primary.talkingPoints + secondary.talkingPoints))
            if mergedTalkingPoints.count > primary.talkingPoints.count {
                primary.talkingPoints = mergedTalkingPoints
            }

            // Update face bounding box personId references in all encounters
            updateBoundingBoxPersonIds(from: secondary.id, to: primary.id)

            // Delete the now-empty secondary person
            modelContext.delete(secondary)
        }
    }

    /// Update personId in face bounding boxes across all encounters and photos.
    private func updateBoundingBoxPersonIds(from oldId: UUID, to newId: UUID) {
        let descriptor = FetchDescriptor<Encounter>()
        guard let allEncounters = try? modelContext.fetch(descriptor) else { return }

        for encounter in allEncounters {
            // Update legacy bounding boxes on encounter
            var legacyBoxes = encounter.faceBoundingBoxes
            var legacyChanged = false
            for i in legacyBoxes.indices where legacyBoxes[i].personId == oldId {
                legacyBoxes[i].personId = newId
                legacyChanged = true
            }
            if legacyChanged {
                encounter.faceBoundingBoxes = legacyBoxes
            }

            // Update bounding boxes on photos
            for photo in encounter.photos ?? [] {
                var boxes = photo.faceBoundingBoxes
                var changed = false
                for i in boxes.indices where boxes[i].personId == oldId {
                    boxes[i].personId = newId
                    changed = true
                }
                if changed {
                    photo.faceBoundingBoxes = boxes
                }
            }
        }
    }

    /// Append notes from source person to destination, handling nil/empty gracefully.
    private func appendPersonNotes(from source: Person, to destination: Person) {
        guard let sourceNotes = source.notes, !sourceNotes.isEmpty else { return }

        if let existingNotes = destination.notes, !existingNotes.isEmpty {
            destination.notes = existingNotes + "\n\n" + sourceNotes
        } else {
            destination.notes = sourceNotes
        }
    }
}
