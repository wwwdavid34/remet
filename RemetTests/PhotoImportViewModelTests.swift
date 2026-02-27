import XCTest
import SwiftData
import UIKit
@testable import Remet

final class PhotoImportViewModelTests: XCTestCase {

    private var sut: PhotoImportViewModel!
    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        sut = PhotoImportViewModel()
        container = try! TestHelpers.makeModelContainer()
        context = container.mainContext
    }

    override func tearDown() {
        sut = nil
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a minimal 1x1 pixel UIImage for testing (no faces)
    private func makeTestImage() -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIColor.red.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    // MARK: - Single Photo Routing

    @MainActor
    func testSinglePhoto_routesToGroupReview() async {
        let image = makeTestImage()

        await sut.processPickedPhotos(
            images: [(image: image, assetId: nil)],
            modelContext: context
        )

        XCTAssertTrue(sut.showGroupReview, "Single photo should route to group review")
        XCTAssertNotNil(sut.photoGroup, "photoGroup should be set for single photo")
        XCTAssertEqual(sut.photoGroup?.photos.count, 1)
        XCTAssertEqual(sut.scannedPhotos.count, 1)
        XCTAssertFalse(sut.isProcessing)
    }

    // MARK: - Multi-Photo Routing

    @MainActor
    func testMultiplePhotos_routesToGroupReview() async {
        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil)
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        XCTAssertTrue(sut.showGroupReview, "Multiple photos should route to group review")
        XCTAssertNotNil(sut.photoGroup, "photoGroup should be set")
        XCTAssertEqual(sut.photoGroup?.photos.count, 3)
        XCTAssertEqual(sut.scannedPhotos.count, 3)
        XCTAssertFalse(sut.isProcessing)
    }

    @MainActor
    func testTwoPhotos_routesToGroupReview() async {
        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil)
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        XCTAssertTrue(sut.showGroupReview, "Two photos should route to group review")
        XCTAssertEqual(sut.photoGroup?.photos.count, 2)
    }

    // MARK: - Already Imported (Dedup)

    @MainActor
    func testAllPhotosAlreadyImported_showsError() async {
        // Pre-import a photo with known asset ID
        let assetId = "already-imported-asset"
        _ = TestHelpers.makeEncounterPhoto(assetIdentifier: assetId, in: context)
        try! context.save()

        await sut.processPickedPhotos(
            images: [(image: makeTestImage(), assetId: assetId)],
            modelContext: context
        )

        XCTAssertNotNil(sut.errorMessage, "Should show error when all photos already imported")
        XCTAssertFalse(sut.showGroupReview)
        XCTAssertFalse(sut.isProcessing)
    }

    @MainActor
    func testMixedImported_skipsAlreadyImported() async {
        // Pre-import one photo
        let importedId = "already-imported"
        _ = TestHelpers.makeEncounterPhoto(assetIdentifier: importedId, in: context)
        try! context.save()

        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: importedId),    // already imported — skipped
            (image: makeTestImage(), assetId: "new-photo-1"), // new
            (image: makeTestImage(), assetId: "new-photo-2")  // new
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        // Should have 2 photos (skipped the imported one) → group review
        XCTAssertEqual(sut.scannedPhotos.count, 2)
        XCTAssertTrue(sut.showGroupReview)
    }

    @MainActor
    func testMixedImported_singleRemaining_routesToGroupReview() async {
        // Pre-import two photos
        _ = TestHelpers.makeEncounterPhoto(assetIdentifier: "imported-1", in: context)
        _ = TestHelpers.makeEncounterPhoto(assetIdentifier: "imported-2", in: context)
        try! context.save()

        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: "imported-1"),
            (image: makeTestImage(), assetId: "imported-2"),
            (image: makeTestImage(), assetId: "new-photo")
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        // Only 1 new photo remains → still uses group review
        XCTAssertEqual(sut.scannedPhotos.count, 1)
        XCTAssertTrue(sut.showGroupReview)
        XCTAssertNotNil(sut.photoGroup)
        XCTAssertEqual(sut.photoGroup?.photos.count, 1)
    }

    // MARK: - Shared Images (nil assetId)

    @MainActor
    func testSharedImages_nilAssetId_neverSkippedAsImported() async {
        // Shared images have nil assetId — they should never be flagged as imported
        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil)
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        XCTAssertEqual(sut.scannedPhotos.count, 2, "Shared images with nil assetId should not be skipped")
        XCTAssertTrue(sut.showGroupReview)
    }

    @MainActor
    func testSharedImages_getUniqueIds() async {
        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil)
        ]

        await sut.processPickedPhotos(images: images, modelContext: context)

        let ids = sut.scannedPhotos.map(\.id)
        XCTAssertEqual(Set(ids).count, 2, "Each shared photo should get a unique ID")
    }

    // MARK: - Reset

    @MainActor
    func testReset_clearsAllState() async {
        // First process some photos to populate state
        let images: [(image: UIImage, assetId: String?)] = [
            (image: makeTestImage(), assetId: nil),
            (image: makeTestImage(), assetId: nil)
        ]
        await sut.processPickedPhotos(images: images, modelContext: context)

        // Verify state is populated
        XCTAssertTrue(sut.showGroupReview)
        XCTAssertNotNil(sut.photoGroup)

        // Reset
        sut.reset()

        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showAlreadyImportedAlert)
        XCTAssertTrue(sut.pendingImages.isEmpty)
        XCTAssertFalse(sut.showGroupReview)
        XCTAssertTrue(sut.scannedPhotos.isEmpty)
        XCTAssertNil(sut.photoGroup)
    }

    // MARK: - Empty Input

    @MainActor
    func testEmptyImages_showsError() async {
        await sut.processPickedPhotos(images: [], modelContext: context)

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.showGroupReview)
        XCTAssertFalse(sut.isProcessing)
    }
}
