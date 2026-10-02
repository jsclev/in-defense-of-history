import XCTest
@testable import LevelEditorFormats

final class GeneticProgressTests: XCTestCase {
    func testDefaultTimeBudgetIgnoresFormerGenerationAndBattleCeilings() throws {
        var progress = GeneticProgress(runID: UUID(), startedAt: 0, timeBudget: 28_800,
                                       trainingLimit: nil, generationLimit: nil)
        let snapshot = progress.update(now: 1800, phase: .search, completedGenerations: 1000,
            trainingEvaluations: 150_000, validationEvaluations: 0, validationTarget: 512)
        XCTAssertEqual(snapshot.percentComplete, 6.25, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.estimatedSecondsRemaining), 22_680 + 512.0 / (150_000.0 / 1800), accuracy: 0.0001)
        XCTAssertTrue(snapshot.milestones.isEmpty)
    }

    private func tracker(hours: Double = 8, evaluations: Int = 49_488, generations: Int = 300) -> GeneticProgress {
        GeneticProgress(runID: UUID(), startedAt: 100, timeBudget: hours * 3600,
                        trainingLimit: evaluations, generationLimit: generations)
    }

    func testTimeBoundRunRecordsTwentyPercentWithElapsedTime() throws {
        var progress = tracker()
        let snapshot = progress.update(now: 100 + 5_760, phase: .search, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 0, validationTarget: 512)
        XCTAssertEqual(snapshot.percentComplete, 20, accuracy: 0.0001)
        XCTAssertEqual(snapshot.milestones.map(\.percent), [10, 20])
        XCTAssertEqual(snapshot.milestones.last?.elapsedSeconds, 5_760)
        XCTAssertTrue(snapshot.statusLine.contains("elapsed 1h 36m 0s"))
        XCTAssertLessThanOrEqual(try XCTUnwrap(snapshot.estimatedSecondsRemaining), 8 * 3600 - 5_760)
    }

    func testGenerationLimitCanFinishSearchWellBeforeEvaluationCeiling() throws {
        var progress = tracker(generations: 4)
        let snapshot = progress.update(now: 160, phase: .search, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 0, validationTarget: 20)
        XCTAssertEqual(snapshot.percentComplete, 21.25, accuracy: 0.0001)
        XCTAssertEqual(snapshot.milestones.map(\.percent), [10, 20])
        XCTAssertEqual(try XCTUnwrap(snapshot.estimatedSecondsRemaining), 192, accuracy: 0.0001)
    }

    func testEvaluationLimitAndWarmup() throws {
        var progress = tracker(evaluations: 100)
        let initial = progress.update(now: 100, phase: .search, completedGenerations: 0,
            trainingEvaluations: 0, validationEvaluations: 0, validationTarget: 10)
        XCTAssertEqual(initial.percentComplete, 0)
        XCTAssertNil(initial.estimatedSecondsRemaining)
        let snapshot = progress.update(now: 120, phase: .search, completedGenerations: 0,
            trainingEvaluations: 50, validationEvaluations: 0, validationTarget: 10)
        XCTAssertEqual(snapshot.percentComplete, 42.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.estimatedSecondsRemaining), 24, accuracy: 0.0001)
    }

    func testValidationAndSavingCannotReportCompletion() throws {
        var progress = tracker()
        let start = progress.update(now: 160, phase: .validation, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 0, validationTarget: 100)
        XCTAssertEqual(start.percentComplete, 85)
        let half = progress.update(now: 190, phase: .validation, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 50, validationTarget: 100)
        XCTAssertEqual(half.percentComplete, 92, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(half.estimatedSecondsRemaining), 30, accuracy: 0.0001)
        let saving = progress.update(now: 220, phase: .saving, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 100, validationTarget: 100)
        XCTAssertEqual(saving.percentComplete, 99)
        XCTAssertNil(saving.estimatedSecondsRemaining)
        let recording = progress.update(now: 221, phase: .recording, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 100, validationTarget: 100)
        XCTAssertEqual(recording.percentComplete, 99)
        XCTAssertTrue(recording.statusLine.contains("recording retained solutions"))
        XCTAssertEqual(recording.trainingEvaluations + recording.validationEvaluations, 200)
        let completed = progress.update(now: 223, phase: .completed, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 100, validationTarget: 100)
        XCTAssertEqual(completed.percentComplete, 100)
        XCTAssertEqual(completed.milestones.last?.percent, 100)
        XCTAssertEqual(completed.milestones.last?.elapsedSeconds, 123)
        XCTAssertEqual(try JSONDecoder().decode(GeneticProgress.Snapshot.self, from: JSONEncoder().encode(completed)), completed)
        XCTAssertEqual(progress.update(now: 999, phase: .completed, completedGenerations: 1,
            trainingEvaluations: 100, validationEvaluations: 100, validationTarget: 100), completed)
    }

    func testExpiredBudgetStillReservesPublicationAndZeroFinalistsIsFinite() throws {
        var progress = tracker(hours: 1)
        let search = progress.update(now: 7_300, phase: .search, completedGenerations: 1,
            trainingEvaluations: 20, validationEvaluations: 0, validationTarget: 100)
        XCTAssertEqual(search.percentComplete, 85)
        let validation = progress.update(now: 7_301, phase: .validation, completedGenerations: 1,
            trainingEvaluations: 20, validationEvaluations: 0, validationTarget: 0)
        XCTAssertEqual(validation.percentComplete, 99)
        XCTAssertEqual(validation.estimatedSecondsRemaining, 0)
        XCTAssertLessThan(validation.percentComplete, 100)
    }

    func testMonotonicProgressAndFailureKeepsLastPercent() throws {
        var progress = tracker(generations: 4)
        let first = progress.update(now: 160, phase: .search, completedGenerations: 1,
            trainingEvaluations: 20, validationEvaluations: 0, validationTarget: 10)
        let repeated = progress.update(now: 150, phase: .search, completedGenerations: 0,
            trainingEvaluations: 10, validationEvaluations: 0, validationTarget: 10)
        XCTAssertEqual(repeated.percentComplete, first.percentComplete)
        XCTAssertEqual(repeated.elapsedSeconds, first.elapsedSeconds)
        XCTAssertEqual(repeated.milestones, first.milestones)
        let failed = progress.update(now: 180, phase: .failed, completedGenerations: 1,
            trainingEvaluations: 20, validationEvaluations: 0, validationTarget: 10)
        XCTAssertEqual(failed.percentComplete, first.percentComplete)
        XCTAssertNil(failed.estimatedSecondsRemaining)
        XCTAssertFalse(failed.milestones.contains { $0.percent == 100 })
    }
}
