import XCTest
import SwiftData
@testable import Remet

/// Tests for practice quiz filtering logic added in commit 27a1e4e.
/// Mirrors troubleFaces, masteredCount, hasCustomFilters, customFilterSummary,
/// and overallAccuracy from PracticeHomeView.
final class PracticeQuizFilterTests: XCTestCase {

    // MARK: - troubleFaces

    /// Replicates PracticeHomeView.troubleFaces criteria:
    /// - Has face embeddings (not isMe)
    /// - Has spacedRepetitionData
    /// - totalAttempts >= 2
    /// - accuracy < 0.6
    /// Sorted ascending by accuracy (worst first)
    private func troubleFaces(from people: [Person]) -> [Person] {
        people.filter { person in
            guard !person.isMe,
                  (person.embeddings ?? []).count > 0,
                  let srData = person.spacedRepetitionData else { return false }
            return srData.totalAttempts >= 2 && srData.accuracy < 0.6
        }.sorted { p1, p2 in
            (p1.spacedRepetitionData?.accuracy ?? 1) < (p2.spacedRepetitionData?.accuracy ?? 1)
        }
    }

    @MainActor
    func testTroubleFaces_noSRData_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        XCTAssertTrue(troubleFaces(from: [person]).isEmpty)
    }

    @MainActor
    func testTroubleFaces_oneAttempt_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 1, correctAttempts: 0, for: person, in: ctx)
        try ctx.save()

        XCTAssertTrue(troubleFaces(from: [person]).isEmpty)
    }

    @MainActor
    func testTroubleFaces_twoAttempts70Pct_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 10, correctAttempts: 7, for: person, in: ctx)
        try ctx.save()

        XCTAssertTrue(troubleFaces(from: [person]).isEmpty) // 0.7 >= 0.6
    }

    @MainActor
    func testTroubleFaces_twoAttempts50Pct_included() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 2, correctAttempts: 1, for: person, in: ctx)
        try ctx.save()

        let result = troubleFaces(from: [person])
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testTroubleFaces_sortedByAccuracyAscending() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let worst = TestHelpers.makePerson(name: "Worst", embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 10, correctAttempts: 1, for: worst, in: ctx) // 0.1

        let bad = TestHelpers.makePerson(name: "Bad", embeddingSeed: 2, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 10, correctAttempts: 5, for: bad, in: ctx) // 0.5

        try ctx.save()

        let result = troubleFaces(from: [bad, worst])
        XCTAssertEqual(result[0].name, "Worst")
        XCTAssertEqual(result[1].name, "Bad")
    }

    @MainActor
    func testTroubleFaces_isMe_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let me = TestHelpers.makePerson(name: "Me", isMe: true, embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 10, correctAttempts: 1, for: me, in: ctx)
        try ctx.save()

        XCTAssertTrue(troubleFaces(from: [me]).isEmpty)
    }

    // MARK: - masteredCount

    /// Replicates PracticeHomeView.masteredCount:
    /// accuracy >= 0.8 AND totalAttempts >= 3
    private func masteredCount(from people: [Person]) -> Int {
        people.filter { person in
            guard !person.isMe,
                  (person.embeddings ?? []).count > 0,
                  let srData = person.spacedRepetitionData else { return false }
            return srData.accuracy >= 0.8 && srData.totalAttempts >= 3
        }.count
    }

    @MainActor
    func testMastered_twoAttempts100Pct_notMastered() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 2, correctAttempts: 2, for: person, in: ctx)
        try ctx.save()

        XCTAssertEqual(masteredCount(from: [person]), 0)
    }

    @MainActor
    func testMastered_threeAttempts79Pct_notMastered() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        // 7/9 ≈ 0.778 < 0.8
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 9, correctAttempts: 7, for: person, in: ctx)
        try ctx.save()

        XCTAssertEqual(masteredCount(from: [person]), 0)
    }

    @MainActor
    func testMastered_threeAttempts80Pct_mastered() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        // 4/5 = 0.8
        _ = TestHelpers.makeSpacedRepetitionData(totalAttempts: 5, correctAttempts: 4, for: person, in: ctx)
        try ctx.save()

        XCTAssertEqual(masteredCount(from: [person]), 1)
    }

    @MainActor
    func testMastered_noSRData_notMastered() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        XCTAssertEqual(masteredCount(from: [person]), 0)
    }

    // MARK: - hasCustomFilters

    func testHasCustomFilters_allDefaults_returnsFalse() {
        XCTAssertFalse(hasCustomFilters(
            favoritesOnly: false, relationship: nil, context: nil, tagIds: []
        ))
    }

    func testHasCustomFilters_favoritesOnly_returnsTrue() {
        XCTAssertTrue(hasCustomFilters(
            favoritesOnly: true, relationship: nil, context: nil, tagIds: []
        ))
    }

    func testHasCustomFilters_relationship_returnsTrue() {
        XCTAssertTrue(hasCustomFilters(
            favoritesOnly: false, relationship: "Friend", context: nil, tagIds: []
        ))
    }

    func testHasCustomFilters_context_returnsTrue() {
        XCTAssertTrue(hasCustomFilters(
            favoritesOnly: false, relationship: nil, context: "Work", tagIds: []
        ))
    }

    func testHasCustomFilters_tags_returnsTrue() {
        XCTAssertTrue(hasCustomFilters(
            favoritesOnly: false, relationship: nil, context: nil, tagIds: [UUID()]
        ))
    }

    // MARK: - customFilterSummary

    func testCustomFilterSummary_noFilters_allPeople() {
        XCTAssertEqual(customFilterSummary(
            favoritesOnly: false, relationship: nil, context: nil, tagCount: 0
        ), "All People")
    }

    func testCustomFilterSummary_favoritesOnly() {
        XCTAssertEqual(customFilterSummary(
            favoritesOnly: true, relationship: nil, context: nil, tagCount: 0
        ), "Favorites")
    }

    func testCustomFilterSummary_relationship() {
        XCTAssertEqual(customFilterSummary(
            favoritesOnly: false, relationship: "Friend", context: nil, tagCount: 0
        ), "Friend")
    }

    func testCustomFilterSummary_threeTags() {
        XCTAssertEqual(customFilterSummary(
            favoritesOnly: false, relationship: nil, context: nil, tagCount: 3
        ), "3 tags")
    }

    func testCustomFilterSummary_multiple_joinedWithDot() {
        let result = customFilterSummary(
            favoritesOnly: true, relationship: "Coworker", context: "Work", tagCount: 2
        )
        XCTAssertTrue(result.contains("Favorites"))
        XCTAssertTrue(result.contains("Coworker"))
        XCTAssertTrue(result.contains("Work"))
        XCTAssertTrue(result.contains("2 tags"))
        XCTAssertTrue(result.contains(" · "))
    }

    // MARK: - overallAccuracy

    func testOverallAccuracy_noAttempts_returnsZero() {
        XCTAssertEqual(overallAccuracy(totalAttempts: 0, totalCorrect: 0), 0.0)
    }

    func testOverallAccuracy_someAttempts_returnsRatio() {
        XCTAssertEqual(overallAccuracy(totalAttempts: 10, totalCorrect: 7), 0.7, accuracy: 0.001)
    }

    func testOverallAccuracy_allCorrect_returnsOne() {
        XCTAssertEqual(overallAccuracy(totalAttempts: 5, totalCorrect: 5), 1.0)
    }

    // MARK: - Helpers (mirror PracticeHomeView logic)

    private func hasCustomFilters(
        favoritesOnly: Bool, relationship: String?, context: String?, tagIds: Set<UUID>
    ) -> Bool {
        favoritesOnly || relationship != nil || context != nil || !tagIds.isEmpty
    }

    private func customFilterSummary(
        favoritesOnly: Bool, relationship: String?, context: String?, tagCount: Int
    ) -> String {
        var parts: [String] = []
        if favoritesOnly { parts.append("Favorites") }
        if let rel = relationship { parts.append(rel) }
        if let ctx = context { parts.append(ctx) }
        if tagCount > 0 { parts.append("\(tagCount) tags") }
        return parts.isEmpty ? "All People" : parts.joined(separator: " · ")
    }

    private func overallAccuracy(totalAttempts: Int, totalCorrect: Int) -> Double {
        totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0
    }
}
