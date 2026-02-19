import XCTest
import SwiftData
@testable import Remet

/// Tests for Person model computed properties added after v1.0.
/// Covers commits: f242158 (favorites/isMe), e13575b (profile embedding),
/// 97a5513 (exclude Me from practice).
final class PersonModelExtrasTests: XCTestCase {

    // MARK: - Default Values

    @MainActor
    func testIsFavorite_defaultsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertFalse(person.isFavorite)
    }

    @MainActor
    func testIsMe_defaultsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertFalse(person.isMe)
    }

    // MARK: - encounterCount

    @MainActor
    func testEncounterCount_noEncounters_returnsZero() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertEqual(person.encounterCount, 0)
    }

    @MainActor
    func testEncounterCount_threeEncounters_returnsThree() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)

        for i in 0..<3 {
            let encounter = TestHelpers.makeEncounter(occasion: "E\(i)", in: ctx)
            encounter.people = [person]
        }
        try ctx.save()
        XCTAssertEqual(person.encounterCount, 3)
    }

    // MARK: - interests JSON round-trip

    @MainActor
    func testInterests_nilData_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertTrue(person.interests.isEmpty)
    }

    @MainActor
    func testInterests_roundTrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        person.interests = ["Swift", "Music"]
        try ctx.save()
        XCTAssertEqual(person.interests, ["Swift", "Music"])
    }

    @MainActor
    func testInterests_invalidData_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        person.interestsData = Data("not json".utf8)
        try ctx.save()
        XCTAssertTrue(person.interests.isEmpty)
    }

    // MARK: - talkingPoints JSON round-trip

    @MainActor
    func testTalkingPoints_nilData_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertTrue(person.talkingPoints.isEmpty)
    }

    @MainActor
    func testTalkingPoints_roundTrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        person.talkingPoints = ["Project X", "Vacation plans"]
        try ctx.save()
        XCTAssertEqual(person.talkingPoints, ["Project X", "Vacation plans"])
    }

    // MARK: - needsReview

    @MainActor
    func testNeedsReview_noSRData_returnsTrue() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertTrue(person.needsReview) // nil → default true
    }

    @MainActor
    func testNeedsReview_srDataPast_returnsTrue() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        let pastDate = Date().addingTimeInterval(-86400) // yesterday
        _ = TestHelpers.makeSpacedRepetitionData(nextReviewDate: pastDate, for: person, in: ctx)
        try ctx.save()
        XCTAssertTrue(person.needsReview)
    }

    @MainActor
    func testNeedsReview_srDataFuture_returnsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        let futureDate = Date().addingTimeInterval(86400) // tomorrow
        _ = TestHelpers.makeSpacedRepetitionData(nextReviewDate: futureDate, for: person, in: ctx)
        try ctx.save()
        XCTAssertFalse(person.needsReview)
    }

    // MARK: - profileEmbedding

    @MainActor
    func testProfileEmbedding_noEmbeddings_returnsNil() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertNil(person.profileEmbedding)
    }

    @MainActor
    func testProfileEmbedding_noProfileId_returnsFirst() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()
        XCTAssertNotNil(person.profileEmbedding)
        XCTAssertEqual(person.profileEmbedding?.id, person.embeddings?.first?.id)
    }

    @MainActor
    func testProfileEmbedding_withProfileId_returnsMatching() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)

        // Add a second embedding
        let vector2 = TestHelpers.makeEmbeddingVector(seed: 2)
        let embedding2 = FaceEmbedding(
            vector: TestHelpers.vectorToData(vector2),
            faceCropData: Data()
        )
        embedding2.person = person
        person.embeddings = (person.embeddings ?? []) + [embedding2]
        ctx.insert(embedding2)

        // Set profileEmbeddingId to the second one
        person.profileEmbeddingId = embedding2.id
        try ctx.save()

        XCTAssertEqual(person.profileEmbedding?.id, embedding2.id)
    }

    @MainActor
    func testProfileEmbedding_profileIdNotFound_fallsBackToFirst() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        person.profileEmbeddingId = UUID() // non-existent ID
        try ctx.save()

        XCTAssertNotNil(person.profileEmbedding)
        XCTAssertEqual(person.profileEmbedding?.id, person.embeddings?.first?.id)
    }

    // MARK: - Contact Photo Export (issue #2)

    /// Regression test for issue #2: a person with a linked contact and a
    /// profile embedding must have accessible faceCropData for photo export.
    @MainActor
    func testLinkedPerson_profileDataAvailableForExport() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        person.contactIdentifier = "test-contact-id"
        try ctx.save()

        // Linked person with embedding should have exportable data
        XCTAssertNotNil(person.contactIdentifier)
        XCTAssertNotNil(person.profileEmbedding)
        XCTAssertNotNil(person.profileEmbedding?.faceCropData,
                        "Linked person must have accessible faceCropData for contact photo export")
    }

    // MARK: - recentNotes

    @MainActor
    func testRecentNotes_nil_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()
        XCTAssertTrue(person.recentNotes.isEmpty)
    }

    @MainActor
    func testRecentNotes_threeNotes_sortedDescending() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)

        let oldest = InteractionNote(content: "Old", createdAt: Date().addingTimeInterval(-7200))
        oldest.person = person
        ctx.insert(oldest)

        let middle = InteractionNote(content: "Mid", createdAt: Date().addingTimeInterval(-3600))
        middle.person = person
        ctx.insert(middle)

        let newest = InteractionNote(content: "New", createdAt: Date())
        newest.person = person
        ctx.insert(newest)

        try ctx.save()

        let notes = person.recentNotes
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes[0].content, "New")
        XCTAssertEqual(notes[1].content, "Mid")
        XCTAssertEqual(notes[2].content, "Old")
    }

    @MainActor
    func testRecentNotes_sevenNotes_returnsOnlyFive() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)

        for i in 0..<7 {
            let note = InteractionNote(
                content: "Note \(i)",
                createdAt: Date().addingTimeInterval(Double(i) * 3600)
            )
            note.person = person
            ctx.insert(note)
        }
        try ctx.save()
        XCTAssertEqual(person.recentNotes.count, 5)
    }
}
