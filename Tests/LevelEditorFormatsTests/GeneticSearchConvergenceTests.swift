import XCTest
@testable import LevelEditorFormats

final class GeneticSearchConvergenceTests: XCTestCase {
    private func fitness(_ lives: Int = 10) -> GeneticFitness {
        GeneticFitness([GeneticEvaluation(seed: 1, result: SimulationResult(outcome: .victory,
            seconds: 90, livesRemaining: lives, goldRemaining: 0, goldEarned: 0, killed: 1, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []),
            wavesStarted: 1, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])])
    }
    func testEffortAndBothStabilityWindowsAreRequiredForEveryGroup() {
        let policy = GeneticStoppingPolicy()
        var search = GeneticSearchConvergence(policy: policy, stars: [0,36])
        for stars in [0,36] {
            search.observe(stars: stars, generation: 0, battles: 750_000, fitness: fitness(), winningNiche: "a")
        }
        XCTAssertFalse(search.ready(generation: 1000))
        search.observe(stars: 0, generation: 999, battles: 250_000, fitness: fitness(), winningNiche: "a")
        XCTAssertFalse(search.ready(generation: 1000))
        search.observe(stars: 36, generation: 999, battles: 250_000, fitness: fitness(), winningNiche: "a")
        XCTAssertFalse(search.ready(generation: 999))
        XCTAssertTrue(search.ready(generation: 1000))
        search.restartExploration(generation: 1000)
        XCTAssertFalse(search.ready(generation: 1_000_000)) // Generations alone cannot fake evaluated battles.
        for stars in [0,36] {
            search.observe(stars: stars, generation: 1999, battles: 250_000, fitness: fitness(), winningNiche: "a")
        }
        XCTAssertFalse(search.ready(generation: 1999))
        XCTAssertTrue(search.ready(generation: 2000))
    }
    func testFitnessAndNewWinningCoverageResetStability() {
        var p = GeneticStoppingPolicy(); p.minimumTrainingBattles = 10; p.stabilityBattles = 5; p.stabilityGenerations = 2
        var search = GeneticSearchConvergence(policy: p, stars: [0])
        search.observe(stars: 0, generation: 0, battles: 5, fitness: fitness(), winningNiche: "a")
        search.observe(stars: 0, generation: 1, battles: 5, fitness: fitness(), winningNiche: "a")
        XCTAssertTrue(search.ready(generation: 2))
        search.observe(stars: 0, generation: 2, battles: 5, fitness: fitness(), winningNiche: "b")
        XCTAssertFalse(search.ready(generation: 4))
        search.observe(stars: 0, generation: 3, battles: 5, fitness: fitness(11), winningNiche: "a")
        XCTAssertFalse(search.ready(generation: 5))
        search.observe(stars: 0, generation: 4, battles: 5, fitness: fitness(), winningNiche: "a")
        XCTAssertTrue(search.ready(generation: 5))
    }
    func testLargeEffortFloorsAreFloorsAndNotAutomaticSuccess() throws {
        for minimum in [1_000_000, 100_000_000, 1_000_000_000] {
            var p = GeneticStoppingPolicy(); p.minimumTrainingBattles = minimum
            try p.validate()
            var search = GeneticSearchConvergence(policy: p, stars: [0])
            search.observe(stars: 0, generation: 0, battles: 1, fitness: fitness(), winningNiche: nil)
            search.observe(stars: 0, generation: 1000, battles: minimum - 2, fitness: fitness(), winningNiche: nil)
            XCTAssertFalse(search.ready(generation: 1000))
            search.observe(stars: 0, generation: 1000, battles: 1, fitness: fitness(), winningNiche: nil)
            XCTAssertTrue(search.ready(generation: 1000))
            XCTAssertTrue(try p.qualifyingSet([], samples: 64).isEmpty) // Readiness does not certify winners.
        }
    }
    func testRepeatedHeldOutPanelsNeverReuseTrainingOrEarlierAttemptSeeds() {
        let p = GeneticStoppingPolicy(), base = UInt64.max - 1
        var seen = Set((0..<3).map { base &+ UInt64($0) })
        for attempt in 0..<20 {
            let seeds = p.validationSeeds(base: base, trainingCount: 3, count: 64, attempt: attempt)
            XCTAssertEqual(Set(seeds).count, 64)
            XCTAssertTrue(seen.isDisjoint(with: seeds))
            seen.formUnion(seeds)
        }
    }
    func testQualificationRequiresCompleteReliableDistinctEvidence() throws {
        let strategy = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([]))
        let families = [UUID(),UUID(),UUID()]
        func candidate(_ id: Int, wins: Int = 58, count: Int = 64, family: UUID) -> GeneticCandidate {
            let plan = GeneticDefenseFixtures.plan([.init(slot: 0,family: family)])
            let samples = (0..<count).map { seed in
                GeneticEvaluation(placementPlan: plan, seed: UInt64(seed), result: SimulationResult(
                    outcome: seed < wins ? .victory : .defeat, seconds: 90, livesRemaining: seed < wins ? 10 : 0,
                    goldRemaining: 0, goldEarned: 0, killed: 1, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []),
                    wavesStarted: 1, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
            }
            return GeneticCandidate(id: id, generation: 0, strategy: strategy, evaluations: samples)
        }
        let p = GeneticStoppingPolicy()
        let a = candidate(0,family: families[0]), b = candidate(1,family: families[1])
        XCTAssertEqual(try p.qualifyingSet([a,b,candidate(2,family: families[2])], samples: 64).count, 3)
        XCTAssertLessThan(try p.qualifyingSet([a,b,candidate(2,wins: 57,family: families[2])], samples: 64).count, 3)
        XCTAssertLessThan(try p.qualifyingSet([a,b,candidate(2,count: 63,family: families[2])], samples: 64).count, 3)
        XCTAssertLessThan(try p.qualifyingSet([a,b,candidate(2,family: families[0])], samples: 64).count, 3)
    }

    func testFreshQualificationDoesNotEraseEarlierFailuresAndDuplicateSeedsFail() throws {
        let family = UUID(), strategy = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([]))
        let plan = GeneticDefenseFixtures.plan([.init(slot:0,family:family)])
        func panel(_ firstSeed: Int, wins: Int) -> GeneticCandidate {
            GeneticCandidate(id:1,generation:0,strategy:strategy,evaluations:(0..<10).map { i in
                GeneticEvaluation(placementPlan:plan,seed:UInt64(firstSeed+i),result:SimulationResult(
                    outcome:i < wins ? .victory : .defeat,seconds:90,livesRemaining:i < wins ? 10 : 0,
                    goldRemaining:0,goldEarned:0,killed:1,leaked:0,fatesByTypeID:[:],waveMaxProgress:[],leaksByWave:[]),
                    wavesStarted:1,waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
            })
        }
        var history = GeneticQualificationHistory(), p = GeneticStoppingPolicy(); p.solutions = 1
        try history.append([panel(0,wins:5)])
        let fresh = panel(10,wins:10)
        try history.append([fresh])
        XCTAssertEqual(try p.qualifyingSet([fresh],samples:10).count,1)
        XCTAssertEqual(try p.qualifyingSet([fresh],samples:10,history:history.candidates).count,0)
        XCTAssertEqual(history.candidates[1]?.evaluations.count,20)
        XCTAssertThrowsError(try history.append([fresh]))
        XCTAssertEqual(history.candidates[1]?.evaluations.count,20)
    }

    func testRepeatedQualificationDoesNotInventNinetyNinePercentCompletionEvenWithResourceCaps() {
        var p = GeneticProgress(runID: UUID(), startedAt: 0, timeBudget: 3600,
            trainingLimit: 1000, generationLimit: 30, qualitySearch: true)
        for (i,phase) in [GeneticProgress.Phase.search,.validation,.search,.validation,.search].enumerated() {
            let snapshot = p.update(now: Double(i+1)*10, phase: phase, completedGenerations: i+1,
                trainingEvaluations: (i+1)*10, validationEvaluations: i*64, validationTarget: (i+1)*64)
            XCTAssertEqual(snapshot.percentComplete,0)
            XCTAssertNil(snapshot.estimatedSecondsRemaining)
            XCTAssertTrue(snapshot.milestones.isEmpty)
        }
    }

    func testUnboundedProgressNeverInventsCompletionTimeOrPercentage() {
        var p = GeneticProgress(runID: UUID(), startedAt: 0, timeBudget: 0, trainingLimit: nil, generationLimit: nil)
        for (i, phase) in [GeneticProgress.Phase.search, .validation, .search].enumerated() {
            let snapshot = p.update(now: Double(i + 1) * 10_000_000, phase: phase,
                completedGenerations: 10_000, trainingEvaluations: 1_000_000_000,
                validationEvaluations: 64, validationTarget: 512)
            XCTAssertNil(snapshot.estimatedSecondsRemaining)
            XCTAssertEqual(snapshot.percentComplete, 0)
            XCTAssertTrue(snapshot.statusLine.contains("completion time unknown"))
        }
    }
}
