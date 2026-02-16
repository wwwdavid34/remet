import XCTest
import SwiftData
@testable import Remet

final class FaceMatchingServiceTests: XCTestCase {

    private var sut: FaceMatchingService!

    override func setUp() {
        super.setUp()
        sut = FaceMatchingService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Cosine Similarity: Basic Properties

    func testCosineSimilarity_identicalVectors_returns1() {
        let v: [Float] = [0.5, 0.3, 0.8, 0.1]
        let result = sut.cosineSimilarity(v, v)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_oppositeVectors_returnsNegative1() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let result = sut.cosineSimilarity(a, b)
        XCTAssertEqual(result, -1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_orthogonalVectors_returns0() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let result = sut.cosineSimilarity(a, b)
        XCTAssertEqual(result, 0.0, accuracy: 0.001)
    }

    func testCosineSimilarity_isCommutative() {
        let a: [Float] = [0.5, 0.3, 0.8, 0.1]
        let b: [Float] = [0.2, 0.9, 0.4, 0.7]
        XCTAssertEqual(sut.cosineSimilarity(a, b), sut.cosineSimilarity(b, a), accuracy: 0.0001)
    }

    func testCosineSimilarity_scaleInvariant() {
        let a: [Float] = [1, 2, 3]
        let b: [Float] = [2, 4, 6] // 2x scale of a
        let result = sut.cosineSimilarity(a, b)
        XCTAssertEqual(result, 1.0, accuracy: 0.001, "Cosine similarity is scale-invariant")
    }

    // MARK: - Cosine Similarity: Edge Cases

    func testCosineSimilarity_emptyVectors_returns0() {
        XCTAssertEqual(sut.cosineSimilarity([], []), 0.0)
    }

    func testCosineSimilarity_mismatchedLengths_returns0() {
        XCTAssertEqual(sut.cosineSimilarity([1, 2, 3], [1, 2]), 0.0)
    }

    func testCosineSimilarity_zeroVector_returns0() {
        XCTAssertEqual(sut.cosineSimilarity([0, 0, 0], [1, 2, 3]), 0.0)
    }

    func testCosineSimilarity_bothZeroVectors_returns0() {
        XCTAssertEqual(sut.cosineSimilarity([0, 0], [0, 0]), 0.0)
    }

    // MARK: - Cosine Similarity: Realistic 512-D Vectors

    func testCosineSimilarity_sameSeedVectors_returns1() {
        let v = TestHelpers.makeEmbeddingVector(seed: 1)
        let result = sut.cosineSimilarity(v, v)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_differentSeedVectors_returnsLessThan1() {
        let a = TestHelpers.makeEmbeddingVector(seed: 1)
        let b = TestHelpers.makeEmbeddingVector(seed: 100)
        let result = sut.cosineSimilarity(a, b)
        XCTAssertLessThan(result, 1.0)
    }

    func testCosineSimilarity_highSimilarityPair() {
        let (a, b) = TestHelpers.makeVectorPair(similarity: 0.95)
        let result = sut.cosineSimilarity(a, b)
        // The mixing approach gives approximate similarity; just verify it's high
        XCTAssertGreaterThan(result, 0.7, "High similarity pair should have high cosine similarity")
    }

    // MARK: - findMatches: With SwiftData

    @MainActor
    func testFindMatches_returnsTopKResults() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)

        // Create people with different embedding seeds (different similarity to query)
        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: context)  // identical
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: context)      // similar
        let carol = TestHelpers.makePerson(name: "Carol", embeddingSeed: 100, in: context) // different

        try context.save()

        let results = sut.findMatches(
            for: queryVector,
            in: [alice, bob, carol],
            topK: 2,
            threshold: 0.0 // Accept all for this test
        )

        XCTAssertEqual(results.count, 2, "Should return topK=2 results")
        XCTAssertEqual(results.first?.person.id, alice.id, "Best match should be Alice (identical vector)")
    }

    @MainActor
    func testFindMatches_respectsThreshold() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)

        // Alice has identical embedding (similarity ~1.0)
        let _ = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: context)
        // Dave has very different embedding
        let _ = TestHelpers.makePerson(name: "Dave", embeddingSeed: 500, in: context)

        try context.save()

        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        let results = sut.findMatches(
            for: queryVector,
            in: people,
            topK: 10,
            threshold: 0.99 // Very high threshold
        )

        // Only Alice should pass the high threshold
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.person.name, "Alice")
    }

    @MainActor
    func testFindMatches_sortedByDescendingSimilarity() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)

        let _ = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: context)   // best
        let _ = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: context)     // good
        let _ = TestHelpers.makePerson(name: "Carol", embeddingSeed: 50, in: context)  // worse

        try context.save()

        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        let results = sut.findMatches(for: queryVector, in: people, topK: 10, threshold: 0.0)

        // Verify descending order
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].similarity,
                results[i + 1].similarity,
                "Results should be sorted by descending similarity"
            )
        }
    }

    @MainActor
    func testFindMatches_personWithNoEmbeddings_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)

        // Person without embedding
        let _ = TestHelpers.makePerson(name: "NoFace", embeddingSeed: nil, in: context)
        // Person with embedding
        let _ = TestHelpers.makePerson(name: "HasFace", embeddingSeed: 1, in: context)

        try context.save()

        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        let results = sut.findMatches(for: queryVector, in: people, topK: 10, threshold: 0.0)

        let names = results.map { $0.person.name }
        XCTAssertFalse(names.contains("NoFace"), "Person without embeddings should not appear in results")
    }

    @MainActor
    func testFindMatches_emptyPeopleList_returnsEmpty() {
        let results = sut.findMatches(
            for: TestHelpers.makeEmbeddingVector(seed: 1),
            in: [],
            topK: 5
        )
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Confidence Levels

    @MainActor
    func testFindMatches_highSimilarity_returnsHighConfidence() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)
        let _ = TestHelpers.makePerson(name: "Twin", embeddingSeed: 1, in: context) // identical = 1.0

        try context.save()

        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        let results = sut.findMatches(for: queryVector, in: people, topK: 1, threshold: 0.0)

        XCTAssertEqual(results.first?.confidence, .high, "Similarity of 1.0 should be high confidence")
    }

    // MARK: - Boost

    @MainActor
    func testFindMatches_boostPersonIds_increasesSimilarity() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = container.mainContext

        let queryVector = TestHelpers.makeEmbeddingVector(seed: 1)
        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 2, in: context)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: context) // same similarity as Alice

        try context.save()

        // Without boost
        let resultsNoBooost = sut.findMatches(
            for: queryVector, in: [alice, bob], topK: 2, threshold: 0.0
        )

        // With boost on Bob
        let resultsBoosted = sut.findMatches(
            for: queryVector, in: [alice, bob], topK: 2, threshold: 0.0,
            boostPersonIds: [bob.id]
        )

        let bobScoreNormal = resultsNoBooost.first(where: { $0.person.id == bob.id })?.similarity ?? 0
        let bobScoreBoosted = resultsBoosted.first(where: { $0.person.id == bob.id })?.similarity ?? 0

        XCTAssertGreaterThan(bobScoreBoosted, bobScoreNormal, "Boosted score should be higher")
    }
}
