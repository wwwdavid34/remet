import XCTest
import SwiftData
@testable import Remet

/// Tests for EncounterManagementService: merge encounters, merge people, move photos.
/// Covers commits: d9b0ea4 (encounter merge), e8817e2 (people merge).
final class EncounterManagementServiceTests: XCTestCase {

    // MARK: - mergeEncounters: Photos

    @MainActor
    func testMergeEncounters_photosTransferred() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makeEncounter(occasion: "Primary", in: ctx)
        let secondary = TestHelpers.makeEncounter(occasion: "Secondary", in: ctx)

        let photo = TestHelpers.makeEncounterPhoto(imageData: Data([0x01]), in: ctx)
        photo.encounter = secondary

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual((primary.photos ?? []).count, 1)
        XCTAssertEqual((primary.photos ?? []).first?.imageData, Data([0x01]))
    }

    // MARK: - mergeEncounters: People Deduplicated

    @MainActor
    func testMergeEncounters_peopleDeduplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let alice = TestHelpers.makePerson(name: "Alice", in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", in: ctx)

        let primary = TestHelpers.makeEncounter(in: ctx)
        primary.people = [alice]

        let secondary = TestHelpers.makeEncounter(in: ctx)
        secondary.people = [alice, bob] // alice is duplicate

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        let people = primary.people ?? []
        XCTAssertEqual(people.count, 2) // alice + bob, not 3
    }

    // MARK: - mergeEncounters: Tags Deduplicated

    @MainActor
    func testMergeEncounters_tagsDeduplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)

        let primary = TestHelpers.makeEncounter(in: ctx)
        primary.tags = [tag1]

        let secondary = TestHelpers.makeEncounter(in: ctx)
        secondary.tags = [tag1, tag2]

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        let tags = primary.tags ?? []
        XCTAssertEqual(tags.count, 2)
    }

    // MARK: - mergeEncounters: Notes

    @MainActor
    func testMergeEncounters_combineNotesTrue_notesCombined() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makeEncounter(notes: "Primary notes", in: ctx)
        let secondary = TestHelpers.makeEncounter(notes: "Secondary notes", in: ctx)

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: true)
        try ctx.save()

        XCTAssertEqual(primary.notes, "Primary notes\n\nSecondary notes")
    }

    @MainActor
    func testMergeEncounters_combineNotesFalse_notesUnchanged() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makeEncounter(notes: "Primary notes", in: ctx)
        let secondary = TestHelpers.makeEncounter(notes: "Secondary notes", in: ctx)

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual(primary.notes, "Primary notes")
    }

    @MainActor
    func testMergeEncounters_sourceNilNotes_destinationUnchanged() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makeEncounter(notes: "Existing", in: ctx)
        let secondary = TestHelpers.makeEncounter(in: ctx) // nil notes

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: true)
        try ctx.save()

        XCTAssertEqual(primary.notes, "Existing")
    }

    @MainActor
    func testMergeEncounters_destinationNilNotes_takesSource() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makeEncounter(in: ctx) // nil notes
        let secondary = TestHelpers.makeEncounter(notes: "Source notes", in: ctx)

        try ctx.save()

        svc.mergeEncounters(primary: primary, secondaries: [secondary], combineNotes: true)
        try ctx.save()

        XCTAssertEqual(primary.notes, "Source notes")
    }

    // MARK: - mergePeople: Embeddings Transferred

    @MainActor
    func testMergePeople_embeddingsTransferred() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let secondary = TestHelpers.makePerson(name: "Alice2", embeddingSeed: 2, in: ctx)

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual((primary.embeddings ?? []).count, 2)
    }

    // MARK: - mergePeople: Encounters Deduplicated

    @MainActor
    func testMergePeople_encountersDeduplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let shared = TestHelpers.makeEncounter(occasion: "Shared", in: ctx)
        let unique = TestHelpers.makeEncounter(occasion: "Unique", in: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", in: ctx)
        primary.encounters = [shared]

        let secondary = TestHelpers.makePerson(name: "Alice2", in: ctx)
        secondary.encounters = [shared, unique]

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual((primary.encounters ?? []).count, 2) // shared + unique
    }

    // MARK: - mergePeople: Tags Deduplicated

    @MainActor
    func testMergePeople_tagsDeduplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", in: ctx)
        primary.tags = [tag1]

        let secondary = TestHelpers.makePerson(name: "Alice2", in: ctx)
        secondary.tags = [tag1, tag2]

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual((primary.tags ?? []).count, 2)
    }

    // MARK: - mergePeople: isMe Flag Transfer

    @MainActor
    func testMergePeople_isMeTransferred() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", in: ctx)
        let secondary = TestHelpers.makePerson(name: "Me", isMe: true, in: ctx)

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertTrue(primary.isMe)
    }

    // MARK: - mergePeople: Empty Fields Filled

    @MainActor
    func testMergePeople_emptyFieldsFilled() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", in: ctx)
        let secondary = TestHelpers.makePerson(
            name: "Alice2", relationship: "Friend", contextTag: "Work", company: "Acme", in: ctx
        )

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual(primary.relationship, "Friend")
        XCTAssertEqual(primary.contextTag, "Work")
        XCTAssertEqual(primary.company, "Acme")
    }

    @MainActor
    func testMergePeople_existingFieldsPreserved() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", relationship: "Family", in: ctx)
        let secondary = TestHelpers.makePerson(name: "Alice2", relationship: "Friend", in: ctx)

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        XCTAssertEqual(primary.relationship, "Family") // NOT overwritten
    }

    // MARK: - mergePeople: Interests Union

    @MainActor
    func testMergePeople_interestsUnioned() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", in: ctx)
        primary.interests = ["Swift", "Music"]

        let secondary = TestHelpers.makePerson(name: "Alice2", in: ctx)
        secondary.interests = ["Music", "Travel"]

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: false)
        try ctx.save()

        let interests = Set(primary.interests)
        XCTAssertTrue(interests.contains("Swift"))
        XCTAssertTrue(interests.contains("Music"))
        XCTAssertTrue(interests.contains("Travel"))
        XCTAssertEqual(interests.count, 3) // deduplicated
    }

    // MARK: - mergePeople: Notes

    @MainActor
    func testMergePeople_notesCombined() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let primary = TestHelpers.makePerson(name: "Alice", notes: "Primary", in: ctx)
        let secondary = TestHelpers.makePerson(name: "Alice2", notes: "Secondary", in: ctx)

        try ctx.save()

        svc.mergePeople(primary: primary, secondaries: [secondary], combineNotes: true)
        try ctx.save()

        XCTAssertEqual(primary.notes, "Primary\n\nSecondary")
    }

    // MARK: - movePhotos

    @MainActor
    func testMovePhotos_photoTransferred() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let source = TestHelpers.makeEncounter(in: ctx)
        let dest = TestHelpers.makeEncounter(in: ctx)
        let photo1 = TestHelpers.makeEncounterPhoto(imageData: Data([0x01]), in: ctx)
        photo1.encounter = source
        let photo2 = TestHelpers.makeEncounterPhoto(imageData: Data([0x02]), in: ctx)
        photo2.encounter = source

        try ctx.save()

        let deleted = svc.movePhotos(photoIds: [photo1.id], from: source, to: dest)

        XCTAssertFalse(deleted) // source still has photo2
        XCTAssertEqual((dest.photos ?? []).count, 1)
    }

    @MainActor
    func testMovePhotos_sourceDeletedWhenEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let source = TestHelpers.makeEncounter(in: ctx)
        let dest = TestHelpers.makeEncounter(in: ctx)
        let photo = TestHelpers.makeEncounterPhoto(in: ctx)
        photo.encounter = source

        try ctx.save()

        let deleted = svc.movePhotos(photoIds: [photo.id], from: source, to: dest)
        XCTAssertTrue(deleted)
    }

    @MainActor
    func testMovePhotos_duplicateAssetSkipped() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let source = TestHelpers.makeEncounter(in: ctx)
        let dest = TestHelpers.makeEncounter(in: ctx)

        let photo1 = TestHelpers.makeEncounterPhoto(assetIdentifier: "ABC", in: ctx)
        photo1.encounter = source

        let existingPhoto = TestHelpers.makeEncounterPhoto(assetIdentifier: "ABC", in: ctx)
        existingPhoto.encounter = dest

        try ctx.save()

        _ = svc.movePhotos(photoIds: [photo1.id], from: source, to: dest)
        try ctx.save()

        // Destination should still have only 1 photo (duplicate skipped)
        XCTAssertEqual((dest.photos ?? []).count, 1)
    }

    // MARK: - updateEncounterThumbnail

    @MainActor
    func testUpdateThumbnail_usesEarliestPhoto() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let svc = EncounterManagementService(modelContext: ctx)

        let encounter = TestHelpers.makeEncounter(in: ctx)
        let olderPhoto = TestHelpers.makeEncounterPhoto(
            imageData: Data([0xAA]),
            date: Date().addingTimeInterval(-3600),
            in: ctx
        )
        olderPhoto.encounter = encounter
        let newerPhoto = TestHelpers.makeEncounterPhoto(
            imageData: Data([0xBB]),
            date: Date(),
            in: ctx
        )
        newerPhoto.encounter = encounter

        try ctx.save()

        svc.updateEncounterThumbnail(encounter)
        try ctx.save()

        XCTAssertEqual(encounter.thumbnailData, Data([0xAA])) // oldest photo's data
    }
}
