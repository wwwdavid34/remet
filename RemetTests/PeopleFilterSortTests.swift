import XCTest
import SwiftData
@testable import Remet

/// Tests for the people filtering and sorting logic.
/// Mirrors the filteredPeople computed property in AllPeopleListView.
final class PeopleFilterSortTests: XCTestCase {

    /// Replicates the exact logic from AllPeopleListView.filteredPeople
    private func applyPeopleFilter(
        people: [Person],
        showMe: Bool = true,
        searchText: String = "",
        selectedTagFilters: Set<UUID> = [],
        selectedTimeFilter: TimeFilter = .all,
        filterFavoritesOnly: Bool = false,
        selectedSortOption: PersonSortOption = .nameAZ
    ) -> [Person] {
        var result = showMe ? Array(people) : people.filter { !$0.isMe }

        if !searchText.isEmpty {
            result = result.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                (person.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if !selectedTagFilters.isEmpty {
            result = result.filter { person in
                let personTagIds = Set((person.tags ?? []).map { $0.id })
                return !selectedTagFilters.isDisjoint(with: personTagIds)
            }
        }

        if selectedTimeFilter != .all, let dateRange = selectedTimeFilter.dateRange {
            result = result.filter { person in
                person.createdAt >= dateRange.start && person.createdAt <= dateRange.end
            }
        }

        if filterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        switch selectedSortOption {
        case .nameAZ:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .mostEncounters:
            result.sort { ($0.encounters ?? []).count > ($1.encounters ?? []).count }
        }

        if showMe {
            result.sort { p1, p2 in
                if p1.isMe { return true }
                if p2.isMe { return false }
                return false
            }
        }

        return result
    }

    // MARK: - Show Me Filter

    @MainActor
    func testFilter_showMeFalse_excludesMe() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let me = TestHelpers.makePerson(name: "Me", isMe: true, in: ctx)
        let alice = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [me, alice], showMe: false)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Alice")
    }

    // MARK: - Search

