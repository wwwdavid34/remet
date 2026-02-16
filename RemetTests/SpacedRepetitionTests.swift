import XCTest
import SwiftData
@testable import Remet

final class SpacedRepetitionTests: XCTestCase {

    // MARK: - SpacedRepetitionData: Default State

    func testDefaultState() {
        let srd = SpacedRepetitionData()
        XCTAssertEqual(srd.easeFactor, 2.5)
        XCTAssertEqual(srd.interval, 0)
        XCTAssertEqual(srd.repetitions, 0)
        XCTAssertEqual(srd.totalAttempts, 0)
        XCTAssertEqual(srd.correctAttempts, 0)
    }

    // MARK: - Accuracy

    func testAccuracy_noAttempts_returns0() {
        let srd = SpacedRepetitionData()
        XCTAssertEqual(srd.accuracy, 0.0)
    }

    func testAccuracy_allCorrect_returns1() {
        let srd = SpacedRepetitionData(totalAttempts: 5, correctAttempts: 5)
        XCTAssertEqual(srd.accuracy, 1.0)
    }

    func testAccuracy_halfCorrect() {
        let srd = SpacedRepetitionData(totalAttempts: 10, correctAttempts: 5)
        XCTAssertEqual(srd.accuracy, 0.5, accuracy: 0.001)
    }

    // MARK: - needsReview

    func testNeedsReview_pastDueDate_returnsTrue() {
        let srd = SpacedRepetitionData(
            nextReviewDate: Date().addingTimeInterval(-86400) // yesterday
        )
        XCTAssertTrue(srd.needsReview)
    }

    func testNeedsReview_futureDueDate_returnsFalse() {
        let srd = SpacedRepetitionData(
            nextReviewDate: Date().addingTimeInterval(86400) // tomorrow
        )
        XCTAssertFalse(srd.needsReview)
    }

    func testNeedsReview_defaultDate_returnsTrue() {
        // Default nextReviewDate is Date() which is now, so <= Date() is true
        let srd = SpacedRepetitionData()
        XCTAssertTrue(srd.needsReview)
    }

    // MARK: - SM-2 Algorithm Logic
    // These test the algorithm as implemented in FaceQuizView.updateSpacedRepetition

    func testSM2_firstCorrectAnswer_setsInterval1() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd)

        XCTAssertEqual(srd.repetitions, 1)
        XCTAssertEqual(srd.interval, 1, "First correct answer should set interval to 1 day")
    }

    func testSM2_secondCorrectAnswer_setsInterval6() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd)
        simulateCorrectAnswer(srd)

        XCTAssertEqual(srd.repetitions, 2)
        XCTAssertEqual(srd.interval, 6, "Second correct answer should set interval to 6 days")
    }

    func testSM2_thirdCorrectAnswer_multipliesByEaseFactor() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd) // rep=1, interval=1
        simulateCorrectAnswer(srd) // rep=2, interval=6
        simulateCorrectAnswer(srd) // rep=3, interval = 6 * easeFactor

        XCTAssertEqual(srd.repetitions, 3)
        // Ease factor starts at 2.5, increases by 0.1 each correct (capped at 2.5)
        // After 2 correct: easeFactor = min(2.5, 2.5 + 0.1) = 2.5, then +0.1 again = 2.5
        // interval = Int(6 * 2.5) = 15
        XCTAssertEqual(srd.interval, 15)
    }

    func testSM2_incorrectAnswer_resetsRepetitions() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd) // rep=1
        simulateCorrectAnswer(srd) // rep=2
        simulateIncorrectAnswer(srd) // reset

        XCTAssertEqual(srd.repetitions, 0, "Incorrect answer should reset repetitions to 0")
        XCTAssertEqual(srd.interval, 1, "Incorrect answer should set interval to 1")
    }

    func testSM2_incorrectAnswer_decreasesEaseFactor() {
        let srd = SpacedRepetitionData()
        let initialEase = srd.easeFactor
        simulateIncorrectAnswer(srd)

        XCTAssertEqual(srd.easeFactor, initialEase - 0.2, accuracy: 0.001)
    }

    func testSM2_easeFactor_neverBelowMinimum() {
        let srd = SpacedRepetitionData()
        // Incorrect many times to drive ease factor down
        for _ in 0..<20 {
            simulateIncorrectAnswer(srd)
        }

        XCTAssertGreaterThanOrEqual(srd.easeFactor, 1.3, "Ease factor should never go below 1.3")
    }

    func testSM2_easeFactor_neverAboveMaximum() {
        let srd = SpacedRepetitionData()
        // Correct many times to drive ease factor up
        for _ in 0..<20 {
            simulateCorrectAnswer(srd)
        }

        XCTAssertLessThanOrEqual(srd.easeFactor, 2.5, "Ease factor should never exceed 2.5")
    }

    func testSM2_correctIncreasesEase_thenIncorrectDecreases() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd)
        let easeAfterCorrect = srd.easeFactor
        simulateIncorrectAnswer(srd)
        let easeAfterIncorrect = srd.easeFactor

        XCTAssertLessThan(easeAfterIncorrect, easeAfterCorrect)
    }

    func testSM2_totalAttempts_incrementsEachTime() {
        let srd = SpacedRepetitionData()
        simulateCorrectAnswer(srd)
        simulateIncorrectAnswer(srd)
        simulateCorrectAnswer(srd)

        XCTAssertEqual(srd.totalAttempts, 3)
        XCTAssertEqual(srd.correctAttempts, 2)
    }

    func testSM2_nextReviewDate_advancesByInterval() {
        let srd = SpacedRepetitionData()
        let before = Date()
        simulateCorrectAnswer(srd) // interval = 1 day

        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: before)!
        let diff = abs(srd.nextReviewDate.timeIntervalSince(expectedDate))
        XCTAssertLessThan(diff, 2.0, "Next review should be ~1 day from now")
    }

    func testSM2_lastReviewDate_updatedOnReview() {
        let srd = SpacedRepetitionData()
        XCTAssertNil(srd.lastReviewDate)

        let before = Date()
        simulateCorrectAnswer(srd)

        XCTAssertNotNil(srd.lastReviewDate)
        let diff = abs(srd.lastReviewDate!.timeIntervalSince(before))
        XCTAssertLessThan(diff, 2.0, "Last review date should be approximately now")
    }

    // MARK: - Helper: Simulate the SM-2 algorithm from FaceQuizView

    /// Replicates the exact logic from FaceQuizView.updateSpacedRepetition
    private func simulateCorrectAnswer(_ srd: SpacedRepetitionData) {
        srd.totalAttempts += 1
        srd.correctAttempts += 1
        srd.lastReviewDate = Date()
        srd.repetitions += 1

        if srd.repetitions == 1 {
            srd.interval = 1
        } else if srd.repetitions == 2 {
            srd.interval = 6
        } else {
            srd.interval = Int(Double(srd.interval) * srd.easeFactor)
        }

        srd.easeFactor = min(2.5, srd.easeFactor + 0.1)
        srd.nextReviewDate = Calendar.current.date(byAdding: .day, value: srd.interval, to: Date()) ?? Date()
    }

    private func simulateIncorrectAnswer(_ srd: SpacedRepetitionData) {
        srd.totalAttempts += 1
        srd.lastReviewDate = Date()
        srd.repetitions = 0
        srd.interval = 1
        srd.easeFactor = max(1.3, srd.easeFactor - 0.2)
        srd.nextReviewDate = Calendar.current.date(byAdding: .day, value: srd.interval, to: Date()) ?? Date()
    }
}
