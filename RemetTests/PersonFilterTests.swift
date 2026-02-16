import XCTest
import SwiftData
@testable import Remet

/// Tests for the custom group quiz filtering logic.
/// Mirrors the filter logic in PracticeHomeView.filteredQuizPeople.
final class PersonFilterTests: XCTestCase {

    // MARK: - Filter Logic (extracted from PracticeHomeView)

    /// Applies the same filter logic as PracticeHomeView.filteredQuizPeople
    private func applyFilters(
        people: [Person],
        favoritesOnly: Bool = false,
        relationship: String? = nil,
        context: String? = nil,
        tagIds: Set<UUID> = []
    ) -> [Person] {
        var result = people

        if favoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        if let relationship {
            result = result.filter { $0.relationship == relationship }
        }

        if let context {
            result = result.filter { $0.contextTag == context }
        }

        if !tagIds.isEmpty {
            result = result.filter { person in
                let personTagIds = Set((person.tags ?? []).map(\.id))
                return !personTagIds.isDisjoint(with: tagIds)
            }
        }

        return result
    }

    // MARK: - No Filters

    @MainActor
    func testNoFilters_returnsAllPeople() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [alice, bob])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Favorites Filter

    @MainActor
    func testFavoritesOnly_filtersCorrectly() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let fav = TestHelpers.makePerson(name: "Fav", isFavorite: true, embeddingSeed: 1, in: ctx)
        let _ = TestHelpers.makePerson(name: "NotFav", isFavorite: false, embeddingSeed: 2, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [fav], favoritesOnly: true)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Fav")
    }

    @MainActor
    func testFavoritesOnly_noFavorites_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let p = TestHelpers.makePerson(name: "NotFav", isFavorite: false, embeddingSeed: 1, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [p], favoritesOnly: true)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Relationship Filter

    @MainActor
    func testRelationshipFilter_matchesExactly() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let coworker = TestHelpers.makePerson(name: "Alice", relationship: "Coworker", embeddingSeed: 1, in: ctx)
        let friend = TestHelpers.makePerson(name: "Bob", relationship: "Friend", embeddingSeed: 2, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [coworker, friend], relationship: "Coworker")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Alice")
    }

    @MainActor
    func testRelationshipFilter_nilRelationship_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let noRel = TestHelpers.makePerson(name: "Unknown", relationship: nil, embeddingSeed: 1, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [noRel], relationship: "Coworker")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Context Filter

    @MainActor
    func testContextFilter_matchesExactly() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let work = TestHelpers.makePerson(name: "Alice", contextTag: "Work", embeddingSeed: 1, in: ctx)
        let gym = TestHelpers.makePerson(name: "Bob", contextTag: "Gym", embeddingSeed: 2, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [work, gym], context: "Work")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Alice")
    }

    // MARK: - Tag Filter

    @MainActor
    func testTagFilter_matchesAnySelectedTag() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let workTag = TestHelpers.makeTag(name: "Work", in: ctx)
        let travelTag = TestHelpers.makeTag(name: "Travel", in: ctx)

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        alice.tags = [workTag]

        let bob = TestHelpers.makePerson(name: "Bob", embeddingSeed: 2, in: ctx)
        bob.tags = [travelTag]

        let carol = TestHelpers.makePerson(name: "Carol", embeddingSeed: 3, in: ctx)
        // No tags

        try ctx.save()

        let result = applyFilters(people: [alice, bob, carol], tagIds: [workTag.id, travelTag.id])
        XCTAssertEqual(result.count, 2, "Alice and Bob have matching tags")

        let names = Set(result.map(\.name))
        XCTAssertTrue(names.contains("Alice"))
        XCTAssertTrue(names.contains("Bob"))
        XCTAssertFalse(names.contains("Carol"))
    }

    @MainActor
    func testTagFilter_emptyTagIds_returnsAll() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let alice = TestHelpers.makePerson(name: "Alice", embeddingSeed: 1, in: ctx)
        try ctx.save()

        let result = applyFilters(people: [alice], tagIds: [])
        XCTAssertEqual(result.count, 1, "Empty tag filter should not exclude anyone")
    }

    // MARK: - Combined Filters

    @MainActor
    func testCombinedFilters_favoritesAndRelationship() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let favCoworker = TestHelpers.makePerson(name: "Alice", relationship: "Coworker", isFavorite: true, embeddingSeed: 1, in: ctx)
        let _ = TestHelpers.makePerson(name: "Bob", relationship: "Coworker", isFavorite: false, embeddingSeed: 2, in: ctx)
        let _ = TestHelpers.makePerson(name: "Carol", relationship: "Friend", isFavorite: true, embeddingSeed: 3, in: ctx)
        try ctx.save()

        let descriptor = FetchDescriptor<Person>()
        let all = try ctx.fetch(descriptor)

        let result = applyFilters(people: all, favoritesOnly: true, relationship: "Coworker")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, favCoworker.id, "Only favorite coworker should pass both filters")
    }

    @MainActor
    func testCombinedFilters_allFiltersActive_noMatch_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let _ = TestHelpers.makePerson(name: "Alice", relationship: "Coworker", contextTag: "Work", isFavorite: false, embeddingSeed: 1, in: ctx)
        try ctx.save()

        let descriptor = FetchDescriptor<Person>()
        let all = try ctx.fetch(descriptor)

        let result = applyFilters(people: all, favoritesOnly: true, relationship: "Coworker", context: "Work")
        XCTAssertTrue(result.isEmpty, "Alice is not a favorite so should be excluded")
    }
}
