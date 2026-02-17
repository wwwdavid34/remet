import XCTest
@testable import Remet

/// Tests for the occasion string construction logic.
/// Mirrors the logic in QuickCaptureView.saveEncounter that builds
/// the encounter occasion from user context or auto-generates from person names.
final class OccasionBuildingTests: XCTestCase {

    /// Replicates the exact logic from QuickCaptureView.saveEncounter
    private func buildOccasion(context: String?, names: [String]) -> String? {
        if let context, !context.isEmpty {
            return context
        } else {
            if names.isEmpty {
                return nil
            } else if names.count == 1 {
                return "Met \(names[0])"
            } else {
                return "Met \(names.dropLast().joined(separator: ", ")) & \(names.last!)"
            }
        }
    }

    // MARK: - User-Provided Context

    func testOccasion_userProvidedContext_usedDirectly() {
        XCTAssertEqual(buildOccasion(context: "Conference", names: ["Alice"]), "Conference")
    }

    func testOccasion_userProvidedContext_overridesAutoGen() {
        XCTAssertEqual(buildOccasion(context: "Team Dinner", names: ["Alice", "Bob"]), "Team Dinner")
    }

    func testOccasion_emptyContext_fallsToAutoGen() {
        XCTAssertEqual(buildOccasion(context: "", names: ["Alice"]), "Met Alice")
    }

    func testOccasion_nilContext_fallsToAutoGen() {
        XCTAssertEqual(buildOccasion(context: nil, names: ["Alice"]), "Met Alice")
    }

    // MARK: - Auto-Generated from Names

    func testOccasion_zeroNames_returnsNil() {
        XCTAssertNil(buildOccasion(context: nil, names: []))
    }

    func testOccasion_oneName_metPrefix() {
        XCTAssertEqual(buildOccasion(context: nil, names: ["Alice"]), "Met Alice")
    }

    func testOccasion_twoNames_ampersandJoin() {
        XCTAssertEqual(buildOccasion(context: nil, names: ["Alice", "Bob"]), "Met Alice & Bob")
    }

    func testOccasion_threeNames_commaAndAmpersand() {
        XCTAssertEqual(
            buildOccasion(context: nil, names: ["Alice", "Bob", "Carol"]),
            "Met Alice, Bob & Carol"
        )
    }

    func testOccasion_fourNames_commaAndAmpersand() {
        XCTAssertEqual(
            buildOccasion(context: nil, names: ["Alice", "Bob", "Carol", "Dave"]),
            "Met Alice, Bob, Carol & Dave"
        )
    }
}
