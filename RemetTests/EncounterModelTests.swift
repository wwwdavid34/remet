import XCTest
import SwiftData
@testable import Remet

/// Tests for Encounter, EncounterPhoto, and FaceBoundingBox model computed properties.
/// Covers commits: f242158 (favorites), d2e32e6 (GPS extraction), 9818842 (face boxes).
final class EncounterModelTests: XCTestCase {

    // MARK: - Encounter.hasCoordinates

    @MainActor
    func testHasCoordinates_bothNil_returnsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertFalse(encounter.hasCoordinates)
    }

    @MainActor
    func testHasCoordinates_latOnly_returnsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(latitude: 37.78, in: ctx)
        try ctx.save()
        XCTAssertFalse(encounter.hasCoordinates)
    }

    @MainActor
    func testHasCoordinates_bothSet_returnsTrue() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(latitude: 37.78, longitude: -122.41, in: ctx)
        try ctx.save()
        XCTAssertTrue(encounter.hasCoordinates)
    }

    // MARK: - Encounter.mapsURL

    @MainActor
    func testMapsURL_noCoordinates_returnsNil() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertNil(encounter.mapsURL)
    }

    @MainActor
    func testMapsURL_validCoordinates_returnsCorrectURL() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(latitude: 37.78, longitude: -122.41, in: ctx)
        try ctx.save()

        let url = encounter.mapsURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("maps.apple.com"))
        XCTAssertTrue(url!.absoluteString.contains("ll=37.78,-122.41"))
    }

    // MARK: - Encounter.displayImageData

    @MainActor
    func testDisplayImageData_noPhotosNoData_returnsNil() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertNil(encounter.displayImageData)
    }

    @MainActor
    func testDisplayImageData_noPhotos_returnsImageData() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let testData = Data([0x01, 0x02])
        encounter.imageData = testData
        try ctx.save()
        XCTAssertEqual(encounter.displayImageData, testData)
    }

    @MainActor
    func testDisplayImageData_noPhotosNoImageData_returnsThumbnail() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let thumbData = Data([0xAA, 0xBB])
        encounter.thumbnailData = thumbData
        try ctx.save()
        XCTAssertEqual(encounter.displayImageData, thumbData)
    }

    @MainActor
    func testDisplayImageData_withPhotos_returnsFirstPhotoData() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        let photoData = Data([0xCC, 0xDD])
        let photo = TestHelpers.makeEncounterPhoto(imageData: photoData, in: ctx)
        photo.encounter = encounter
        encounter.imageData = Data([0x01]) // should be ignored
        try ctx.save()
        XCTAssertEqual(encounter.displayImageData, photoData)
    }

    // MARK: - Encounter.totalFaceCount

    @MainActor
    func testTotalFaceCount_noPhotosNoBoxes_returnsZero() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertEqual(encounter.totalFaceCount, 0)
    }

    @MainActor
    func testTotalFaceCount_noPhotos_legacyBoxes_returnsCount() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        encounter.faceBoundingBoxes = [
            FaceBoundingBox(rect: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)),
            FaceBoundingBox(rect: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3))
        ]
        try ctx.save()
        XCTAssertEqual(encounter.totalFaceCount, 2)
    }

    @MainActor
    func testTotalFaceCount_withPhotos_sumsPhotoBoxes() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)

        let photo1 = TestHelpers.makeEncounterPhoto(in: ctx)
        photo1.encounter = encounter
        photo1.faceBoundingBoxes = [
            FaceBoundingBox(rect: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        ]

        let photo2 = TestHelpers.makeEncounterPhoto(in: ctx)
        photo2.encounter = encounter
        photo2.faceBoundingBoxes = [
            FaceBoundingBox(rect: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)),
            FaceBoundingBox(rect: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3)),
            FaceBoundingBox(rect: CGRect(x: 0.7, y: 0.7, width: 0.1, height: 0.1))
        ]

        try ctx.save()
        XCTAssertEqual(encounter.totalFaceCount, 4)
    }

    // MARK: - Encounter.sortedPhotos

    @MainActor
    func testSortedPhotos_empty_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertTrue(encounter.sortedPhotos.isEmpty)
    }

    @MainActor
    func testSortedPhotos_outOfOrder_sortedAscending() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)

        let older = Date().addingTimeInterval(-3600)
        let newer = Date()

        let photo1 = TestHelpers.makeEncounterPhoto(date: newer, in: ctx)
        photo1.encounter = encounter
        let photo2 = TestHelpers.makeEncounterPhoto(date: older, in: ctx)
        photo2.encounter = encounter

        try ctx.save()
        let sorted = encounter.sortedPhotos
        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted.first?.id, photo2.id) // older first
        XCTAssertEqual(sorted.last?.id, photo1.id) // newer last
    }

    // MARK: - Encounter.faceBoundingBoxes JSON round-trip

    @MainActor
    func testFaceBoundingBoxes_nilData_returnsEmpty() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertTrue(encounter.faceBoundingBoxes.isEmpty)
    }

    @MainActor
    func testFaceBoundingBoxes_roundTrip_preservesData() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)

        let personId = UUID()
        let boxes = [
            FaceBoundingBox(rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), personId: personId, personName: "Alice", confidence: 0.95, isAutoAccepted: true)
        ]
        encounter.faceBoundingBoxes = boxes
        try ctx.save()

        let decoded = encounter.faceBoundingBoxes
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].personId, personId)
        XCTAssertEqual(decoded[0].personName, "Alice")
        XCTAssertEqual(decoded[0].confidence, 0.95)
        XCTAssertTrue(decoded[0].isAutoAccepted)
    }

    // MARK: - Encounter.isFavorite

    @MainActor
    func testIsFavorite_defaultsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(in: ctx)
        try ctx.save()
        XCTAssertFalse(encounter.isFavorite)
    }

    @MainActor
    func testIsFavorite_setTrue_persists() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let encounter = TestHelpers.makeEncounter(isFavorite: true, in: ctx)
        try ctx.save()
        XCTAssertTrue(encounter.isFavorite)
    }

    // MARK: - EncounterPhoto.hasCoordinates

    @MainActor
    func testPhoto_hasCoordinates_bothNil_returnsFalse() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let photo = TestHelpers.makeEncounterPhoto(in: ctx)
        try ctx.save()
        XCTAssertFalse(photo.hasCoordinates)
    }

    @MainActor
    func testPhoto_hasCoordinates_bothSet_returnsTrue() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let photo = TestHelpers.makeEncounterPhoto(latitude: -33.87, longitude: 151.21, in: ctx)
        try ctx.save()
        XCTAssertTrue(photo.hasCoordinates)
    }

    // MARK: - EncounterPhoto.faceBoundingBoxes JSON

    @MainActor
    func testPhoto_faceBoundingBoxes_roundTrip() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let photo = TestHelpers.makeEncounterPhoto(in: ctx)
        photo.faceBoundingBoxes = [
            FaceBoundingBox(rect: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3))
        ]
        try ctx.save()
        XCTAssertEqual(photo.faceBoundingBoxes.count, 1)
    }

    // MARK: - EncounterPhoto.assetIdentifier

    @MainActor
    func testPhoto_assetIdentifier_storedAndRetrieved() throws {
        let container = try TestHelpers.makeModelContainer()
        let ctx = container.mainContext
        let photo = TestHelpers.makeEncounterPhoto(assetIdentifier: "ABC-123", in: ctx)
        try ctx.save()
        XCTAssertEqual(photo.assetIdentifier, "ABC-123")
    }

    // MARK: - FaceBoundingBox (pure struct)

    func testFaceBoundingBox_rect_matchesInit() {
        let box = FaceBoundingBox(rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        XCTAssertEqual(box.rect.origin.x, 0.1, accuracy: 0.001)
        XCTAssertEqual(box.rect.origin.y, 0.2, accuracy: 0.001)
        XCTAssertEqual(box.rect.size.width, 0.3, accuracy: 0.001)
        XCTAssertEqual(box.rect.size.height, 0.4, accuracy: 0.001)
    }

    func testFaceBoundingBox_defaults() {
        let box = FaceBoundingBox(rect: .zero)
        XCTAssertNil(box.personId)
        XCTAssertNil(box.personName)
        XCTAssertNil(box.confidence)
        XCTAssertFalse(box.isAutoAccepted)
    }

    func testFaceBoundingBox_codableRoundTrip() throws {
        let original = FaceBoundingBox(
            rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            personId: UUID(),
            personName: "Test",
            confidence: 0.9,
            isAutoAccepted: true
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([FaceBoundingBox].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        let box = decoded[0]
        XCTAssertEqual(box.id, original.id)
        XCTAssertEqual(box.x, original.x)
        XCTAssertEqual(box.y, original.y)
        XCTAssertEqual(box.width, original.width)
        XCTAssertEqual(box.height, original.height)
        XCTAssertEqual(box.personId, original.personId)
        XCTAssertEqual(box.personName, original.personName)
        XCTAssertEqual(box.confidence, original.confidence)
        XCTAssertEqual(box.isAutoAccepted, original.isAutoAccepted)
    }
}
