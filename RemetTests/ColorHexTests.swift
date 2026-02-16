import XCTest
import SwiftUI
@testable import Remet

final class ColorHexTests: XCTestCase {

    // MARK: - Color(hex:) Initializer

    func testColorHex_validHex_createsColor() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color, "Valid hex should create a color")
    }

    func testColorHex_withoutHash_createsColor() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    func testColorHex_invalidHex_returnsNil() {
        let color = Color(hex: "ZZZZZZ")
        XCTAssertNil(color)
    }

    func testColorHex_emptyString_returnsNil() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testColorHex_whitespace_handled() {
        let color = Color(hex: "  #007AFF  ")
        XCTAssertNotNil(color)
    }

    // MARK: - TagColor Hex Values

    func testTagColor_allCasesHaveValidHex() {
        for tagColor in TagColor.allCases {
            let color = Color(hex: tagColor.hex)
            XCTAssertNotNil(color, "\(tagColor.rawValue) should have valid hex: \(tagColor.hex)")
        }
    }

    func testTagColor_hexStartsWithHash() {
        for tagColor in TagColor.allCases {
            XCTAssertTrue(tagColor.hex.hasPrefix("#"), "\(tagColor.rawValue) hex should start with #")
        }
    }

    func testTagColor_hexIs7Characters() {
        for tagColor in TagColor.allCases {
            XCTAssertEqual(tagColor.hex.count, 7, "\(tagColor.rawValue) hex should be 7 chars (#RRGGBB)")
        }
    }

    // MARK: - PresetTag Suggested Colors

    func testPresetTag_allCasesHaveSuggestedColor() {
        for preset in PresetTag.allCases {
            // Just verify no crash and the suggested color is a valid TagColor
            let _ = preset.suggestedColor
        }
    }
}
