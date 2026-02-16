import XCTest
@testable import Remet

final class FaceEmbeddingServiceTests: XCTestCase {

    // MARK: - Singleton

    func testShared_returnsSameInstance() {
        let a = FaceEmbeddingService.shared
        let b = FaceEmbeddingService.shared
        XCTAssertTrue(a === b, "shared should always return the same instance")
    }

    func testPreload_multipleCallsAreSafe() {
        // Calling preload multiple times should be idempotent and not crash
        FaceEmbeddingService.shared.preload()
        FaceEmbeddingService.shared.preload()
        FaceEmbeddingService.shared.preload()
    }
}
