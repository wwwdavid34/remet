import XCTest
import SwiftData
@testable import Remet

/// Tests for the encounter filtering and sorting logic.
/// Mirrors the filteredEncounters computed property in EncounterListView.
final class EncounterFilterSortTests: XCTestCase {

    /// Replicates the exact logic from EncounterListView.filteredEncounters
    private func applyEncounterFilter(
        encounters: [Encounter],
        searchText: String = "",
        selectedTagFilters: Set<UUID> = [],
        selectedTimeFilter: TimeFilter = .all,
        selectedLocation: String? = nil,
        filterFavoritesOnly: Bool = false,
        selectedSortOption: EncounterSortOption = .dateNewest
    ) -> [Encounter] {
        var result = encounters

        if !searchText.isEmpty {
            result = result.filter { encounter in
                encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
                encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
                (encounter.people ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        if !selectedTagFilters.isEmpty {
            result = result.filter { encounter in
                let encounterTagIds = Set((encounter.tags ?? []).map { $0.id })
                return !selectedTagFilters.isDisjoint(with: encounterTagIds)
            }
        }

        if selectedTimeFilter != .all, let dateRange = selectedTimeFilter.dateRange {
            result = result.filter { encounter in
                encounter.date >= dateRange.start && encounter.date <= dateRange.end
            }
        }

        if let location = selectedLocation, !location.isEmpty {
            result = result.filter { encounter in
                encounter.location?.localizedCaseInsensitiveCompare(location) == .orderedSame
            }
        }

        if filterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        switch selectedSortOption {
        case .dateNewest:
            result.sort { $0.date > $1.date }
        case .dateOldest:
            result.sort { $0.date < $1.date }
        case .mostPeople:
            result.sort { ($0.people ?? []).count > ($1.people ?? []).count }
        case .fewestPeople:
            result.sort { ($0.people ?? []).count < ($1.people ?? []).count }
        }

        return result
    }

    // MARK: - Search

    @MainActor
    func testSearch_byOccasion() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e1 = TestHelpers.makeEncounter(occasion: "Coffee meetup", in: ctx)
        let e2 = TestHelpers.makeEncounter(occasion: "Lunch", in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e1, e2], searchText: "coffee")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].occasion, "Coffee meetup")
    }

    @MainActor
    func testSearch_byLocation() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e = TestHelpers.makeEncounter(location: "Downtown Cafe", in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], searchText: "downtown")
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testSearch_byPersonName() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let person = TestHelpers.makePerson(name: "Alice", in: ctx)
        let e = TestHelpers.makeEncounter(in: ctx)
        e.people = [person]
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], searchText: "alice")
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Tag Filter

    @MainActor
    func testTagFilter_OR_oneMatching_included() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)
        let e = TestHelpers.makeEncounter(in: ctx)
        e.tags = [tag1]
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], selectedTagFilters: [tag1.id, tag2.id])
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testTagFilter_noMatch_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag1 = TestHelpers.makeTag(name: "Work", in: ctx)
        let tag2 = TestHelpers.makeTag(name: "Travel", in: ctx)
        let e = TestHelpers.makeEncounter(in: ctx)
        e.tags = [tag1]
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], selectedTagFilters: [tag2.id])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Location Filter

    @MainActor
    func testLocationFilter_caseInsensitive() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e = TestHelpers.makeEncounter(location: "Coffee Shop", in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], selectedLocation: "COFFEE SHOP")
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testLocationFilter_nilLocation_excluded() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e], selectedLocation: "Anywhere")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Favorites Filter

    @MainActor
    func testFavoritesFilter_excludesNonFavorite() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let fav = TestHelpers.makeEncounter(occasion: "Fav", isFavorite: true, in: ctx)
        let notFav = TestHelpers.makeEncounter(occasion: "NotFav", in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [fav, notFav], filterFavoritesOnly: true)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].occasion, "Fav")
    }

    // MARK: - Sorting

    @MainActor
    func testSort_dateNewest() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let older = TestHelpers.makeEncounter(date: Date().addingTimeInterval(-3600), in: ctx)
        let newer = TestHelpers.makeEncounter(date: Date(), in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [older, newer], selectedSortOption: .dateNewest)
        XCTAssertEqual(result.first?.id, newer.id)
    }

    @MainActor
    func testSort_dateOldest() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let older = TestHelpers.makeEncounter(date: Date().addingTimeInterval(-3600), in: ctx)
        let newer = TestHelpers.makeEncounter(date: Date(), in: ctx)
        try ctx.save()

        let result = applyEncounterFilter(encounters: [older, newer], selectedSortOption: .dateOldest)
        XCTAssertEqual(result.first?.id, older.id)
    }

    @MainActor
    func testSort_mostPeople() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e1 = TestHelpers.makeEncounter(in: ctx)
        let e2 = TestHelpers.makeEncounter(in: ctx)
        let p1 = TestHelpers.makePerson(name: "A", in: ctx)
        let p2 = TestHelpers.makePerson(name: "B", in: ctx)
        let p3 = TestHelpers.makePerson(name: "C", in: ctx)
        e1.people = [p1]
        e2.people = [p2, p3]
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e1, e2], selectedSortOption: .mostPeople)
        XCTAssertEqual(result.first?.id, e2.id)
    }

    @MainActor
    func testSort_fewestPeople() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e1 = TestHelpers.makeEncounter(in: ctx)
        let e2 = TestHelpers.makeEncounter(in: ctx)
        let p1 = TestHelpers.makePerson(name: "A", in: ctx)
        let p2 = TestHelpers.makePerson(name: "B", in: ctx)
        let p3 = TestHelpers.makePerson(name: "C", in: ctx)
        e1.people = [p1, p2, p3]
        e2.people = [p1]
        try ctx.save()

        let result = applyEncounterFilter(encounters: [e1, e2], selectedSortOption: .fewestPeople)
        XCTAssertEqual(result.first?.id, e2.id)
    }

    // MARK: - locationsInUse

    /// Replicates EncounterListView.locationsInUse
    private func locationsInUse(_ encounters: [Encounter]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for encounter in encounters {
            if let location = encounter.location, !location.isEmpty, !seen.contains(location) {
                seen.insert(location)
                result.append(location)
            }
        }
        return result.sorted()
    }

    @MainActor
    func testLocationsInUse_empty() throws {
        XCTAssertTrue(locationsInUse([]).isEmpty)
    }

    @MainActor
    func testLocationsInUse_nilAndEmptySkipped() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e1 = TestHelpers.makeEncounter(in: ctx) // nil location
        let e2 = TestHelpers.makeEncounter(location: "", in: ctx)
        let e3 = TestHelpers.makeEncounter(location: "Office", in: ctx)
        try ctx.save()

        let result = locationsInUse([e1, e2, e3])
        XCTAssertEqual(result, ["Office"])
    }

    @MainActor
    func testLocationsInUse_deduplicated() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let e1 = TestHelpers.makeEncounter(location: "Cafe", in: ctx)
        let e2 = TestHelpers.makeEncounter(location: "Cafe", in: ctx)
        let e3 = TestHelpers.makeEncounter(location: "Park", in: ctx)
        try ctx.save()

        let result = locationsInUse([e1, e2, e3])
        XCTAssertEqual(result, ["Cafe", "Park"])
    }

    // MARK: - hasActiveFilters / activeFilterCount (encounters version)

    func testEncounterHasActiveFilters_allDefaults_returnsFalse() {
        let result = encounterHasActiveFilters(
            timeFilter: .all, location: nil, tagCount: 0,
            sortOption: .dateNewest, favoritesOnly: false
        )
        XCTAssertFalse(result)
    }

    func testEncounterHasActiveFilters_locationSet_returnsTrue() {
        XCTAssertTrue(encounterHasActiveFilters(
            timeFilter: .all, location: "Cafe", tagCount: 0,
            sortOption: .dateNewest, favoritesOnly: false
        ))
    }

    func testEncounterActiveFilterCount_allActive() {
        let count = encounterActiveFilterCount(
            timeFilter: .thisWeek, location: "Office", tagCount: 2,
            sortOption: .mostPeople, favoritesOnly: true
        )
        // time(1) + location(1) + sort(1) + favorites(1) + tags(2) = 6
        XCTAssertEqual(count, 6)
    }

    // MARK: - Helpers

    private func encounterHasActiveFilters(
        timeFilter: TimeFilter, location: String?, tagCount: Int,
        sortOption: EncounterSortOption, favoritesOnly: Bool
    ) -> Bool {
        timeFilter != .all || location != nil || tagCount > 0 || sortOption != .dateNewest || favoritesOnly
    }

    private func encounterActiveFilterCount(
        timeFilter: TimeFilter, location: String?, tagCount: Int,
        sortOption: EncounterSortOption, favoritesOnly: Bool
    ) -> Int {
        var count = 0
        if timeFilter != .all { count += 1 }
        if location != nil { count += 1 }
        if sortOption != .dateNewest { count += 1 }
        if favoritesOnly { count += 1 }
        count += tagCount
        return count
    }
}
