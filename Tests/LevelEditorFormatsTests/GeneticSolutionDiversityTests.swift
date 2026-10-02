import XCTest
@testable import LevelEditorFormats

final class GeneticSolutionDiversityTests: XCTestCase {
    private typealias Profile = GeneticSolutionDiversitySelector.Profile
    private typealias Placement = GeneticSolutionDiversitySelector.Placement
    private let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let selector = GeneticSolutionDiversitySelector()
    private func profile(_ types: [UUID], later: UUID) -> Profile {
        GeneticDefenseFixtures.plan(initial: types.enumerated().map { Placement(slot: $0.offset, towerID: $0.element) },
                subsequent: (10..<15).map { Placement(slot: $0, towerID: later) })
    }

    func testDifferentMainArmyAndSustainedContributionQualify() throws {
        let result = try selector.compare(profile([a,a,a,a], later: a), profile([a,b,b,b], later: b))
        XCTAssertEqual(result.initialSlots, 4)
        XCTAssertEqual(result.differentInitialSlots, 3)
        XCTAssertTrue(result.qualifies)
    }

    func testMeaningfulMixDoesNotRequireMovingSeventyFivePercentOfSlots() throws {
        XCTAssertTrue(try selector.compare(profile([a,a,a], later: a), profile([a,b,b], later: b)).qualifies)
    }

    func testInitialOrderDoesNotCreateDiversity() throws {
        let first = profile([a,a,b,b], later: a)
        let other = GeneticDefenseFixtures.plan(initial: first.initial.reversed(), subsequent: profile([], later: b).subsequent)
        XCTAssertEqual(try selector.compare(first, other).differentInitialSlots, 0)
    }

    func testRelocationAndDifferentLayoutSizesUseOccupiedSlotUnion() throws {
        let first = profile([a,a], later: a)
        let other = GeneticDefenseFixtures.plan(initial: [Placement(slot: 2, towerID: a)], subsequent: profile([], later: b).subsequent)
        let difference = try selector.compare(first, other)
        XCTAssertEqual(difference.initialSlots, 3)
        XCTAssertEqual(difference.differentInitialSlots, 3)
        XCTAssertTrue(difference.initialQualifies)
        XCTAssertFalse(difference.qualifies, "Relocating the same tower family is not a new playstyle")
    }

    func testEmptyInitialLayoutsDoNotQualify() throws {
        XCTAssertFalse(try selector.compare(profile([], later: a), profile([], later: b)).qualifies)
    }

    func testFourDifferentLaterBuildsDoNotVetoMeaningfulComposition() throws {
        let first = profile([a,a,a,a], later: a)
        var later = profile([], later: b).subsequent
        later[4] = first.subsequent[4]
        later.append(Placement(slot: 15, towerID: b))
        let other = GeneticDefenseFixtures.plan(initial: profile([b,b,b,b], later: b).initial, subsequent: later)
        let difference = try selector.compare(first, other)
        XCTAssertEqual(difference.comparedSubsequentPlacements, 5)
        XCTAssertEqual(difference.differentSubsequentPlacements, 4)
        XCTAssertTrue(difference.qualifies)
    }

    func testMinimalistDefenseDoesNotNeedFiveLaterPlacements() throws {
        let first = profile([a], later: a)
        let other = GeneticDefenseFixtures.plan(initial: profile([b], later: b).initial,
                            subsequent: Array(profile([], later: b).subsequent.prefix(4)))
        XCTAssertTrue(try selector.compare(first, other).qualifies)
    }

    func testEveryAlternativeMustDifferFromEverySelectedPlan() throws {
        let profiles = [profile([a,a,a,a], later: a), profile([a,a,a,b], later: b),
                        profile([b,b,b,b], later: b), profile([a,a,a,a], later: a),
                        profile([c,c,c,c], later: c)]
        let result = try selector.select(ranked: Array(0..<5), plan: { profiles[$0] })
        XCTAssertEqual(result.map(\.item), [0,2,4])
        XCTAssertEqual(result.map(\.fitnessRank), [1,3,5])
        XCTAssertEqual(result[2].comparisons.count, 2)
        XCTAssertTrue(result[2].comparisons.allSatisfy(\.qualifies))
        XCTAssertEqual(try selector.select(ranked: [0,2,3], plan: { profiles[$0] }).count, 2,
                       "The third cannot repeat the first just because it differs from the second")
    }

