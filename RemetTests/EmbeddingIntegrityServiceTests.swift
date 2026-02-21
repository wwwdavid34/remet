import XCTest
import SwiftData
@testable import Remet

/// Tests for EmbeddingIntegrityService orphaned embedding detection and cleanup.
final class EmbeddingIntegrityServiceTests: XCTestCase {

    // MARK: - Orphan Detection

    @MainActor
    func testCleanup_reassignedEmbedding_isDeleted() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)

        let boxId = UUID()

        // Alice has an orphaned embedding whose bounding box was re-labeled to Bob
        let orphanedEmbedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 99)),
            faceCropData: Data(),
            boundingBoxId: boxId
        )
        orphanedEmbedding.person = alice
        alice.embeddings = (alice.embeddings ?? []) + [orphanedEmbedding]
        ctx.insert(orphanedEmbedding)

        // Encounter with bounding box now owned by Bob
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: boxId, rect: .zero, personId: bob.id)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        XCTAssertEqual((alice.embeddings ?? []).count, 2, "Alice starts with 2 embeddings (1 correct + 1 orphaned)")

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice, bob],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 1, "Should detect 1 orphaned embedding")
        XCTAssertEqual(result.peopleAffected, 1, "Should affect 1 person (Alice)")

        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        let aliceEmbeddings = allEmbeddings.filter { $0.person?.id == alice.id }
        XCTAssertEqual(aliceEmbeddings.count, 1, "Orphaned embedding should be deleted")
    }

    @MainActor
    func testCleanup_correctEmbedding_isKept() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let boxId = UUID()

        let embedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 1)),
            faceCropData: Data(),
            boundingBoxId: boxId
        )
        embedding.person = alice
        alice.embeddings = [embedding]
        ctx.insert(embedding)

        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: boxId, rect: .zero, personId: alice.id)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 0, "Correctly owned embedding must not be deleted")
        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        XCTAssertEqual(allEmbeddings.filter { $0.person?.id == alice.id }.count, 1)
    }

    @MainActor
    func testCleanup_noEncounters_noDeletion() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 0, "No encounters means no orphan detection")
        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        XCTAssertEqual(allEmbeddings.filter { $0.person?.id == alice.id }.count, 1)
    }

    @MainActor
    func testCleanup_embeddingWithoutBoxId_isKept() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)

        // Encounter with a box owned by Bob — but Alice's embedding has no boundingBoxId
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: UUID(), rect: .zero, personId: bob.id)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 0, "Embedding with no boundingBoxId must not be deleted")
    }

    @MainActor
    func testCleanup_unownedBox_embeddingRemoved() throws {
        // Box exists but personId is nil (label was cleared) → orphaned
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let boxId = UUID()

        let embedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 1)),
            faceCropData: Data(),
            boundingBoxId: boxId
        )
        embedding.person = alice
        alice.embeddings = [embedding]
        ctx.insert(embedding)

        // Encounter with bounding box that has nil personId (label cleared)
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: boxId, rect: .zero, personId: nil)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 1, "Embedding linked to unowned box should be removed")
    }

    // MARK: - Filtered People Output

    @MainActor
    func testCleanup_personWithAllEmbeddingsOrphaned_filteredOut() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: nil, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        let boxId = UUID()

        // Alice's only embedding is orphaned
        let orphanedEmbedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 99)),
            faceCropData: Data(),
            boundingBoxId: boxId
        )
        orphanedEmbedding.person = alice
        alice.embeddings = [orphanedEmbedding]
        ctx.insert(orphanedEmbedding)

        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: boxId, rect: .zero, personId: bob.id)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        let (cleanPeople, _) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice, bob],
            using: ctx
        )

        XCTAssertFalse(cleanPeople.contains(where: { $0.id == alice.id }),
                        "Person with all embeddings orphaned should be filtered from quiz")
        XCTAssertTrue(cleanPeople.contains(where: { $0.id == bob.id }),
                       "Person with valid embeddings should remain")
    }

    // MARK: - Multi-Photo Encounters

    @MainActor
    func testCleanup_multiPhotoEncounter_detectsOrphan() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        let boxId = UUID()

        // Alice has orphaned embedding from a multi-photo encounter
        let orphanedEmbedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 99)),
            faceCropData: Data(),
            boundingBoxId: boxId
        )
        orphanedEmbedding.person = alice
        alice.embeddings = (alice.embeddings ?? []) + [orphanedEmbedding]
        ctx.insert(orphanedEmbedding)

        // Box lives in an EncounterPhoto, not the encounter's legacy array
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let photo = TestHelpers.makeEncounterPhoto(in: ctx)
        var photoBoxes = photo.faceBoundingBoxes
        photoBoxes.append(FaceBoundingBox(id: boxId, rect: .zero, personId: bob.id))
        photo.faceBoundingBoxes = photoBoxes
        encounter.photos = [photo]

        try ctx.save()

        let (_, result) = EmbeddingIntegrityService.cleanAndFilter(
            people: [alice, bob],
            using: ctx
        )

        XCTAssertEqual(result.orphansRemoved, 1, "Should detect orphan in multi-photo encounter")
    }
}
