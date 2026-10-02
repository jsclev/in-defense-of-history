import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticSearchCoverageTests: XCTestCase {
    func testSavedTrainingArchiveSelectsUniqueNichesWithoutRunningBattles() throws {
        guard let path = ProcessInfo.processInfo.environment["TD_GA_ARCHIVE_AUDIT_DATABASE"] else {
            throw XCTSkip("Set TD_GA_ARCHIVE_AUDIT_DATABASE for a read-only finalist audit")
        }
        let db = try SimulatorDatabase.open(URL(fileURLWithPath: path), readOnly: true)
        defer { db.close() }
        let dao = try GeneticStudyDAO(db: db), run = try dao.runID()
        let options = try dao.options(runID: run)
        let started = ProcessInfo.processInfo.systemUptime
        let candidates = try dao.bestTrainingCandidates(runID: run, seeds: dao.seeds(runID: run, panel: .training), limit: Int.max)
        let readSeconds = ProcessInfo.processInfo.systemUptime - started
        let finalists = GeneticBreedingDiversity.select(candidates, limit: options.finalists,
            distinctMetaSelections: true, creativeFinalists: true)
        XCTAssertEqual(finalists.first?.id, GeneticCandidate.ranked(candidates).first?.id)
        XCTAssertEqual(Set(finalists.compactMap { $0.behaviorDescriptor?.niche }).count, finalists.count)
        XCTAssertLessThanOrEqual(finalists.count, options.finalists)
        print("ARCHIVE_FINALISTS candidates=\(candidates.count) selected=\(finalists.map(\.id)) read_seconds=\(readSeconds)")
    }
    private func setup() throws -> (AuthoredDatabaseFixture, AuthoredMoneyStudy) {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        return try (fixture, AuthoredMoneyStudy(db: fixture.db,
            levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))))
    }
    func testRecordedUpgradeRestoreKeepsTheFactorysExactValidation() throws {
        let (fixture, study) = try setup(); _ = fixture
        let catalog = study.battle.playerUpgrades.loadout.catalog
        let factory = try MetaUpgradesFactory(catalog: catalog)
        for original in factory.progressions.prefix(256) {
            XCTAssertEqual(try MetaUpgradesFactory.restore(original.upgrades, catalog: catalog), original)
        }
        XCTAssertThrowsError(try MetaUpgradesFactory.restore([.rangeEstimation, .rangeEstimation], catalog: catalog))
        XCTAssertThrowsError(try MetaUpgradesFactory.restore([.twoGoodVolleys], catalog: catalog))
    }
    private func candidate(_ id: Int, family: UUID, lives: Int = 10) throws -> GeneticCandidate {
        let profile = GeneticDefenseFixtures.plan([.init(slot: 0, family: family)])
        let result = SimulationResult(outcome: .victory, seconds: 100, livesRemaining: lives,
            goldRemaining: 0, goldEarned: 100, killed: 1, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: [])
        return GeneticCandidate(id: id, generation: id,
            strategy: .init(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([])),
            evaluations: [.init(placementPlan: profile, seed: 1, result: result, wavesStarted: 10,
                waveEconomy: [], reinforcementDeployments: [], waveCalls: [])])
    }

    func testEveryCandidateRemainsEligibleAndNicheChampionsActuallyReproduce() throws {
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        var population = try GeneticMetaPopulation(selections: [progression], population: 4, minimumCandidates: 2)
        for id in 0..<20 {
            let family = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!
            try population.record(candidate(id, family: family, lives: id == 0 ? 20 : 10))
        }
        let selection = try XCTUnwrap(population.activeSelections.first)
        XCTAssertEqual(selection.archive.count, 4)
        XCTAssertEqual(selection.candidates.count, 20)
        XCTAssertEqual(selection.behaviorChampions.count, 20)
        let finalists = population.finalists(limit: 20, distinctSelections: false)
        XCTAssertEqual(Set(finalists.map(\.id)), Set(0..<20), "Bounded parent seats must never gate validation")
        var bred: Set<Int> = []
        for _ in 0..<10 {
            bred.formUnion(population.breedingParents(key: selection.key, count: 6).map(\.id))
        }
        XCTAssertEqual(bred, Set(0..<20), "A saved champion needs real offspring, even outside the working pool")
        XCTAssertEqual(population.best?.id, 0)
    }

    func testSmallTrainingPanelDoesNotExcludeEveryImperfectAlternativeFromValidation() throws {
        var pool: [GeneticCandidate] = []
        let common = UUID()
        for id in 0..<8 {
            let original = try candidate(id, family: id == 7 ? UUID() : common, lives: id == 0 ? 20 : 10)
            var samples = (0..<3).map { seed -> GeneticEvaluation in
                let e = original.evaluations[0]
                return .init(placementPlan: e.placementPlan, seed: UInt64(seed), result: e.result,
                    wavesStarted: 10, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
            }
            if id == 7 {
                var result = samples[2].result; result.outcome = .defeat; result.livesRemaining = 0
                samples[2] = .init(placementPlan: samples[2].placementPlan, seed: 2, result: result,
                    wavesStarted: 10, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
            }
            pool.append(.init(id: id, generation: 0, strategy: original.strategy, evaluations: samples))
        }
        let finalists = GeneticBreedingDiversity.select(pool, limit: 4, creativeFinalists: true)
        XCTAssertEqual(finalists.first?.id, 0)
        XCTAssertTrue(finalists.contains { $0.id == 7 })
        XCTAssertEqual(finalists.count, 2, "A cap of four must not spend two panels on the identical observed baseline")
        XCTAssertEqual(pool[7].fitness.winRate, 2.0 / 3, "Exploration must not rewrite reliability evidence")
    }

    func testMetaCoverageCannotValidateTheSameNicheAgainThroughAnotherRepresentative() throws {
        let baseline = try candidate(0, family: UUID(), lives: 20)
        let local = try candidate(1, family: UUID(), lives: 15)
        let alternate = GeneticCandidate(id: 2, generation: 0,
            strategy: .init(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([.rangeEstimation])),
            evaluations: local.evaluations)
        let finalists = GeneticBreedingDiversity.select([baseline, local, alternate], limit: 6,
            distinctMetaSelections: true, creativeFinalists: true)
        XCTAssertEqual(finalists.map(\.id), [0, 2], "Meta coverage must not spend a third panel on the same observed niche")
    }

    func testCrossoverKeepsCooperatingOpeningChainsTogether() throws {
        let (fixture, study) = try setup(); _ = fixture
        var rng = SeededRNG(seed: 771)
        let selection = try AuthoredDatabaseFixture.metaProgression([])
        let a = try GeneticStrategyFactory.make(study: study, selection: selection, earlyWaveCalls: false, rng: &rng)
        let b = try GeneticStrategyFactory.make(study: study, selection: selection, earlyWaveCalls: false, rng: &rng)
        let opening = Set(a.decisions.prefix(3).map { $0.step.action.slot })
        for _ in 0..<20 {
            let child = try GeneticStrategy.crossover(a, b, slots: study.level.towerSlots.count,
                metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng, preservingOpening: opening)
            try child.validate(study: study)
            let chains = child.decisions.filter { opening.contains($0.step.action.slot) }
            XCTAssertTrue(chains == a.decisions.filter { opening.contains($0.step.action.slot) }
                || chains == b.decisions.filter { opening.contains($0.step.action.slot) })
        }
    }

    @MainActor func testIndependentFactoryProducesDifferentActualOpeningsAndKeepsAllFamilies() throws {
        let (fixture, study) = try setup(); _ = fixture
        let selection = try AuthoredDatabaseFixture.metaProgression([])
        var rng = SeededRNG(seed: 1776), openings: Set<String> = [], layoutsByFirstFamily: [UUID: Set<String>] = [:]
        var sizesByFirstFamily: [UUID: Set<Int>] = [:]
        for _ in 0..<64 {
            let strategy = try GeneticStrategyFactory.make(study: study, selection: selection, earlyWaveCalls: true, rng: &rng)
            try strategy.validate(study: study)
            let battle = try study.battle.selectingMetaUpgrades(selection.selected)
            let sim = try GameSimulation(recording: .evaluation, content: battle,
                startingMoney: study.level.startingMoney, heroesEnabled: true, seed: 1776)
            var commander = GeneticCommander(strategy); try commander.tick(sim: sim)
            let signature = sim.towers.sorted { $0.slot < $1.slot }.map { "\($0.slot):\($0.kind.rawValue)" }.joined(separator: ",")
            openings.insert(signature)
            let first = try XCTUnwrap(strategy.decisions.first)
            guard case let .build(_, id) = first.step.action else { return XCTFail("First order must build") }
            let family = try XCTUnwrap(study.towerPaths.first { $0.type.id == id }).tierIDs[0]
            layoutsByFirstFamily[family, default: []].insert(signature)
            sizesByFirstFamily[family, default: []].insert(strategy.decisions.filter { $0.step.time == 0 }.count)
        }
        XCTAssertGreaterThan(openings.count, 48, "The old paired factory produced only nine openings in 64 births")
        XCTAssertEqual(layoutsByFirstFamily.count, Set(study.towerPaths.map(\.kind)).count)
        XCTAssertTrue(layoutsByFirstFamily.values.allSatisfy { $0.count >= 3 })
        XCTAssertTrue(sizesByFirstFamily.values.allSatisfy { $0.count >= 3 }, "Family must not determine opening size")
    }

    @MainActor func testMutationUsesExecutedEvidenceAndPreservesOpeningReplacementPriority() throws {
        let (fixture, study) = try setup(); _ = fixture
        var rng = SeededRNG(seed: 654)
        let selection = try AuthoredDatabaseFixture.metaProgression([])
        let strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: study, placementIndex: 7,
            upgradePolicyIndex: 2, seed: 1776), metaProgression: selection)
        let evaluation = try GeneticCommander.evaluate(strategy, recording: .evaluation, content: study.battle,
            money: study.level.startingMoney, seed: 1776, maxSeconds: 60)
        let active = Set(strategy.executedDecisionIndices(evidence: [evaluation], study: study))
        XCTAssertFalse(active.isEmpty); XCTAssertLessThan(active.count, strategy.decisions.count)
        var activeEdits = 0
        for _ in 0..<200 {
            var child = strategy
            try child.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng,
                metaMutationEnabled: false, evidence: [evaluation], operation: .saving)
            let changed = try XCTUnwrap(strategy.decisions.indices.first { child.decisions[$0] != strategy.decisions[$0] })
            if active.contains(changed) { activeEdits += 1 }
        }
        XCTAssertGreaterThan(activeEdits, 135, "Effective orders must receive most mutations without excluding dormant DNA")
        for _ in 0..<50 {
            var child = strategy
            try child.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng,
                metaMutationEnabled: false, evidence: [evaluation], operation: .opening)
            try child.validate(study: study)
            XCTAssertEqual(child.decisions.prefix(evaluation.placementPlan!.initial.count).map { $0.step.action.slot },
                strategy.decisions.prefix(evaluation.placementPlan!.initial.count).map { $0.step.action.slot })
            XCTAssertTrue(child.decisions.prefix(evaluation.placementPlan!.initial.count).allSatisfy { $0.step.time == 0 && $0.earliestWave == 0 })
        }
    }

    @MainActor func testTacticalDNAUsesNormalCommandsAndRecordsActualDifferentSites() throws {
        let (fixture, study) = try setup(); _ = fixture
        for kind in GeneticTacticalOrder.Kind.allCases {
            let template = GeneticTacticalOrder(slot: 0, kind: kind, pathIndex: 0, progress: 0)
            let path = try XCTUnwrap(study.towerPaths.first { $0.type.levels.contains(where: template.supported) })
            let tier = try XCTUnwrap(path.type.levels.firstIndex(where: template.supported))
            var witnessed = false
            for slot in study.level.towerSlots.indices where !witnessed {
                var sites: [Point] = []
                for progress in [0.0, 1.0] {
                    let decisions = [.init(step: .init(time: 0, action: ScriptedBuildOrder.Action.build(slot: slot, towerID: path.type.id)))]
                        + (0..<tier).map { _ in GeneticStrategy.Decision(step: .init(time: 0, action: .upgrade(slot: slot))) }
                    let strategy = GeneticStrategy(decisions: decisions, metaProgression: try AuthoredDatabaseFixture.metaProgression([]),
                        tactics: [.init(slot: slot, kind: kind, pathIndex: 0, progress: progress)])
                    try strategy.validate(study: study)
                    // Disposable command test with sufficient funds for the DAO-authored capability.
                    let sim = try GameSimulation(recording: .evaluation, content: study.battle.selectingMetaUpgrades([]), startingMoney: 100_000, heroesEnabled: true, seed: 1776)
                    var commander = GeneticCommander(strategy); try commander.tick(sim: sim)
                    let tower = try XCTUnwrap(sim.towers.first)
                    if let point = kind == .rally ? tower.rallyPoint : kind == .obstacles ? tower.obstaclePoint : tower.demolitionPoint { sites.append(point) }
                }
                witnessed = sites.count == 2 && sites[0].distance(to: sites[1]) > 10
            }
            XCTAssertTrue(witnessed, "\(kind) DNA must change an actual engine-controlled site")
        }
    }

    func testTacticalDNAAndEvidenceRoundTripAndMissingRowsAreErrors() throws {
        let (fixture, study) = try setup()
        var rng = SeededRNG(seed: 53)
        var strategy = try GeneticStrategyFactory.make(study: study, selection: AuthoredDatabaseFixture.metaProgression([]), earlyWaveCalls: true, rng: &rng)
        XCTAssertFalse(strategy.tactics.isEmpty)
        let legacy = GeneticStrategy(decisions: strategy.decisions, metaProgression: strategy.metaProgression)
        let decoder = MetaUpgradesFactory.decoder(catalog: study.battle.playerUpgrades.loadout.catalog)
        XCTAssertTrue(try decoder.decode(GeneticStrategy.self, from: JSONEncoder().encode(legacy)).tactics.isEmpty)
        XCTAssertEqual(try decoder.decode(GeneticStrategy.self, from: JSONEncoder().encode(strategy)), strategy)
        for _ in 0..<100 {
            try strategy.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng, metaMutationEnabled: false)
            try strategy.validate(study: study)
            strategy = try GeneticStrategy.crossover(strategy, legacy, slots: study.level.towerSlots.count,
                metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng)
            try strategy.validate(study: study)
        }
        // A known DAO-authored capability makes the corruption test independent
        // of whether random mutation happened to remove every tactical family.
        let melee = try XCTUnwrap(study.towerPaths.first { $0.type.levels[0].meleeUnit != nil })
        strategy = .init(decisions: [.init(step: .init(time: 0, action: .build(slot: 0, towerID: melee.type.id)))],
            metaProgression: try AuthoredDatabaseFixture.metaProgression([]))
        strategy.randomizeTactics(study: study, rng: &rng)
        XCTAssertFalse(strategy.tactics.isEmpty)
        let store = try GeneticStore(conn: fixture.connection), run = UUID()
        let context = try GeneticSolutionContext(study: study, db: fixture.db,
            startingMoney: study.level.startingMoney, bountyFraction: 1, maxGameSeconds: 1800)
        try store.ensureRun(runID: run, context: context, executableSHA256: String(repeating: "a", count: 64))
        var e = try candidate(0, family: UUID()).evaluations[0]
        e.tacticalActions = [.init(seconds: 0, wave: 0, slot: 0, kind: .rally, point: Point(1.234567890123, 9.876543210987))]
        let c = GeneticCandidate(id: 0, generation: 0, strategy: strategy, evaluations: [e])
        try store.saveCandidate(c, runID: run, panel: .training, expected: 1)
        let restored = try store.candidate(runID: run, candidateID: 0, panel: .training)
        XCTAssertEqual(restored.strategy, strategy)
        XCTAssertTrue(GeneticStore.exact(e, restored.evaluations[0]))
        let id = try store.sql.one("SELECT strategy_id FROM ga_candidate WHERE run_id=?", [run]).int64("strategy_id")
        try store.sql.execute("DELETE FROM ga_tactical_order WHERE strategy_id=? AND ordinal=0", [id])
        XCTAssertThrowsError(try store.strategy(id))
    }
}
