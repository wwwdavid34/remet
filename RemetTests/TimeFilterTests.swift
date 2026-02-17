import XCTest
@testable import Remet

/// Tests for TimeFilter, EncounterSortOption, and PersonSortOption enums.
/// These enums drive the filtering and sorting UI across encounters and people lists.
final class TimeFilterTests: XCTestCase {

    // MARK: - TimeFilter.dateRange

    func testTimeFilter_all_returnsNil() {
        XCTAssertNil(TimeFilter.all.dateRange)
    }

    func testTimeFilter_today_startsAtStartOfDay() {
        guard let range = TimeFilter.today.dateRange else {
            return XCTFail("Expected non-nil dateRange for .today")
        }
        let expectedStart = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(range.start, expectedStart)
        XCTAssertTrue(range.end >= range.start)
    }

    func testTimeFilter_thisWeek_coversApprox7Days() {
        guard let range = TimeFilter.thisWeek.dateRange else {
            return XCTFail("Expected non-nil dateRange for .thisWeek")
        }
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        // Start should be within a few seconds of 7 days ago
        XCTAssertEqual(range.start.timeIntervalSince1970, sevenDaysAgo.timeIntervalSince1970, accuracy: 5)
        XCTAssertTrue(range.end >= range.start)
    }

    func testTimeFilter_thisMonth_coversApprox1Month() {
        guard let range = TimeFilter.thisMonth.dateRange else {
            return XCTFail("Expected non-nil dateRange for .thisMonth")
        }
        let now = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        XCTAssertEqual(range.start.timeIntervalSince1970, oneMonthAgo.timeIntervalSince1970, accuracy: 5)
    }

    func testTimeFilter_last3Months_coversApprox3Months() {
        guard let range = TimeFilter.last3Months.dateRange else {
            return XCTFail("Expected non-nil dateRange for .last3Months")
        }
        let now = Date()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now)!
        XCTAssertEqual(range.start.timeIntervalSince1970, threeMonthsAgo.timeIntervalSince1970, accuracy: 5)
    }

    func testTimeFilter_thisYear_coversApprox1Year() {
        guard let range = TimeFilter.thisYear.dateRange else {
            return XCTFail("Expected non-nil dateRange for .thisYear")
        }
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        XCTAssertEqual(range.start.timeIntervalSince1970, oneYearAgo.timeIntervalSince1970, accuracy: 5)
    }

    func testTimeFilter_caseCount() {
        XCTAssertEqual(TimeFilter.allCases.count, 6)
    }

    func testTimeFilter_nonNilCases_endIsAfterStart() {
        for filter in TimeFilter.allCases where filter != .all {
            guard let range = filter.dateRange else {
                XCTFail("\(filter) should have a non-nil dateRange")
                continue
            }
            XCTAssertTrue(range.end >= range.start, "\(filter): end should be >= start")
        }
    }

    // MARK: - EncounterSortOption

    func testEncounterSortOption_caseCount() {
        XCTAssertEqual(EncounterSortOption.allCases.count, 4)
    }

    func testEncounterSortOption_rawValues() {
        XCTAssertEqual(EncounterSortOption.dateNewest.rawValue, "Newest First")
        XCTAssertEqual(EncounterSortOption.dateOldest.rawValue, "Oldest First")
        XCTAssertEqual(EncounterSortOption.mostPeople.rawValue, "Most People")
        XCTAssertEqual(EncounterSortOption.fewestPeople.rawValue, "Fewest People")
    }

    func testEncounterSortOption_iconsNotEmpty() {
        for option in EncounterSortOption.allCases {
            XCTAssertFalse(option.icon.isEmpty, "\(option) should have a non-empty icon")
        }
    }

    // MARK: - PersonSortOption

    func testPersonSortOption_caseCount() {
        XCTAssertEqual(PersonSortOption.allCases.count, 4)
    }

    func testPersonSortOption_rawValues() {
        XCTAssertEqual(PersonSortOption.nameAZ.rawValue, "Name A-Z")
        XCTAssertEqual(PersonSortOption.nameZA.rawValue, "Name Z-A")
        XCTAssertEqual(PersonSortOption.newestFirst.rawValue, "Newest First")
        XCTAssertEqual(PersonSortOption.mostEncounters.rawValue, "Most Encounters")
    }

    func testPersonSortOption_iconsNotEmpty() {
        for option in PersonSortOption.allCases {
            XCTAssertFalse(option.icon.isEmpty, "\(option) should have a non-empty icon")
        }
    }
}
