import XCTest
@testable import Remet

final class QuizSessionStatsTests: XCTestCase {

    // MARK: - Accuracy

    func testAccuracy_noAttempts_returns0() {
        let stats = QuizSessionStats()
        XCTAssertEqual(stats.accuracy, 0.0)
    }

    func testAccuracy_allCorrect_returns1() {
        var stats = QuizSessionStats()
        stats.totalAttempts = 10
        stats.correctAttempts = 10
        XCTAssertEqual(stats.accuracy, 1.0)
    }

    func testAccuracy_noneCorrect_returns0() {
        var stats = QuizSessionStats()
        stats.totalAttempts = 5
        stats.correctAttempts = 0
        XCTAssertEqual(stats.accuracy, 0.0)
    }

    func testAccuracy_halfCorrect_returns50Percent() {
        var stats = QuizSessionStats()
        stats.totalAttempts = 8
        stats.correctAttempts = 4
        XCTAssertEqual(stats.accuracy, 0.5, accuracy: 0.001)
    }

    func testAccuracy_singleCorrectAttempt() {
        var stats = QuizSessionStats()
        stats.totalAttempts = 1
        stats.correctAttempts = 1
        XCTAssertEqual(stats.accuracy, 1.0)
    }

    func testAccuracy_singleIncorrectAttempt() {
        var stats = QuizSessionStats()
        stats.totalAttempts = 1
        stats.correctAttempts = 0
        XCTAssertEqual(stats.accuracy, 0.0)
    }

    // MARK: - Default State

    func testDefaultState_isZero() {
        let stats = QuizSessionStats()
        XCTAssertEqual(stats.totalAttempts, 0)
        XCTAssertEqual(stats.correctAttempts, 0)
    }
}