    func testCompositionNoveltyTakesPriorityOverSmallFitnessAdvantages() throws {
        let profiles = [profile([a,a,a,a], later: a), profile([a,b,b,b], later: b),
                        profile([b,b,b,b], later: b), profile([c,c,c,c], later: c)]
        let result = try selector.select(ranked: Array(0..<4), count: 2, plan: { profiles[$0] })
        XCTAssertEqual(result.map(\.item), [0,2], "Prefer the more distinct winner, despite its lower fitness rank")
        XCTAssertEqual(result[1].fitnessRank, 3, "Fitness remains visible and breaks equal-novelty ties")
    }

    func testSameTowerMixCannotPassByMovingEveryTowerAndChangingNextFive() throws {
        let first = profile([a,a,b,b], later: a)
        let moved = GeneticDefenseFixtures.plan(initial: first.initial.map { Placement(slot: $0.slot + 20, towerID: $0.towerID) },
                            subsequent: profile([], later: b).subsequent)
        let comparison = try selector.compare(first, moved)
        XCTAssertTrue(comparison.initialQualifies)
        XCTAssertEqual(comparison.differentSubsequentPlacements, 5)
        XCTAssertEqual(comparison.compositionDifference, 0)
        XCTAssertEqual(comparison.newFamilyShare, 0)
        XCTAssertFalse(comparison.qualifies)
    }

    func testThirdMaximizesDifferenceFromItsNearestSelectedPlaystyle() throws {
        func moved(_ types: [UUID], offset: Int) -> Profile {
            GeneticDefenseFixtures.plan(initial: types.enumerated().map { Placement(slot: offset + $0.offset, towerID: $0.element) },
                    subsequent: profile([], later: c).subsequent)
        }
        let profiles = [profile([a,a,a,a], later: a), profile([b,b,b,b], later: b),
                        moved([b,b,b,c], offset: 20), moved([a,a,b,b], offset: 30)]
        let result = try selector.select(ranked: Array(0..<4), plan: { profiles[$0] })
        XCTAssertEqual(result.map(\.item), [0,1,3],
                       "A balanced alternative is better than a plan very different from the first but close to the second")
        XCTAssertEqual(result[2].comparisons.map(\.compositionDifference), [0.5,0.5])
    }

    func testQuarterOfTowerCountDoesNotDisguiseSameMainArmy() throws {
        let first = profile(Array(repeating: a, count: 8), later: a)
        func moved(_ newCount: Int) -> Profile {
            let types = Array(repeating: a, count: 8 - newCount) + Array(repeating: b, count: newCount)
            return GeneticDefenseFixtures.plan(initial: types.enumerated().map { Placement(slot: 20 + $0.offset, towerID: $0.element) },
                           subsequent: profile([], later: b).subsequent)
        }
        let token = try selector.compare(first, moved(1))
        XCTAssertEqual(token.newFamilyShare, 0.125)
        XCTAssertFalse(token.qualifies)
        let material = try selector.compare(first, moved(2))
        XCTAssertEqual(material.newFamilyShare, 0.25)
        XCTAssertEqual(material.compositionDifference, 0.25)
        XCTAssertFalse(material.qualifies, "A quarter of the count still leaves the same main army")
        XCTAssertTrue(try selector.compare(first, moved(4)).qualifies)
    }

    func testReportsShortfallWithoutPadding() throws {
        let profiles = [profile([a], later: a), profile([b], later: b), profile([a], later: a)]
        XCTAssertEqual(try selector.select(ranked: [0,1,2], count: 2, plan: { profiles[$0] }).map(\.item), [0,1])
        XCTAssertEqual(try selector.select(ranked: [0,0,0], plan: { profiles[$0] }).count, 1)
    }

    func testCompleteSetCanUseAnotherReliableBaselineWithoutRelaxingAnyPair() throws {
        let d = UUID(uuidString:"00000000-0000-0000-0000-000000000004")!
        let profiles = [a,b,c,d].map { profile([$0],later:$0) }
        let allowed: Set<Set<Int>> = [[0,1],[1,2],[1,3],[2,3]]
        let result = try selector.selectCompleteSet(ranked:Array(0..<4),plan:{ profiles[$0] },
            pairEligible:{ allowed.contains([$0,$1]) })
        XCTAssertEqual(result.map(\.item),[1,2,3])
        XCTAssertEqual(result.map(\.fitnessRank),[2,3,4],"Original fitness ranks must stay visible")
        XCTAssertTrue(result.allSatisfy { $0.comparisons.allSatisfy(\.qualifies) })
    }

