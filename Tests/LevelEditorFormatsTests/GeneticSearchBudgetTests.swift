import XCTest
@testable import LevelEditorFormats

final class GeneticSearchBudgetTests: XCTestCase {
    func testDefaultSearchContinuesBeyondBothFormerCeilings() throws {
        let options = GeneticStudyOptions()
        try options.validate(groups: 1)
        let budget = GeneticSearchBudget(options: options, startedAt: 0, validationReservation: 512)
        XCTAssertNil(budget.generationLimit)
        XCTAssertNil(budget.trainingLimit)
        XCTAssertNil(budget.evaluationLimit)
        // The former ceilings stopped the actual run after about fourteen minutes.
        XCTAssertNil(budget.searchStopReason(now: 836, generations: 300, completed: 43_140))
        XCTAssertNil(budget.searchStopReason(now: 1800, generations: 1000, completed: 150_000))
        XCTAssertNil(budget.trainingStopReason(now: 1800, completed: 150_000, pending: 96))
        XCTAssertNil(budget.searchStopReason(now: 1_000_000_000, generations: 9_000_000, completed: 1_000_000_000))
        XCTAssertNil(budget.deadline)
    }

    func testWallTimeIsOnlyAnExplicitResourceGuardrail() {
        var options = GeneticStudyOptions(); options.hours = 8
        let budget = GeneticSearchBudget(options: options, startedAt: 0, validationReservation: 512)
        XCTAssertNil(budget.searchStopReason(now: 24_479, generations: 9000, completed: 1_000_000))
        XCTAssertEqual(budget.searchStopReason(now: 24_480, generations: 9000, completed: 1_000_000), "time-budget")
        XCTAssertEqual(budget.deadline, 28_800)
    }

    func testExplicitCeilingsAndWholeTrainingPanelsRemainEnforced() throws {
        var options = GeneticStudyOptions()
        options.generations = 300; options.maxEvaluations = 50_000
        try options.validate(groups: 1)
        let budget = GeneticSearchBudget(options: options, startedAt: 0, validationReservation: 512)
        XCTAssertEqual(budget.trainingLimit, 49_488)
        XCTAssertNil(budget.searchStopReason(now: 836, generations: 299, completed: 43_140))
        XCTAssertEqual(budget.searchStopReason(now: 836, generations: 300, completed: 43_140), "generation-limit")
        XCTAssertNil(budget.trainingStopReason(now: 836, completed: 49_479, pending: 6))
        XCTAssertEqual(budget.trainingStopReason(now: 836, completed: 49_482, pending: 6), "evaluation-budget")
    }

    func testOptionalCeilingsAreIndependentAndInvalidLimitsFail() throws {
        var options = GeneticStudyOptions()
        options.generations = 1
        var budget = GeneticSearchBudget(options: options, startedAt: 0, validationReservation: 512)
        XCTAssertNil(budget.trainingLimit)
        XCTAssertEqual(budget.searchStopReason(now: 1, generations: 1, completed: 192), "generation-limit")
        options.generations = 0; options.maxEvaluations = 50_000
        budget = GeneticSearchBudget(options: options, startedAt: 0, validationReservation: 512)
        XCTAssertNil(budget.generationLimit)
        XCTAssertEqual(budget.searchStopReason(now: 1, generations: 1000, completed: 49_488), "evaluation-budget")
        options.maxEvaluations = 1
        XCTAssertThrowsError(try options.validate(groups: 1))
        options.maxEvaluations = -1
        XCTAssertThrowsError(try options.validate(groups: 1))
        options.maxEvaluations = 0; options.generations = -1
        XCTAssertThrowsError(try options.validate(groups: 1))
        options.generations = 0; options.hours = -1
        XCTAssertThrowsError(try options.validate(groups: 1))
    }

    func testEmptyGenerationsRequestFreshExplorationUntilNewCandidatesArrive() {
        var recovery = GeneticSearchRecovery()
        let budget = GeneticSearchBudget(options: GeneticStudyOptions(), startedAt: 0, validationReservation: 512)
        XCTAssertFalse(recovery.needsFreshGeneration)
        for generation in 1...5 {
            recovery.completedGeneration(newEvaluations: 0)
            XCTAssertTrue(recovery.needsFreshGeneration)
            XCTAssertNil(budget.searchStopReason(now: 100, generations: generation, completed: 192))
        }
        recovery.completedGeneration(newEvaluations: 3)
        XCTAssertFalse(recovery.needsFreshGeneration)
    }
}
