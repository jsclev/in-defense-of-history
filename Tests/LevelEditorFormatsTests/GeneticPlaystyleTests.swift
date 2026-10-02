import XCTest
@testable import LevelEditorFormats

final class GeneticPlaystyleTests: XCTestCase {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private func evidence(family: UUID, purchaseTime: Double = 0, activity: Bool = true,
                          mode: String = "direct", level: Int = 1, route: Int = 0,
                          reinforcements: Int = 0) -> GeneticPlaystyle {
        .init(duration: 100, purchases: [.init(seconds: purchaseTime, wave: 0, slot: 0, familyID: family,
            tierID: family, action: "build", pathID: nil, cost: 100)], towers: (0...3).map { phase in
                .init(phase: phase, seconds: Double(phase) * 100 / 3, slot: 0, familyID: family, tierID: family, level: level,
                    branch: 1, attackMode: mode, spent: 100, damage: activity ? Double(phase) * 100 / 3 : 0, shots: activity ? phase * 10 : 0,
                    blockingSeconds: mode == "melee" && activity ? Double(phase) * 10 : 0, income: 0, detonations: 0,
                    routes: [.init(index: route, progress: route == 0 ? 0.1 : 0.9)], slowingSeconds: 0) },
            reinforcementActions: reinforcements, earlyWaveActions: 0, demolitionActions: 0,
            startingLives: 20, minimumLives: 18)
    }
    func testLateTokenInvestmentAndUnusedTowerDoNotBecomeExecutedMechanics() {
        let early = evidence(family: a), late = evidence(family: b, purchaseTime: 99.9, activity: false)
        let mixed = GeneticPlaystyle(duration: 100, purchases: early.purchases + late.purchases,
            towers: early.towers + late.towers, reinforcementActions: 0, earlyWaveActions: 0,
            demolitionActions: 0, startingLives: 20, minimumLives: 18)
        XCTAssertLessThan(mixed.descriptor.investment[b.uuidString]!, 0.002)
        XCTAssertNil(mixed.descriptor.mechanics["tier:\(b)"])
        XCTAssertLessThan(GeneticPlaystyle.distance(early.descriptor.investment, mixed.descriptor.investment), 0.002)
    }
    func testMechanicsDevelopmentSpatialAndWorkloadAreSeparateMeasuredDimensions() throws {
        let x = evidence(family: a)
        let y = evidence(family: b, mode: "melee", level: 4, route: 1, reinforcements: 10)
        var left = GeneticPlacementPlan(initial: [.init(slot: 0, towerID: a)], subsequent: [])
        var right = GeneticPlacementPlan(initial: [.init(slot: 0, towerID: b)], subsequent: [])
        left.playstyle = x; right.playstyle = y
        let comparison = try GeneticSolutionDiversitySelector().compare(left,right)
        XCTAssertEqual(comparison.investmentDifference, 1)
        XCTAssertEqual(comparison.mechanicsDifference!, 1, accuracy: 0.000000000001)
        XCTAssertGreaterThan(comparison.developmentDifference!, 0)
        XCTAssertEqual(comparison.spatialDifference, 1)
        XCTAssertGreaterThan(comparison.workloadDifference!, 0)
        XCTAssertTrue(comparison.qualifies, "No five-build requirement for a minimalist defense")
    }
    func testUnusedOpeningTowerCannotManufactureAnotherPlaystyle() throws {
        var baseline = GeneticPlacementPlan(initial:[.init(slot:0,towerID:a)],subsequent:[])
        baseline.playstyle = evidence(family:a)
        let unused = GeneticPlaystyle.Purchase(seconds:0,wave:0,slot:1,familyID:b,tierID:b,
            action:"build",pathID:nil,cost:100)
        var alternative = GeneticPlacementPlan(initial:[.init(slot:0,towerID:a),.init(slot:1,towerID:b)],subsequent:[])
        let p = baseline.playstyle!
        alternative.playstyle = GeneticPlaystyle(duration:p.duration,purchases:p.purchases + [unused],
            towers:p.towers + [.init(phase:3,seconds:100,slot:1,familyID:b,tierID:b,level:1,branch:1,
                attackMode:"direct",spent:100,damage:0,shots:0,blockingSeconds:0,income:0,detonations:0,routes:[])],
            reinforcementActions:0,earlyWaveActions:0,demolitionActions:0,startingLives:20,minimumLives:18)
        let comparison = try GeneticSolutionDiversitySelector().compare(baseline,alternative)
        XCTAssertEqual(comparison.compositionDifference,0)
        XCTAssertEqual(comparison.newFamilyShare,0)
        XCTAssertFalse(comparison.qualifies)
    }
    func testCreativeParentArchiveKeepsLowerFitnessPlaystyleChampionAndOriginalBest() throws {
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        func candidate(_ id: Int, family: UUID, lives: Int) -> GeneticCandidate {
            var plan = GeneticPlacementPlan(initial: [.init(slot: 0, towerID: family)], subsequent: [])
            plan.playstyle = evidence(family: family)
            let result = SimulationResult(outcome: .victory, seconds: 100, livesRemaining: lives,
                goldRemaining: 0, goldEarned: 100, killed: 1, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: [])
            let e = GeneticEvaluation(placementPlan: plan, seed: 1, result: result, wavesStarted: 1,
                waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
            return .init(id: id, generation: 0, strategy: .init(decisions: [], metaProgression: progression), evaluations: [e])
        }
        let candidates = [candidate(1,family:a,lives:20),candidate(2,family:a,lives:19),candidate(3,family:b,lives:15)]
        XCTAssertEqual(GeneticBreedingDiversity.select(candidates,limit:2).map(\.id), [1,3])
        XCTAssertEqual(GeneticCandidate.ranked(candidates).map(\.id), [1,2,3], "Original fitness remains unchanged")
    }
    func testMaterialOpeningRoleGetsAParentSeatBeforeItWins() throws {
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        func candidate(_ id: Int, family: UUID, wins: Bool) -> GeneticCandidate {
            var plan = GeneticPlacementPlan(initial:[.init(slot:0,towerID:family)],subsequent:[])
            plan.playstyle = evidence(family:family,mode:"mode-\(id)")
            let result = SimulationResult(outcome:wins ? .victory : .defeat,seconds:100,
                livesRemaining:wins ? 20 : 0,goldRemaining:0,goldEarned:100,killed:1,leaked:wins ? 0 : 20,
                fatesByTypeID:[:],waveMaxProgress:[],leaksByWave:[])
            let e = GeneticEvaluation(placementPlan:plan,seed:1,result:result,wavesStarted:10,
                waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
            return .init(id:id,generation:0,strategy:.init(decisions:[],metaProgression:progression),evaluations:[e])
        }
        let familiar = (0..<10).map { candidate($0,family:a,wins:true) }
        let adapting = candidate(99,family:b,wins:false)
        let selected = GeneticBreedingDiversity.select(familiar + [adapting],limit:8)
        XCTAssertEqual(selected.first?.id,0)
        XCTAssertTrue(selected.contains { $0.id == adapting.id },"Eight high-fitness variants must not erase the other opening role")
        XCTAssertEqual(GeneticBreedingDiversity.matingPool(for:adapting,parents:selected).map(\.id),[99])
        let learned = candidate(100,family:b,wins:true)
        let finalists = GeneticBreedingDiversity.select(familiar + [learned],limit:3,
            distinctMetaSelections:true,creativeFinalists:true)
        XCTAssertEqual(finalists.count,3,"Different plans may share campaign upgrades")
        XCTAssertTrue(finalists.contains { $0.id == learned.id })
    }
    func testFreshIntroductionsReachTheActualSixOffspringSubpopulation() {
        let capacity = 64 / 8
        let offspring = capacity - max(1,capacity / 4)
        XCTAssertEqual(offspring,6)
        XCTAssertEqual((0..<offspring).filter {
            GeneticBreedingDiversity.introducesFreshPlan(index:$0,offspringCount:offspring,generation:8)
        },[5])
        XCTAssertTrue((0..<offspring).allSatisfy {
            !GeneticBreedingDiversity.introducesFreshPlan(index:$0,offspringCount:offspring,generation:7)
        })
    }

    func testControlledMetaExchangeStillValidatesLosingUpgradeSelections() throws {
        let choices = try [[MetaUpgrade.rangeEstimation], [.artificerCorps]].map(AuthoredDatabaseFixture.metaProgression)
        var population = try GeneticMetaPopulation(selections:choices,population:8,minimumCandidates:2)
        for group in choices.indices {
            for index in 0..<4 {
                var plan = GeneticPlacementPlan(initial:[.init(slot:0,towerID:group == 0 ? a : b)],subsequent:[])
                plan.playstyle = evidence(family:group == 0 ? a : b, mode:"mode-\(index)")
                let result = SimulationResult(outcome:group == 0 ? .victory : .defeat,seconds:100,
                    livesRemaining:group == 0 ? 20-index : 0,goldRemaining:0,goldEarned:100,
                    killed:1,leaked:group == 0 ? 0 : 20,fatesByTypeID:[:],waveMaxProgress:[],leaksByWave:[])
                let sample = GeneticEvaluation(placementPlan:plan,seed:1,result:result,wavesStarted:10,
                    waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
                try population.record(.init(id:group*10+index,generation:0,
                    strategy:.init(decisions:[],metaProgression:choices[group]),evaluations:[sample]))
            }
        }
        let creative = population.finalists(limit:4)
        XCTAssertEqual(creative.count,4,"Several creative finalists can share a single upgrade selection")
        XCTAssertTrue(creative.allSatisfy { $0.fitness.winRate == 1 })
        let controlled = population.finalists(limit:4,controlledMetaExchange:true)
        XCTAssertEqual(controlled.map(\.id),[0,10],"Controlled comparison needs the best plan for both upgrade choices")
    }
    func testCoarseNicheCannotHideAQualifiedOpeningRoleChampion() throws {
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        func profile(_ minority: Int) -> GeneticPlaystyle {
            let purchases = [a,b].enumerated().map { i,family in
                GeneticPlaystyle.Purchase(seconds:0,wave:0,slot:i,familyID:family,tierID:family,
                    action:"build",pathID:nil,cost:i == 0 ? 100-minority : minority)
            }
            return GeneticPlaystyle(duration:100,purchases:purchases,towers:[],reinforcementActions:0,
                earlyWaveActions:0,demolitionActions:0,startingLives:20,minimumLives:20)
        }
        let below = profile(14), above = profile(16)
        XCTAssertEqual(below.descriptor.niche,above.descriptor.niche)
        XCTAssertFalse(below.descriptor.materialOpeningFamilies.contains(b.uuidString))
        XCTAssertTrue(above.descriptor.materialOpeningFamilies.contains(b.uuidString))
        func candidate(_ id: Int, profile: GeneticPlaystyle, lives: Int) -> GeneticCandidate {
            var plan = GeneticPlacementPlan(initial:profile.purchases.map { .init(slot:$0.slot,towerID:$0.familyID) },subsequent:[])
            plan.playstyle = profile
            let result = SimulationResult(outcome:.victory,seconds:100,livesRemaining:lives,
                goldRemaining:0,goldEarned:100,killed:1,leaked:0,fatesByTypeID:[:],waveMaxProgress:[],leaksByWave:[])
            let e = GeneticEvaluation(placementPlan:plan,seed:1,result:result,wavesStarted:1,
                waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
            return .init(id:id,generation:0,strategy:.init(decisions:[],metaProgression:progression),evaluations:[e])
        }
        let selected = GeneticBreedingDiversity.select([
            candidate(0,profile:below,lives:20), candidate(1,profile:evidence(family:a),lives:20),
            candidate(99,profile:above,lives:19)
        ],limit:2)
        XCTAssertEqual(selected.map(\.id),[0,99])
    }
    func testLateTierPurchaseCannotClaimEarlierDamageAsItsOwnActivity() {
        let original = evidence(family:a)
        let upgraded = GeneticPlaystyle.Tower(phase:3,seconds:100,slot:0,familyID:a,tierID:b,level:4,branch:2,
            attackMode:"shell",spent:200,damage:100,shots:10,blockingSeconds:0,income:0,detonations:0,routes:[])
        let purchase = GeneticPlaystyle.Purchase(seconds:99.9,wave:10,slot:0,familyID:a,tierID:b,
            action:"upgrade",pathID:nil,cost:100)
        let profile = GeneticPlaystyle(duration:100,purchases:original.purchases + [purchase],towers:[upgraded],
            reinforcementActions:0,earlyWaveActions:0,demolitionActions:0,startingLives:20,minimumLives:18)
        XCTAssertTrue(profile.descriptor.mechanics.isEmpty,
            "No stable activity interval exists for the newly purchased branch")
    }
    func testIdenticalOpeningCannotPassOnlyThroughLaterMechanicChanges() throws {
        var left = GeneticPlacementPlan(initial:[.init(slot:0,towerID:a)],subsequent:[])
        var right = left
        left.playstyle = evidence(family:a)
        right.playstyle = evidence(family:b,mode:"melee",level:4,route:1,reinforcements:10)
        let difference = try GeneticSolutionDiversitySelector().compare(left,right)
        XCTAssertGreaterThan(difference.mechanicsDifference!,0.9)
        XCTAssertFalse(difference.qualifies,"The player explicitly rejected visually identical openings")
    }
    func testPairwiseDiversityMustHoldAcrossThePanelNotJustItsBestSeed() throws {
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        func candidate(_ id: Int, families: [UUID]) -> GeneticCandidate {
            let samples = families.enumerated().map { i,family in
                var plan = GeneticPlacementPlan(initial:[.init(slot:0,towerID:family)],subsequent:[])
                plan.playstyle = evidence(family:family)
                let result = SimulationResult(outcome:.victory,seconds:100,livesRemaining:20,
                    goldRemaining:0,goldEarned:100,killed:1,leaked:0,fatesByTypeID:[:],waveMaxProgress:[],leaksByWave:[])
                return GeneticEvaluation(placementPlan:plan,seed:UInt64(i),result:result,wavesStarted:1,
                    waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
            }
            return .init(id:id,generation:0,strategy:.init(decisions:[],metaProgression:progression),evaluations:samples)
        }
        let selector = GeneticSolutionDiversitySelector(), baseline = candidate(0,families:[a,a,a])
        XCTAssertFalse(try selector.consistentlyDifferent(baseline,candidate(1,families:[b,a,a])))
        XCTAssertTrue(try selector.consistentlyDifferent(baseline,candidate(2,families:[b,b,b])))
    }
    func testSlowingActivityRecognizesEngineersWithoutInventingDamage() {
        let purchase = GeneticPlaystyle.Purchase(seconds:0,wave:0,slot:0,familyID:a,tierID:a,
            action:"build",pathID:nil,cost:100)
        var tower = GeneticPlaystyle.Tower(phase:3,seconds:100,slot:0,familyID:a,tierID:a,level:1,branch:1,
            attackMode:"obstacles",spent:100,damage:0,shots:0,blockingSeconds:0,income:0,detonations:0,routes:[])
        tower.slowingSeconds = 25
        let profile = GeneticPlaystyle(duration:100,purchases:[purchase],towers:[tower],reinforcementActions:0,
            earlyWaveActions:0,demolitionActions:0,startingLives:20,minimumLives:20)
        XCTAssertGreaterThan(profile.descriptor.mechanics["slowing"]!,0)
        XCTAssertGreaterThan(profile.descriptor.mechanics["mode:obstacles"]!,0)
        XCTAssertEqual(profile.towers[0].damage,0)
    }
    func testControlAttributionPreservesTheOriginalStrongestFieldRuleExactly() {
        let fields = [
            EngineerObstacleField(position:.zero,stats:.init(radius:30,slowFraction:0.3,widthFraction:2),heading:0.4),
            EngineerObstacleField(position:CGPoint(x:10,y:5),stats:.init(radius:40,slowFraction:0.6,widthFraction:1),heading:0.8),
            EngineerObstacleField(position:.zero,stats:.init(radius:20,slowFraction:0.6,widthFraction:2),heading:0.2)
        ]
        for x in stride(from:-50.0,through:50.0,by:2.5) {
            for y in stride(from:-50.0,through:50.0,by:2.5) {
                let point = CGPoint(x:x,y:y)
                let strongest = fields.reduce(0.0) { value,field in field.contains(point) ? max(value,field.stats.slowFraction) : value }
                let effect = EngineerObstacleField.movementEffect(at:point,retreating:false,fields:fields)
                XCTAssertEqual(effect.multiplier.bitPattern,(1-strongest).bitPattern)
                if let i = effect.fieldIndex {
                    XCTAssertTrue(fields[i].contains(point)); XCTAssertEqual(fields[i].stats.slowFraction,strongest)
                } else { XCTAssertEqual(strongest,0) }
                XCTAssertEqual(EngineerObstacleField.movementEffect(at:point,retreating:true,fields:fields).multiplier,1)
            }
        }
    }
    @MainActor func testCaptureRoundTripsAndDoesNotChangeSharedEngineOutcome() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        let plan = try MoneyStudyPlan(study: study,placementIndex:7,upgradePolicyIndex:2,seed:1776,openingKind:.melee)
        let strategy = GeneticStrategy(plan:plan,metaProgression:progression)
        let baseline = try GeneticCommander.evaluate(strategy,recording:.evaluation,content:study.battle,
            money:study.level.startingMoney,seed:1776,maxSeconds:30,capturePlaystyle:false)
        let sample = try GeneticCommander.evaluate(strategy,recording:.evaluation,content:study.battle,
            money:study.level.startingMoney,seed:1776,maxSeconds:30)
        XCTAssertEqual(sample,baseline)
        let profile = try XCTUnwrap(sample.placementPlan?.playstyle)
        XCTAssertTrue(profile.towers.allSatisfy { $0.slowingSeconds != nil })
        XCTAssertFalse(profile.purchases.isEmpty)
        XCTAssertTrue(profile.purchases.contains { $0.action == "build" })
        XCTAssertEqual(profile.purchases.reduce(0) { $0 + $1.cost }, study.level.startingMoney + sample.result.goldEarned - sample.result.goldRemaining)
        let store = try GeneticStore(conn:fixture.connection), run=UUID()
        let context = try GeneticSolutionContext(study:study,db:fixture.db,startingMoney:study.level.startingMoney,bountyFraction:1,maxGameSeconds:30)
        try store.ensureRun(runID:run,context:context,executableSHA256:String(repeating:"a",count:64))
        let candidate = GeneticCandidate(id:0,generation:0,strategy:strategy,evaluations:[sample])
        try store.saveCandidate(candidate,runID:run,panel:.training,expected:1)
        let restored = try store.candidate(runID:run,candidateID:0,panel:.training)
        XCTAssertEqual(restored.placementPlan?.playstyle,profile)
        XCTAssertEqual(restored.fitness,candidate.fitness)
        try store.sql.execute("DELETE FROM ga_playstyle_purchase WHERE ordinal=0")
        XCTAssertThrowsError(try store.candidate(runID:run,candidateID:0,panel:.training))
    }
    @MainActor func testCreativeSeedingIncludesEveryUnlockedTowerFamilyInOpenings() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        for kind in Set(study.towerPaths.map(\.kind)) {
            let plan = try MoneyStudyPlan(study:study,placementIndex:0,upgradePolicyIndex:2,seed:1776,openingKind:kind)
            guard case let .build(_,id) = plan.steps[0].action else { return XCTFail("Opening must build") }
            XCTAssertEqual(study.towerPaths.first { $0.type.id == id }?.kind,kind)
        }
    }
    /// Opt-in offline throughput check against a completed real study; never run
    /// concurrently with a search or mutate its original evidence.
    @MainActor func testOriginalCandidateCaptureThroughput() throws {
        guard let path = ProcessInfo.processInfo.environment["TD_PLAYSTYLE_BENCHMARK_DATABASE"] else {
            throw XCTSkip("Set TD_PLAYSTYLE_BENCHMARK_DATABASE to a completed study")
        }
        let db = try SimulatorDatabase.open(URL(fileURLWithPath:path),readOnly:true)
        defer { db.close() }
        let dao = try GeneticStudyDAO(db:db), run = try dao.runID()
        let solution = try XCTUnwrap(db.geneticSolutionDao.validatedCandidates(runID:run,limit:1).first)
        let study = try AuthoredMoneyStudy(db:db,levelID:solution.context.levelID)
        var baselineSeconds = 0.0, captureSeconds = 0.0
        let seeds = Array(solution.candidate.evaluations.prefix(6))
        for (i,expected) in seeds.enumerated() {
            var samples: [Bool:GeneticEvaluation] = [:]
            for enabled in i % 2 == 0 ? [false,true] : [true,false] {
                let start = ProcessInfo.processInfo.systemUptime
                let value = try GeneticCommander.evaluate(solution.candidate.strategy,recording:.evaluation,
                    content:study.battle,money:solution.context.startingMoney,seed:expected.seed,
                    maxSeconds:solution.context.maxGameSeconds,capturePlaystyle:enabled)
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                if enabled { captureSeconds += elapsed } else { baselineSeconds += elapsed }
                samples[enabled] = value
                XCTAssertEqual(value,expected, "Recording must not change the original full-battle result")
            }
            XCTAssertEqual(samples[true],samples[false])
        }
        print("PLAYSTYLE_CAPTURE_BENCHMARK games=\(seeds.count) baseline_seconds=\(baselineSeconds) capture_seconds=\(captureSeconds) ratio=\(captureSeconds / baselineSeconds)")
    }
}
