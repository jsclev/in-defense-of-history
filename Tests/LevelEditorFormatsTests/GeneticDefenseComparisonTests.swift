import XCTest
@testable import LevelEditorFormats

final class GeneticDefenseComparisonTests: XCTestCase {
    private typealias Fixture = GeneticDefenseFixtures
    private let a = UUID(uuidString:"00000000-0000-0000-0000-000000000001")!
    private let b = UUID(uuidString:"00000000-0000-0000-0000-000000000002")!
    private let c = UUID(uuidString:"00000000-0000-0000-0000-000000000003")!
    private let selector = GeneticSolutionDiversitySelector()

    func testAllThreePlayerRejectedMoviesFailEveryPair() throws {
        let plans = [RejectedCharlestonDefenseFixtures.candidate10585,
                     RejectedCharlestonDefenseFixtures.candidate11442,
                     RejectedCharlestonDefenseFixtures.candidate12886]
        for i in plans.indices {
            for j in plans.indices where j > i {
                let comparison = try selector.compare(plans[i],plans[j])
                XCTAssertNil(comparison.defense.unknownReason)
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(comparison.defense.sharedOpeningCore),0.6)
                XCTAssertTrue(comparison.rejectionReasons.contains("shared dominant opening defense"))
                XCTAssertFalse(comparison.qualifies,"Rejected movie pair \(i)/\(j) must never become a recommendation pair again")
                print("Rejected movies \(i)/\(j): \(comparison.defense)")
            }
        }
        XCTAssertEqual(try selector.selectCompleteSet(ranked:plans,plan:{$0}).count,1)
    }
    func testDistinctMainArmiesPassAndComparisonIsSymmetric() throws {
        let left = Fixture.plan([.init(slot:0,family:a),.init(slot:1,family:a)])
        let right = Fixture.plan([.init(slot:0,family:b),.init(slot:1,family:b)])
        let x = try selector.compare(left,right), y = try selector.compare(right,left)
        XCTAssertTrue(x.qualifies); XCTAssertTrue(y.qualifies)
        XCTAssertEqual(x.novelty,1); XCTAssertEqual(x.novelty,y.novelty)
        XCTAssertEqual(x.defense.sharedOpeningCore,y.defense.sharedOpeningCore)
    }
    func testIdenticalVisibleOpeningCannotPassThroughDifferentParticipation() {
        let left = Fixture.plan([.init(slot:0,family:a),.init(slot:1,family:b,damageRate:0)])
        let right = Fixture.plan([.init(slot:0,family:a,damageRate:0),.init(slot:1,family:b)])
        let result = GeneticDefenseComparison.compare(left,right)
        XCTAssertEqual(result.sharedOpeningCore,0)
        XCTAssertEqual(result.openingFamilyTurnover,1)
        XCTAssertTrue(result.early!.qualifies)
        XCTAssertEqual(result.sharedOpeningLayout,1)
        XCTAssertFalse(result.qualifies,"The viewer sees exactly the same opening")
    }
    func testAddingExpensiveEconomyOrIdleTowersCannotDiluteCore() throws {
        let baseline = Fixture.plan([.init(slot:0,family:a),.init(slot:1,family:a)])
        let extra = Fixture.plan([.init(slot:0,family:a),.init(slot:1,family:a),
            .init(slot:2,family:b,cost:5000,damageRate:0,income:500),
            .init(slot:3,family:c,cost:5000,damageRate:0)])
        let comparison = try selector.compare(baseline,extra)
        XCTAssertEqual(comparison.defense.sharedOpeningCore,1)
        XCTAssertEqual(comparison.defense.openingFamilyTurnover,0)
        XCTAssertFalse(comparison.qualifies)
    }
    func testNearbySlotShuffleStillMatchesTheSameDefenseOneToOne() throws {
        let left = Fixture.plan([.init(slot:0,family:a,routes:[.init(index:0,progress:0.2)]),
                                 .init(slot:1,family:a,routes:[.init(index:0,progress:0.24)])])
        let right = Fixture.plan([.init(slot:8,family:a,routes:[.init(index:0,progress:0.23)]),
                                  .init(slot:9,family:a,routes:[.init(index:0,progress:0.27)])])
        let result = GeneticDefenseComparison.compare(left,right)
        XCTAssertEqual(result.sharedOpeningCore,1)
        XCTAssertEqual(result.matches.count,2)
        XCTAssertEqual(Set(result.matches.map(\.rightSlot)).count,2)
        XCTAssertFalse(result.qualifies)
    }
    func testMovingSameArmyToOppositeEndDoesNotCreateNewRoles() {
        let left = Fixture.plan([.init(slot:0,family:a,routes:[.init(index:0,progress:0.1)])])
        let right = Fixture.plan([.init(slot:8,family:a,routes:[.init(index:0,progress:0.9)])])
        let result = GeneticDefenseComparison.compare(left,right)
        XCTAssertEqual(result.sharedOpeningCore,0)
        XCTAssertEqual(result.openingFamilyTurnover,0)
        XCTAssertFalse(result.qualifies)
    }
    func testDifferentExpensiveTowersDoingAlmostNothingCannotPass() {
        let left = Fixture.plan([.init(slot:0,family:a,cost:20,damageRate:100),
                                 .init(slot:1,family:b,cost:80,damageRate:0.01)])
        let right = Fixture.plan([.init(slot:0,family:a,cost:20,damageRate:100),
                                  .init(slot:1,family:c,cost:80,damageRate:0.01)])
        let result = GeneticDefenseComparison.compare(left,right)
        XCTAssertLessThan(result.sharedOpeningCore!,0.6)
        XCTAssertGreaterThan(result.openingFamilyTurnover!,0.4)
        XCTAssertFalse(result.early!.qualifies)
        XCTAssertFalse(result.qualifies)
    }
    func testControlCanDefineARealAlternativeWithoutInventingDamage() {
        func plan(_ family: UUID, rate: Double) -> GeneticPlacementPlan {
            Fixture.plan([.init(slot:0,family:a,cost:30),
                          .init(slot:1,family:family,cost:70,damageRate:0,blockingRate:rate)])
        }
        let tiny = GeneticDefenseComparison.compare(plan(b,rate:0.001),plan(c,rate:0.001))
        XCTAssertEqual(tiny.early?.blockingTurnover,1)
        XCTAssertFalse(tiny.qualifies,"100% of a negligible amount of blocking is still negligible")
        let material = GeneticDefenseComparison.compare(plan(b,rate:1),plan(c,rate:1))
        XCTAssertEqual(material.early?.damageTurnover,0)
        XCTAssertTrue(material.qualifies)
    }
    func testDifferentOpeningsThatConvergeFailOnIncrementalMiddleActivity() {
        func plan(_ family: UUID) -> GeneticPlacementPlan {
            var p = Fixture.plan([.init(slot:0,family:family),.init(slot:1,family:c,damageRate:0)])
            let old = p.playstyle!
            let towers = old.towers.map { t -> GeneticPlaystyle.Tower in
                guard t.slot == 1, t.phase >= 2 else { return t }
                return .init(phase:t.phase,seconds:t.seconds,slot:t.slot,familyID:t.familyID,tierID:t.tierID,
                    level:t.level,branch:t.branch,attackMode:t.attackMode,spent:t.spent,damage:Double(t.phase)*30000,
                    shots:100,blockingSeconds:0,income:0,detonations:0,routes:t.routes,slowingSeconds:0)
            }
            p.playstyle = replacing(old,towers:towers)
            return p
        }
        let result = GeneticDefenseComparison.compare(plan(a),plan(b))
        XCTAssertEqual(result.openingFamilyTurnover,1)
        XCTAssertTrue(result.early!.qualifies)
        XCTAssertFalse(result.middle!.qualifies)
        XCTAssertFalse(result.qualifies)
    }
    func testMissingPhaseOrUnknownSlowingCannotQualify() {
        let left = Fixture.plan([.init(slot:0,family:a)])
        var right = Fixture.plan([.init(slot:0,family:b)])
        let original = right.playstyle!
        right.playstyle = replacing(original,towers:original.towers.filter { $0.phase != 1 })
        XCTAssertNotNil(GeneticDefenseComparison.compare(left,right).unknownReason)
        right.playstyle = replacing(original,towers:original.towers.map { t in
            var t = t; t.slowingSeconds = nil; return t
        })
        XCTAssertNotNil(GeneticDefenseComparison.compare(left,right).unknownReason)
        right.playstyle = nil
        XCTAssertFalse(GeneticDefenseComparison.compare(left,right).qualifies)
    }
    func testCoreThresholdIsInclusiveAndCannotBeOffsetByOtherDimensions() {
        let left = Fixture.plan([.init(slot:0,family:a,cost:60),.init(slot:1,family:b,cost:40)])
        let right = Fixture.plan([.init(slot:0,family:a,cost:60),.init(slot:1,family:c,cost:40)])
        let result = GeneticDefenseComparison.compare(left,right)
        XCTAssertEqual(result.sharedOpeningCore,0.6)
        XCTAssertTrue(result.early!.qualifies)
        XCTAssertFalse(result.qualifies)
    }
    func testOptimalMatchingAvoidsGreedyTrapAndHandlesRectangles() {
        let weights = [[9.0,8.0],[8.0,0.0]]
        let match = GeneticDefenseComparison.maximumMatching(weights)
        XCTAssertEqual(match.reduce(0) { $0 + weights[$1.0][$1.1] },16)
        XCTAssertEqual(GeneticDefenseComparison.maximumMatching([[2,1,3]]).map { $0.1 },[2])
        XCTAssertEqual(GeneticDefenseComparison.maximumMatching([[2],[3],[1]]).map { $0.0 },[1])
        XCTAssertTrue(GeneticDefenseComparison.maximumMatching([]).isEmpty)
        XCTAssertTrue(GeneticDefenseComparison.maximumMatching([[0,0],[0,0]]).isEmpty)
    }
    /// Optional offline integration check; the ordinary regression suite uses the
    /// frozen fixtures above and never depends on a user's changing database.
    func testSavedStudyWithoutExecutingBattles() throws {
        guard let path = ProcessInfo.processInfo.environment["GA_DIVERSITY_AUDIT_DATABASE"] else {
            throw XCTSkip("Set GA_DIVERSITY_AUDIT_DATABASE for a read-only audit of a completed study")
        }
        let db = try SimulatorDatabase.open(URL(fileURLWithPath:path),readOnly:true)
        defer { db.close() }
        let dao = try GeneticStudyDAO(db:db), run = try dao.runID()
        let ranked = try db.geneticSolutionDao.validatedCandidates(runID:run,limit:Int.max)
            .filter { $0.candidate.fitness.winRate >= 0.9 }
        let rejected = ranked.filter { [10585,11442,12886].contains($0.candidate.id) }
        XCTAssertEqual(rejected.count,3)
        for i in rejected.indices {
            for j in rejected.indices where j > i {
                let x = rejected[i].candidate, y = rejected[j].candidate
                var passing = 0, unknown = 0
                for e in x.evaluations {
                    let other = try XCTUnwrap(y.evaluations.first { $0.seed == e.seed })
                    let result = try selector.compare(XCTUnwrap(e.placementPlan),XCTUnwrap(other.placementPlan))
                    if result.qualifies { passing += 1 }
                    if result.defense.unknownReason != nil { unknown += 1 }
                }
                print("Saved pair \(x.id)/\(y.id): passing \(passing)/\(x.evaluations.count), unknown \(unknown)")
                XCTAssertEqual(passing,0); XCTAssertEqual(unknown,0)
                XCTAssertFalse(try selector.consistentlyDifferent(x,y))
            }
        }
        let selected = try selector.selectCompleteSet(ranked:ranked,plan:{ try $0.candidate.requirePlacementPlan() },
            pairEligible:{ try self.selector.consistentlyDifferent($0.candidate,$1.candidate) })
        print("Complete saved validated pool: \(ranked.count) reliable candidates; compatible set \(selected.map { $0.item.candidate.id })")
    }
    private func replacing(_ p: GeneticPlaystyle, towers: [GeneticPlaystyle.Tower]) -> GeneticPlaystyle {
        .init(duration:p.duration,purchases:p.purchases,towers:towers,reinforcementActions:p.reinforcementActions,
            earlyWaveActions:p.earlyWaveActions,demolitionActions:p.demolitionActions,
            startingLives:p.startingLives,minimumLives:p.minimumLives)
    }
}
