import XCTest
import SwiftData
@testable import Remet

final class ModelRelationshipTests: XCTestCase {

    // MARK: - Person + FaceEmbedding

    @MainActor
    func testPerson_addEmbedding_createsRelationship() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: context)
        try context.save()

        XCTAssertEqual(person.embeddings?.count, 1)
        XCTAssertEqual(person.embeddings?.first?.person?.id, person.id)
    }

    @MainActor
    func testPerson_multipleEmbeddings() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Bob")
        context.insert(person)

        let emb1 = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 1)),
            faceCropData: Data()
        )
        let emb2 = FaceEmbedding(
            vector: TestHelpers.vectorToData(TestHelpers.makeEmbeddingVector(seed: 2)),
            faceCropData: Data()
        )
        emb1.person = person
        emb2.person = person
        person.embeddings = [emb1, emb2]
        context.insert(emb1)
        context.insert(emb2)
        try context.save()

        XCTAssertEqual(person.embeddings?.count, 2)
    }

    @MainActor
    func testPerson_withoutEmbedding_hasEmptyList() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = TestHelpers.makePerson(name: "NoFace", embeddingSeed: nil, in: context)
        try context.save()

        XCTAssertTrue((person.embeddings ?? []).isEmpty)
    }

    // MARK: - FaceEmbedding Vector Storage

    @MainActor
    func testFaceEmbedding_vectorRoundtrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let originalVector: [Float] = [0.1, 0.2, 0.3, -0.5, 0.99]
        let embedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(originalVector),
            faceCropData: Data()
        )
        context.insert(embedding)
        try context.save()

        let retrieved = embedding.embeddingVector
        XCTAssertEqual(retrieved.count, originalVector.count)
        for i in 0..<originalVector.count {
            XCTAssertEqual(retrieved[i], originalVector[i], accuracy: 0.0001)
        }
    }

    @MainActor
    func testFaceEmbedding_512dVectorRoundtrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let originalVector = TestHelpers.makeEmbeddingVector(seed: 42)
        XCTAssertEqual(originalVector.count, 512)

        let embedding = FaceEmbedding(
            vector: TestHelpers.vectorToData(originalVector),
            faceCropData: Data()
        )
        context.insert(embedding)
        try context.save()

        let retrieved = embedding.embeddingVector
        XCTAssertEqual(retrieved.count, 512)
        for i in 0..<512 {
            XCTAssertEqual(retrieved[i], originalVector[i], accuracy: 0.0001)
        }
    }

    // MARK: - Person + Tags

    @MainActor
    func testPerson_addTags_createsRelationship() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Carol")
        context.insert(person)

        let workTag = TestHelpers.makeTag(name: "Work", in: context)
        let friendTag = TestHelpers.makeTag(name: "Friends", in: context)

        person.tags = [workTag, friendTag]
        try context.save()

        XCTAssertEqual(person.tags?.count, 2)
        let tagNames = Set(person.tags?.map(\.name) ?? [])
        XCTAssertTrue(tagNames.contains("Work"))
        XCTAssertTrue(tagNames.contains("Friends"))
    }

    @MainActor
    func testTag_inverseRelationship_showsPeople() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let tag = TestHelpers.makeTag(name: "Coworkers", in: context)
        let alice = Person(name: "Alice")
        let bob = Person(name: "Bob")
        context.insert(alice)
        context.insert(bob)

        alice.tags = [tag]
        bob.tags = [tag]
        try context.save()

        XCTAssertEqual(tag.people?.count, 2)
    }

    // MARK: - Person + QuizAttempts

    @MainActor
    func testPerson_quizAttempts_recordCorrectAndIncorrect() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Dave")
        context.insert(person)

        let correct = QuizAttempt(wasCorrect: true, responseTimeMs: 1200)
        correct.person = person
        context.insert(correct)

        let incorrect = QuizAttempt(wasCorrect: false, responseTimeMs: 3000, userGuess: "Eve")
        incorrect.person = person
        context.insert(incorrect)

        person.quizAttempts = [correct, incorrect]
        try context.save()

        XCTAssertEqual(person.quizAttempts?.count, 2)

        let correctAttempts = person.quizAttempts?.filter(\.wasCorrect) ?? []
        XCTAssertEqual(correctAttempts.count, 1)

        let incorrectAttempts = person.quizAttempts?.filter { !$0.wasCorrect } ?? []
        XCTAssertEqual(incorrectAttempts.count, 1)
        XCTAssertEqual(incorrectAttempts.first?.userGuess, "Eve")
    }

    // MARK: - Person + SpacedRepetitionData

    @MainActor
    func testPerson_spacedRepetitionData_relationship() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Frank")
        context.insert(person)

        let srd = SpacedRepetitionData()
        srd.person = person
        person.spacedRepetitionData = srd
        context.insert(srd)
        try context.save()

        XCTAssertNotNil(person.spacedRepetitionData)
        XCTAssertEqual(person.spacedRepetitionData?.person?.id, person.id)
    }

    @MainActor
    func testPerson_needsReview_defaultsToTrue() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Grace")
        context.insert(person)
        try context.save()

        // No spaced repetition data → needsReview defaults to true
        XCTAssertTrue(person.needsReview)
    }

    // MARK: - Person Computed Properties

    @MainActor
    func testPerson_interests_jsonRoundtrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Helen")
        context.insert(person)

        person.interests = ["Photography", "Cooking", "Travel"]
        try context.save()

        XCTAssertEqual(person.interests.count, 3)
        XCTAssertTrue(person.interests.contains("Photography"))
    }

    @MainActor
    func testPerson_talkingPoints_jsonRoundtrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Ivan")
        context.insert(person)

        person.talkingPoints = ["Ask about project", "Recommend book"]
        try context.save()

        XCTAssertEqual(person.talkingPoints.count, 2)
        XCTAssertEqual(person.talkingPoints.first, "Ask about project")
    }

    @MainActor
    func testPerson_interests_emptyByDefault() {
        let person = Person(name: "Jane")
        XCTAssertTrue(person.interests.isEmpty)
        XCTAssertTrue(person.talkingPoints.isEmpty)
    }

    // MARK: - Person encounterCount

    @MainActor
    func testPerson_encounterCount_reflectsEncounters() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let person = Person(name: "Kim")
        context.insert(person)

        let enc1 = Encounter(occasion: "Coffee", date: Date())
        let enc2 = Encounter(occasion: "Lunch", date: Date())
        context.insert(enc1)
        context.insert(enc2)

        person.encounters = [enc1, enc2]
        try context.save()

        XCTAssertEqual(person.encounterCount, 2)
    }

    @MainActor
    func testPerson_encounterCount_zeroByDefault() {
        let person = Person(name: "Leo")
        XCTAssertEqual(person.encounterCount, 0)
    }
}
