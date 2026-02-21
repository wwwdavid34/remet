import XCTest
import SwiftData
@testable import Remet

/// Tests for quiz option generation logic.
/// Mirrors the generateOptions() logic from FaceQuizView.
final class QuizOptionGenerationTests: XCTestCase {

    /// Replicates the option generation logic from FaceQuizView.generateOptions
    private func generateOptions(
        correctPerson: Person,
        allPeople: [Person],
        quizPeople: [Person]
    ) -> [String] {
        let namePool = (allPeople.isEmpty ? quizPeople : allPeople)
            .filter { !($0.embeddings ?? []).isEmpty }
        var wrongAnswers = namePool
            .filter { $0.id != correctPerson.id }
            .map { $0.name }
            .shuffled()

        let wrongCount = min(3, wrongAnswers.count)
        wrongAnswers = Array(wrongAnswers.prefix(wrongCount))

        return (wrongAnswers + [correctPerson.name]).shuffled()
    }

    // MARK: - Basic Option Generation

    @MainActor
    func testOptions_alwaysIncludeCorrectAnswer() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let correct = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let p2 = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        let p3 = TestHelpers.makePerson(name: "Carol", embeddingSeed: 3, in: ctx)
        let p4 = TestHelpers.makePerson(name: "Dave", embeddingSeed: 4, in: ctx)
        try ctx.save()

        let allPeople = [correct, p2, p3, p4]

