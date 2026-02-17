import XCTest
import SwiftData
@testable import Remet

/// Tests for PhotoStorageQuality enum, AppSettings default lists, Tag.usageCount,
/// and PresetTag.suggestedColor.
final class AppSettingsTests: XCTestCase {

    // MARK: - PhotoStorageQuality: Resolution

    func testPhotoQuality_high_resolution() {
        XCTAssertEqual(PhotoStorageQuality.high.resolution, 1024)
    }

    func testPhotoQuality_balanced_resolution() {
        XCTAssertEqual(PhotoStorageQuality.balanced.resolution, 768)
    }

    func testPhotoQuality_compact_resolution() {
        XCTAssertEqual(PhotoStorageQuality.compact.resolution, 512)
    }

    // MARK: - PhotoStorageQuality: JPEG Quality

    func testPhotoQuality_high_jpegQuality() {
        XCTAssertEqual(PhotoStorageQuality.high.jpegQuality, 0.8)
    }

    func testPhotoQuality_balanced_jpegQuality() {
        XCTAssertEqual(PhotoStorageQuality.balanced.jpegQuality, 0.6)
    }

    func testPhotoQuality_compact_jpegQuality() {
        XCTAssertEqual(PhotoStorageQuality.compact.jpegQuality, 0.5)
    }

    // MARK: - PhotoStorageQuality: Estimated Size

    func testPhotoQuality_high_estimatedSize() {
        XCTAssertEqual(PhotoStorageQuality.high.estimatedSizePerPhoto, 200)
    }

    func testPhotoQuality_balanced_estimatedSize() {
        XCTAssertEqual(PhotoStorageQuality.balanced.estimatedSizePerPhoto, 80)
    }

    func testPhotoQuality_compact_estimatedSize() {
        XCTAssertEqual(PhotoStorageQuality.compact.estimatedSizePerPhoto, 40)
    }

    func testPhotoQuality_caseCount() {
        XCTAssertEqual(PhotoStorageQuality.allCases.count, 3)
    }

    // MARK: - Default Lists

    func testDefaultRelationships_count() {
        XCTAssertEqual(AppSettings.defaultRelationships.count, 6)
    }

    func testDefaultRelationships_firstIsFamily() {
        XCTAssertEqual(AppSettings.defaultRelationships.first, "Family")
    }

    func testDefaultRelationships_containsExpected() {
        let expected = ["Family", "Friend", "Coworker", "Acquaintance", "Client", "Mentor"]
        XCTAssertEqual(AppSettings.defaultRelationships, expected)
    }

    func testDefaultContexts_count() {
        XCTAssertEqual(AppSettings.defaultContexts.count, 7)
    }

    func testDefaultContexts_firstIsWork() {
        XCTAssertEqual(AppSettings.defaultContexts.first, "Work")
    }

    func testDefaultContexts_containsExpected() {
        let expected = ["Work", "School", "Gym", "Church", "Neighborhood", "Online", "Event"]
        XCTAssertEqual(AppSettings.defaultContexts, expected)
    }

    // MARK: - Tag.usageCount

    @MainActor
    func testTagUsageCount_noUsage_returnsZero() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let tag = TestHelpers.makeTag(name: "Test", in: ctx)
        try ctx.save()
        XCTAssertEqual(tag.usageCount, 0)
    }

    @MainActor
    func testTagUsageCount_peopleAndEncounters_sumsCorrectly() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext

        let tag = TestHelpers.makeTag(name: "Work", in: ctx)

        let person1 = TestHelpers.makePerson(name: "Alice", in: ctx)
        let person2 = TestHelpers.makePerson(name: "Bob", in: ctx)
        person1.tags = [tag]
        person2.tags = [tag]

        let encounter = TestHelpers.makeEncounter(occasion: "Meeting", in: ctx)
        encounter.tags = [tag]

        try ctx.save()
        XCTAssertEqual(tag.usageCount, 3) // 2 people + 1 encounter
    }

    // MARK: - PresetTag.suggestedColor

    func testPresetTag_work_blue() {
        XCTAssertEqual(PresetTag.work.suggestedColor, .blue)
    }

    func testPresetTag_family_red() {
        XCTAssertEqual(PresetTag.family.suggestedColor, .red)
    }

    func testPresetTag_friends_green() {
        XCTAssertEqual(PresetTag.friends.suggestedColor, .green)
    }

    func testPresetTag_allCasesHaveSuggestedColor() {
        for preset in PresetTag.allCases {
            // Just verify it doesn't crash and returns a valid TagColor
            XCTAssertTrue(TagColor.allCases.contains(preset.suggestedColor), "\(preset) should have a valid TagColor")
        }
    }
}