    func testCompleteSetBacktracksWhenGreedyAlternativeBlocksTheThird() throws {
        let d = UUID(uuidString:"00000000-0000-0000-0000-000000000004")!
        let profiles = [a,b,c,d].map { profile([$0],later:$0) }
        let allowed: Set<Set<Int>> = [[0,1],[0,2],[0,3],[2,3]]
        var checks: [Set<Int>: Int] = [:]
        let result = try selector.selectCompleteSet(ranked:Array(0..<4),plan:{ profiles[$0] },
            pairEligible:{ x,y in
                checks[[x,y],default:0] += 1
                return allowed.contains([x,y])
            })
        XCTAssertEqual(result.map(\.item),[0,2,3])
        XCTAssertTrue(checks.values.allSatisfy { $0 == 1 },"Do not repeat held-out panel comparisons")
        let partial = try selector.selectCompleteSet(ranked:[0,1,2],plan:{ profiles[$0] },
            pairEligible:{ allowed.contains([$0,$1]) })
        XCTAssertEqual(partial.map(\.item),[0,1],"An actual shortfall stays a shortfall")
    }

    func testInvalidProfileFailsInsteadOfRepairingLayout() throws {
        let invalid = Profile(initial: [Placement(slot: 0, towerID: a), Placement(slot: 0, towerID: b)], subsequent: [])
        XCTAssertThrowsError(try selector.select(ranked: [0], plan: { _ in invalid }))
    }

    @MainActor func testOpeningContainsOnlySuccessfulBuildsAndUsesStartingTowerIdentity() throws {
        let f = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let level = try XCTUnwrap(f.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let study = try AuthoredMoneyStudy(db: f.db, levelID: level)
        let family = try XCTUnwrap(study.battle.arsenal.towers.first { $0.kind == .ranged })
        let base = try XCTUnwrap(family.tiers.first { $0.level == 1 })
        let branch = try XCTUnwrap(family.tiers.last)
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        let strategy = GeneticStrategy(decisions: [
            .init(step: .init(time: 0, action: .build(slot: 0, towerID: branch.id))),
            .init(step: .init(time: 0, action: .build(slot: 1, towerID: base.id)))
        ], metaProgression: progression)
        let sample = try GeneticCommander.evaluate(strategy, recording: .evaluation,
            content: study.battle, money: base.tuning.cost, seed: 17, maxSeconds: 0.1)
        let plan = try XCTUnwrap(sample.placementPlan)
        XCTAssertEqual(plan.initial, [Placement(slot: 0, towerID: base.id)])
        XCTAssertTrue(plan.subsequent.isEmpty, "Unaffordable time-zero orders are not successful placements")
        var later = strategy
        later.decisions[1].step.time = 0.05
        let second = try GeneticCommander.evaluate(later, recording: .evaluation,
            content: study.battle, money: base.tuning.cost * 2, seed: 17, maxSeconds: 0.2)
        XCTAssertEqual(second.placementPlan?.initial, plan.initial)
        XCTAssertEqual(second.placementPlan?.subsequent, [Placement(slot: 1, towerID: base.id)])
        let candidate = GeneticCandidate(id: 1, generation: 0, strategy: strategy, evaluations: [sample])
        XCTAssertEqual(try candidate.requirePlacementPlan(), plan)
        var legacy = sample
        legacy.placementPlan = nil
        let old = GeneticCandidate(id: 2, generation: 0, strategy: strategy, evaluations: [legacy])
        XCTAssertThrowsError(try old.requirePlacementPlan(), "Missing history must not be inferred from DNA gates")

        let movie = try GeneticCommander.evaluate(later, recording: .database(f.db.levelRunDao, .simulator),
            content: study.battle, money: base.tuning.cost * 2, seed: 17, maxSeconds: 0.2)
        let recordingID = try XCTUnwrap(movie.runID)
        let recovered = try GeneticPlacementRecovery.read(dao: f.db.levelRunDao, recordingID: recordingID)
        XCTAssertEqual(recovered.initial, movie.placementPlan?.initial)
        XCTAssertEqual(recovered.subsequent, movie.placementPlan?.subsequent)
        XCTAssertEqual(recovered.sourceRecordingID, recordingID)
    }
}