    @MainActor
    func testFilter_searchByName_caseInsensitive() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let alice = TestHelpers.makePerson(name: "Alice", in: ctx)
        _ = TestHelpers.makePerson(name: "Bob", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [alice], searchText: "ali")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Alice")
    }

    @MainActor
    func testFilter_searchByNotes() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Bob", notes: "Loves coffee", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [person], searchText: "coffee")
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testFilter_searchByTagName() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Carol", in: ctx)
        let tag = TestHelpers.makeTag(name: "Conference", in: ctx)
        person.tags = [tag]
        try ctx.save()

        let result = applyPeopleFilter(people: [person], searchText: "conference")
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testFilter_searchNoMatch_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [person], searchText: "zzzzz")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Tag Filter

    @MainActor
    func testFilter_tagOR_personWithOneMatch_included() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        person.tags = [tag1]
        try ctx.save()

        let result = applyPeopleFilter(people: [person], selectedTagFilters: [tag1.id, tag2.id])
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testFilter_tag_personNoMatch_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        person.tags = [tag1]
        try ctx.save()

        let result = applyPeopleFilter(people: [person], selectedTagFilters: [tag2.id])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Favorites Filter

    @MainActor
    func testFilter_favorites_excludesNonFavorite() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let fav = TestHelpers.makePerson(name: "Alice", isFavorite: true, in: ctx)
        let notFav = TestHelpers.makePerson(name: "Bob", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [fav, notFav], filterFavoritesOnly: true)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Alice")
    }

    // MARK: - Sorting

    @MainActor
    func testSort_nameAZ() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let z = TestHelpers.makePerson(name: "Zebra", in: ctx)
        let a = TestHelpers.makePerson(name: "Apple", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [z, a], showMe: false, selectedSortOption: .nameAZ)
        XCTAssertEqual(result.map(\.name), ["Apple", "Zebra"])
    }

    @MainActor
    func testSort_nameZA() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let a = TestHelpers.makePerson(name: "Apple", in: ctx)
        let z = TestHelpers.makePerson(name: "Zebra", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [a, z], showMe: false, selectedSortOption: .nameZA)
        XCTAssertEqual(result.map(\.name), ["Zebra", "Apple"])
    }

    @MainActor
    func testSort_newestFirst() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let older = TestHelpers.makePerson(name: "Old", createdAt: Date().addingTimeInterval(-86400), in: ctx)
        let newer = TestHelpers.makePerson(name: "New", createdAt: Date(), in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [older, newer], showMe: false, selectedSortOption: .newestFirst)
        XCTAssertEqual(result.first?.name, "New")
    }

    @MainActor
    func testSort_mostEncounters() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let few = TestHelpers.makePerson(name: "Few", in: ctx)
        let many = TestHelpers.makePerson(name: "Many", in: ctx)

        for i in 0..<5 {
            let e = TestHelpers.makeEncounter(occasion: "E\(i)", in: ctx)
            e.people = [many]
        }
        let e1 = TestHelpers.makeEncounter(occasion: "Single", in: ctx)
        e1.people = [few]
        try ctx.save()

        let result = applyPeopleFilter(people: [few, many], showMe: false, selectedSortOption: .mostEncounters)
        XCTAssertEqual(result.first?.name, "Many")
    }

    // MARK: - Me-to-Top Sorting

    @MainActor
    func testSort_meAlwaysFirst_whenShowMe() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let me = TestHelpers.makePerson(name: "Zoe (Me)", isMe: true, in: ctx)
        let alice = TestHelpers.makePerson(name: "Alice", in: ctx)
        try ctx.save()

        let result = applyPeopleFilter(people: [me, alice], showMe: true, selectedSortOption: .nameAZ)
        XCTAssertEqual(result.first?.name, "Zoe (Me)")
    }

    // MARK: - Combined Filters

    @MainActor
    func testFilter_combined_favoritesAndTag() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag = TestHelpers.makeTag(name: "Work", in: ctx)

        let favWithTag = TestHelpers.makePerson(name: "Alice", isFavorite: true, in: ctx)
        favWithTag.tags = [tag]

        let favNoTag = TestHelpers.makePerson(name: "Bob", isFavorite: true, in: ctx)
        let notFavWithTag = TestHelpers.makePerson(name: "Carol", in: ctx)
        notFavWithTag.tags = [tag]

        try ctx.save()

        let result = applyPeopleFilter(
            people: [favWithTag, favNoTag, notFavWithTag],
            showMe: false,
            selectedTagFilters: [tag.id],
            filterFavoritesOnly: true
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Alice")
    }

    // MARK: - hasActiveFilters / activeFilterCount

    func testHasActiveFilters_allDefaults_returnsFalse() {
        let result = hasActiveFilters(
            timeFilter: .all, tagCount: 0, sortOption: .nameAZ, favoritesOnly: false
        )
        XCTAssertFalse(result)
    }

    func testHasActiveFilters_favoritesOnly_returnsTrue() {
        XCTAssertTrue(hasActiveFilters(
            timeFilter: .all, tagCount: 0, sortOption: .nameAZ, favoritesOnly: true
        ))
    }

    func testHasActiveFilters_nonDefaultSort_returnsTrue() {
        XCTAssertTrue(hasActiveFilters(
            timeFilter: .all, tagCount: 0, sortOption: .newestFirst, favoritesOnly: false
        ))
    }

    func testActiveFilterCount_threeTags() {
        let count = activeFilterCount(
            timeFilter: .all, tagCount: 3, sortOption: .nameAZ, favoritesOnly: false
        )
        XCTAssertEqual(count, 3)
    }

    func testActiveFilterCount_allActive() {
        let count = activeFilterCount(
            timeFilter: .thisWeek, tagCount: 2, sortOption: .newestFirst, favoritesOnly: true
        )
        // time(1) + sort(1) + favorites(1) + tags(2) = 5
        XCTAssertEqual(count, 5)
    }

    // MARK: - Helpers (mirror AllPeopleListView logic)

    private func hasActiveFilters(
        timeFilter: TimeFilter, tagCount: Int, sortOption: PersonSortOption, favoritesOnly: Bool
    ) -> Bool {
        timeFilter != .all || tagCount > 0 || sortOption != .nameAZ || favoritesOnly
    }

    private func activeFilterCount(
        timeFilter: TimeFilter, tagCount: Int, sortOption: PersonSortOption, favoritesOnly: Bool
    ) -> Int {
        var count = 0
        if timeFilter != .all { count += 1 }
        if sortOption != .nameAZ { count += 1 }
        if favoritesOnly { count += 1 }
        count += tagCount
        return count
    }
}
