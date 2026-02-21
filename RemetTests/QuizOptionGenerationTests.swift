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
}