        // Run multiple times since shuffling is involved
        for _ in 0..<20 {
            let options = generateOptions(correctPerson: correct, allPeople: allPeople, quizPeople: allPeople)
            XCTAssertTrue(options.contains("Alice"), "Correct answer must always be in options")
        }
    }

    @MainActor
    func testOptions_maxFourChoices() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let correct = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        var others: [Person] = []
        for i in 2..<10 {
            others.append(TestHelpers.makePerson(name: "Person\(i)", embeddingSeed: i, in: ctx))
        }
        try ctx.save()

        let allPeople = [correct] + others
        let options = generateOptions(correctPerson: correct, allPeople: allPeople, quizPeople: allPeople)

        XCTAssertEqual(options.count, 4, "Should have 3 wrong + 1 correct = 4 options")
    }

    @MainActor
    func testOptions_fewerThanFourPeople_adjustsCount() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let correct = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let other = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        try ctx.save()

        let allPeople = [correct, other]
        let options = generateOptions(correctPerson: correct, allPeople: allPeople, quizPeople: allPeople)

        XCTAssertEqual(options.count, 2, "With only 2 people: 1 wrong + 1 correct = 2 options")
        XCTAssertTrue(options.contains("Alice"))
        XCTAssertTrue(options.contains("Bob"))
    }

    @MainActor
    func testOptions_onlyOnePerson_showsOnlyCorrect() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let correct = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        let options = generateOptions(correctPerson: correct, allPeople: [correct], quizPeople: [correct])

        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options.first, "Alice")
    }

    @MainActor
    func testOptions_correctAnswerNotDuplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let correct = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let p2 = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        let p3 = TestHelpers.makePerson(name: "Carol", embeddingSeed: 3, in: ctx)
        let p4 = TestHelpers.makePerson(name: "Dave", embeddingSeed: 4, in: ctx)
        try ctx.save()

        let allPeople = [correct, p2, p3, p4]

        for _ in 0..<20 {
            let options = generateOptions(correctPerson: correct, allPeople: allPeople, quizPeople: allPeople)
            let aliceCount = options.filter { $0 == "Alice" }.count
            XCTAssertEqual(aliceCount, 1, "Correct answer should appear exactly once")
        }
    }

    // MARK: - Full Name Pool vs Filtered Subset

    @MainActor
    func testOptions_usesFullNamePool_notFilteredSubset() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        // Filtered quiz: only Alice
        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)

        // Full pool: Alice + 3 others
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        let carol = TestHelpers.makePerson(name: "Carol", embeddingSeed: 3, in: ctx)
        let dave = TestHelpers.makePerson(name: "Dave", embeddingSeed: 4, in: ctx)
        try ctx.save()

        let allPeople = [alice, bob, carol, dave]
        let quizPeople = [alice] // filtered subset

        let options = generateOptions(correctPerson: alice, allPeople: allPeople, quizPeople: quizPeople)

        XCTAssertEqual(options.count, 4, "Should draw wrong answers from full pool even though quiz subset is only 1 person")
        XCTAssertTrue(options.contains("Alice"))
    }

    @MainActor
    func testOptions_emptyAllPeople_fallsBackToQuizPeople() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        try ctx.save()

        let quizPeople = [alice, bob]

        // Pass empty allPeople — should fall back to quizPeople
        let options = generateOptions(correctPerson: alice, allPeople: [], quizPeople: quizPeople)

        XCTAssertTrue(options.contains("Alice"))
        XCTAssertTrue(options.contains("Bob"))
    }

    // MARK: - Removed Face Embeddings

    @MainActor
    func testOptions_personWithNoEmbeddings_excludedFromNamePool() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        // Dave has no embeddings (face removed)
        let dave = TestHelpers.makePerson(name: "Dave", embeddingSeed: nil, in: ctx)
        try ctx.save()

        let allPeople = [alice, bob, dave]
        let options = generateOptions(correctPerson: alice, allPeople: allPeople, quizPeople: allPeople)

        XCTAssertFalse(options.contains("Dave"), "Person with no face embeddings must not appear as a quiz option")
    }

    @MainActor
    func testOptions_correctPersonEmbeddingsRemoved_stillAppearsAsAnswer() throws {
        // Even if the correct person's embeddings were removed mid-session, their name
        // is always appended as the correct answer regardless of embedding state.
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        try ctx.save()

        // Simulate Alice's embedding being removed
        alice.embeddings = []

        let allPeople = [alice, bob]
        let options = generateOptions(correctPerson: alice, allPeople: allPeople, quizPeople: allPeople)

        // Alice is always appended as the correct answer in generateOptions
        XCTAssertTrue(options.contains("Alice"))
    }

    @MainActor
    func testOptions_allWrongAnswersHaveNoEmbeddings_onlyCorrectAnswerReturned() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        // Bob and Carol have no embeddings (faces removed)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: nil, in: ctx)
        let carol = TestHelpers.makePerson(name: "Carol", embeddingSeed: nil, in: ctx)
        try ctx.save()

        let allPeople = [alice, bob, carol]
        let options = generateOptions(correctPerson: alice, allPeople: allPeople, quizPeople: allPeople)

        XCTAssertEqual(options, ["Alice"], "With all wrong-answer candidates removed, only the correct answer should remain")
    }

    // MARK: - Orphaned Embedding Cleanup

    /// Replicates the removeOrphanedEmbeddings() logic from FaceQuizView.
    private func removeOrphanedEmbeddings(for people: [Person], encounters: [Encounter], in ctx: ModelContext) {
        var boxOwnership: [UUID: UUID] = [:]
        for encounter in encounters {
            for photo in encounter.photos ?? [] {
                for box in photo.faceBoundingBoxes where box.personId != nil {
                    boxOwnership[box.id] = box.personId!
                }
            }
            for box in encounter.faceBoundingBoxes where box.personId != nil {
                boxOwnership[box.id] = box.personId!
            }
        }
        guard !boxOwnership.isEmpty else { return }
        var didDelete = false
        for person in people {
            for embedding in person.embeddings ?? [] {
                guard let boxId = embedding.boundingBoxId,
                      let currentOwner = boxOwnership[boxId],
                      currentOwner != person.id else { continue }
                ctx.delete(embedding)
                didDelete = true
            }
        }
        if didDelete { try? ctx.save() }
    }

    @MainActor
    func testOrphanCleanup_reassignedEmbedding_isDeleted() throws {
        // Simulate pre-v1.1.0 pollution: Face was assigned to Alice, then re-labeled to Bob.
        // Alice still has the orphaned embedding (boundingBoxId points to a box now owned by Bob).
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

        removeOrphanedEmbeddings(for: [alice, bob], encounters: [encounter], in: ctx)

        // Re-fetch to confirm orphaned embedding was removed from the store
        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        let aliceEmbeddings = allEmbeddings.filter { $0.person?.id == alice.id }
        XCTAssertEqual(aliceEmbeddings.count, 1, "Orphaned embedding should be deleted; Alice should keep only her correct embedding")
        XCTAssertNil(aliceEmbeddings.first?.boundingBoxId, "Remaining embedding should be the one without a boundingBoxId (her own face)")
    }

    @MainActor
    func testOrphanCleanup_correctEmbedding_isKept() throws {
        // An embedding whose bounding box still belongs to the same person should NOT be deleted.
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

        removeOrphanedEmbeddings(for: [alice], encounters: [encounter], in: ctx)

        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        let aliceEmbeddings = allEmbeddings.filter { $0.person?.id == alice.id }
        XCTAssertEqual(aliceEmbeddings.count, 1, "Correctly owned embedding must not be deleted")
    }

    @MainActor
    func testOrphanCleanup_noEncounters_noDeletion() throws {
        // When there are no encounters (empty boxOwnership), nothing should be deleted.
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        removeOrphanedEmbeddings(for: [alice], encounters: [], in: ctx)

        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        let aliceEmbeddings = allEmbeddings.filter { $0.person?.id == alice.id }
        XCTAssertEqual(aliceEmbeddings.count, 1, "No encounters means no orphan detection; embedding should be kept")
    }

    @MainActor
    func testOrphanCleanup_embeddingWithoutBoxId_isKept() throws {
        // Embeddings without a boundingBoxId (e.g. from QuickCapture) must never be treated as orphaned.
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)

        // Encounter with a box owned by Bob — but Alice's embedding has no boundingBoxId
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let box = FaceBoundingBox(id: UUID(), rect: .zero, personId: bob.id)
        encounter.faceBoundingBoxes = [box]

        try ctx.save()

        removeOrphanedEmbeddings(for: [alice], encounters: [encounter], in: ctx)

        let allEmbeddings = try ctx.fetch(FetchDescriptor<FaceEmbedding>())
        let aliceEmbeddings = allEmbeddings.filter { $0.person?.id == alice.id }
        XCTAssertEqual(aliceEmbeddings.count, 1, "Embedding with no boundingBoxId must not be deleted")
    }
}
