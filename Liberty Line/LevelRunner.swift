import Foundation
import CoreGraphics
import Combine
import QuartzCore
import UIKit
import CoreHaptics

/// The iPhone adapter owns rendering, the display clock, images and haptics.
/// All battle rules and commands are inherited from the shared BattleEngine.
@MainActor
public final class LevelRunner: BattleEngine {
    private(set) var mapArt: LevelMapArt
    private let db: Db
    private var runtimeCanvas: RuntimeCanvas
    private let hudLayoutConfig: HudLayoutConfig
    private var heroControlSubscription: AnyCancellable?
    private var displayLink: CADisplayLink?
    private let enemyEscapeFeedback = UINotificationFeedbackGenerator()
    private let demolitionFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private var hapticEngine: CHHapticEngine?
    private var activeHapticPlayer: (any CHHapticPatternPlayer)?

    private var demolitionHapticPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var hapticsActive = false

    convenience init(db: Db, virtualCanvas: VirtualCanvas, runtimeCanvas: RuntimeCanvas,
         hudLayoutConfig: HudLayoutConfig = .standard, levelInfoID: UUID?,
         mapImageName: String, onVictory: @escaping (Int, Int) -> Int = { _, _ in 0 }) {
        guard let levelInfoID else { fatalError("Campaign node has no authored level_info id") }
        do {
            let content = try BattleContent(db: db, levelID: levelInfoID)
            self.init(db: db, content: content, runtimeCanvas: runtimeCanvas,
                      hudLayoutConfig: hudLayoutConfig, onVictory: onVictory)
        } catch { fatalError("Database load failed: \(error)") }
    }

    init(db: Db, content: BattleContent, runtimeCanvas: RuntimeCanvas,
         hudLayoutConfig: HudLayoutConfig,
         replaySeed: UInt64? = nil, replayMoney: Int? = nil, heroesEnabled: Bool = true,
         onVictory: @escaping (Int, Int) -> Int = { _, _ in 0 }) {
        self.db = db
        self.runtimeCanvas = runtimeCanvas
        self.hudLayoutConfig = hudLayoutConfig.moving(.heroBar, to: .southWest)
        mapArt = LevelMapArt(mapImageName: content.level.mapImageName)
        do {
            try super.init(recording: .database(db.levelRunDao, .player), content: content, playSpeed: content.playSpeeds.player, heroesEnabled: heroesEnabled, startingMoneyOverride: replayMoney,
                seed: replaySeed ?? UInt64.random(in: UInt64.min...UInt64.max), onVictory: onVictory)
            heroImageAspectRatios = try Dictionary(uniqueKeysWithValues: content.deployments.map { deployment in
                let hero = deployment.hero
                guard let image = UIImage(named: hero.unitImageName),
                      image.size.width > 0, image.size.height > 0 else {
                    throw DbError.Db(message: "Missing sprite dimensions for \(hero.shortName)")
                }
                return (hero.id, image.size.width / image.size.height)
            })
            validateHeroAsset = { name in
                guard UIImage(named: name) != nil else { fatalError("Missing hero animation image '\(name)'") }
            }
            publishesPresentation = true
            publishHeroes()
        } catch { fatalError("Database load failed: \(error)") }
    }

    func bindHeroControls(to settings: PlayerSettingsStore) {
        heroControlSubscription?.cancel()
        heroControlSubscription = settings.bindHeroControls(to: self)
    }

    func updateRuntimeCanvas(_ canvas: RuntimeCanvas) { runtimeCanvas = canvas }
    @objc private func handleFrame() { step() }
    private func step() {
        advance(ticks: timer.dueTicks(), interpolation: timer.interpolationAlpha)
    }

    override func start() {
        guard !isPaused, isReady, (!isDefeated && !isCleared) || !artilleryImpacts.isEmpty,
              displayLink == nil else { return }
        refreshWaveStartState()
        hapticsActive = true
        startHapticEngine()
        let link = CADisplayLink(target: self, selector: #selector(handleFrame))
        // Haptic startup can take several ticks. Anchor the clock only when
        // everything is ready so resuming never advances through setup time.
        timer.resync()
        lastStepGameTicks = Double(timer.tick)
        lastMilitiaTick = timer.tick
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    override func stop() {
        stopSimulation()
        hapticsActive = false
        try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        activeHapticPlayer = nil
        try? demolitionHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        demolitionHapticPlayer = nil
        hapticEngine?.stop()
        hapticEngine = nil
    }

    override func stopSimulation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func startHapticEngine() {
        guard hapticsActive, hapticEngine == nil,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else { return }
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        engine.resetHandler = { [weak self, weak engine] in
            Task { @MainActor in
                guard let self, let engine, self.hapticsActive,
                      self.hapticEngine === engine else { return }
                self.activeHapticPlayer = nil
                self.demolitionHapticPlayer = nil
                try? engine.start()

            }
        }
        try? engine.start()
        hapticEngine = engine
    }

    func playEnemyEscapeHaptic(_ cue: EnemyEscapeHapticPolicy.Cue) {
        _ = playGameplayHaptic(cue == .defeat ? .defeat : .lifeLoss)
    }

    @discardableResult override func playGameplayHaptic(_ pattern: GameplayHapticPattern) -> HapticPlayback {
        guard hapticsActive else { return .inactive }
        if pattern == .demolitionExplosion {
            try? demolitionHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            demolitionHapticPlayer = nil
        } else {
            try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            activeHapticPlayer = nil
        }
        startHapticEngine()
        func fallback() -> HapticPlayback {
            if pattern == .demolitionExplosion {
                demolitionFeedback.impactOccurred(intensity: 1)
            } else {
                enemyEscapeFeedback.notificationOccurred(.error)
            }
            return .fallback
        }
        do {
            guard let engine = hapticEngine else { return fallback() }
            try engine.start()
            if pattern == .demolitionExplosion {
                let player = try engine.makeAdvancedPlayer(with: pattern.makePattern())
                #if DEBUG
                demolitionHapticCompleted = nil
                player.completionHandler = { [weak self] error in
                    let succeeded = error == nil
                    Task { @MainActor in self?.demolitionHapticCompleted = succeeded }
                }
                #endif
                try player.start(atTime: CHHapticTimeImmediate)
                demolitionHapticPlayer = player
            } else {
                let player = try engine.makePlayer(with: pattern.makePattern())
                try player.start(atTime: CHHapticTimeImmediate)
                activeHapticPlayer = player
            }
            return .coreHaptics
        } catch {

            return fallback()
        }
    }

}

#if DEBUG
extension LevelRunner {
    /// Records the actual playable launch without issuing game commands.
    func capturePlayableLaunch() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var report: [String: Any] = ["ready": false]
        do {
            try await Task.sleep(for: .seconds(1))
            let heroStates = try heroPosts.map { post -> [String: Any] in
                guard let enabled = heroAIEnabled[post.hero.id], let controller = heroAIControllers[post.hero.id] else {
                    throw DbError.Db(message: "Missing hero controller for launch verification: \(post.hero.id)")
                }
                return ["id": post.hero.id.uuidString, "name": post.hero.shortName,
                    "aiEnabled": enabled, "controller": String(describing: type(of: controller)),
                    "x": post.unit.position.x, "y": post.unit.position.y]
            }
            report = ["ready": isReady, "levelID": content.level.id.uuidString,
                "levelName": levelName, "map": mapImageName, "money": money,
                "startingMoney": content.level.startingMoney, "awaitingWaveStart": awaitingWaveStart,
                "isPaused": isPaused, "tick": timer.tick,
                "heroes": heroStates]
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw DbError.Db(message: "No active game window for launch verification")
            }
            window.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let capture = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = capture.pngData() else { throw DbError.Db(message: "Launch screenshot failed") }
            try png.write(to: directory.appendingPathComponent("playable-launch.png"), options: .atomic)
        } catch { report["ready"] = false; report["error"] = String(describing: error) }
        report["capturedAt"] = ISO8601DateFormatter().string(from: Date())
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("playable-launch.json"), options: .atomic)
        } catch { print("Unable to save playable launch verification: \(error)") }
    }

    /// Exercises the real display-link clock; a pause must survive a foreground
    /// start request and resume without spending the wall time on game ticks.
    func runPauseLifecycleReview() async throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "PauseReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, "Level did not load")
        startNextWave()
        speedUp()
        start()
        try await Task.sleep(for: .milliseconds(600))
        pause()
        let pausedTick = timer.tick
        let pausedMoney = money
        let pausedLives = lives
        let positions = walkers.map(\.pathDistance)
        let countdown = waveCountdownSeconds
        try require(pausedTick > 0, "Game clock did not start")
        // This is the same request made when the scene becomes active again.
        start()
        try await Task.sleep(for: .seconds(1))
        try require(isPaused && displayLink == nil && !hapticsActive, "Pause restarted in the foreground")
        try require(timer.tick == pausedTick && money == pausedMoney && lives == pausedLives
                    && walkers.map(\.pathDistance) == positions && waveCountdownSeconds == countdown,
                    "Gameplay advanced while paused")
        resume()
        start()
        try require(timer.dueTicks() == 0 && timer.tick == pausedTick, "Resume caught up paused wall time")
        try await Task.sleep(for: .milliseconds(350))
        pause()
        try require(timer.tick > pausedTick && speedMultiplier == 2, "Resume lost progress or speed")
        return ["passed": true, "pausedTick": pausedTick, "resumedTick": timer.tick,
                "frozenGameplay": true, "foregroundStaysPaused": true,
                "resumeWithoutCatchUp": true, "speedPreserved": true]
    }

    struct CombatReviewFrame {
        let seconds: Double
        let presentation: BattlePresentation
        let militia: [MilitiaSoldier]
    }

    func verifyMoraleCombatOnDevice() throws -> (checks: [String: Any], frames: [CombatReviewFrame]) {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "MoraleCombatReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        guard let redcoat = enemyTypesByID.values.first(where: { $0.id == Foe.redcoatRegular.id }),
              var melee = towerLevels[.melee]?[1]?[1]?.meleeUnit,
              let heroTemplate = heroPosts.first else {
            throw NSError(domain: "MoraleCombatReview", code: 2)
        }
        try require(enemyTypesByID.values.allSatisfy { $0.stats.moraleResponse == redcoat.stats.moraleResponse },
                    "Enemy threshold data did not reach the runner")
        let origin = Point(Double(playArea.midX), Double(playArea.midY))
        melee.hp = 1000
        func enemy(_ id: Int, at point: Point, morale: Double, fixedDamage: Double = 12) -> Walker {
            var w = Walker(id: id, assetName: "redcoat_regular", speed: redcoat.stats.speed,
                maxHP: 90, hp: 90, bounty: 0, livesCost: reviewEnemyStats.livesCost, damageMin: fixedDamage, damageMax: fixedDamage,
                cover: 0, blockImmune: false, spawnTick: 0, pathIndex: 0,
                discipline: redcoat.stats.discipline, moraleResponse: redcoat.stats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: point.x, y: point.y))
            w.morale.apply(loss: 100 - morale, direction: 1)
            return w
        }
        func garrison(at point: Point, state: MilitiaUnit.State, target: Int) -> MilitiaGarrison {
            var unit = MilitiaUnit(position: Point(point.x + 80, point.y), hp: 1000)
            unit.state = state; unit.targetSpawnID = target; unit.swingTicksLeft = 1000
            return MilitiaGarrison(rallyPoint: point, units: [unit], enemySwingTicks: [target: 1],
                                   stats: melee, anchor: point)
        }
        heroPosts = []; placedTowers = []; projectiles = []; artilleryImpacts = []
        var militiaDamage: [Double] = []
        for morale in [40.001, 40.0] {
            walkers = [enemy(0, at: origin, morale: morale)]
            garrisonsBySlot = [0: garrison(at: origin, state: .fighting, target: 0)]
            stepMilitiaTick()
            militiaDamage.append(1000 - garrisonsBySlot[0]!.units[0].hp)
            try require(walkers.count == 1 && walkers[0].hp > 0 && blockedWalkerIDs.contains(0),
                        "A living blocked enemy disappeared")
        }
        try require(abs(militiaDamage[0] - 12) < 1e-8 && abs(militiaDamage[1] - 8) < 1e-8,
                    "Morale did not reduce enemy damage to militia by one third")
        var heroDamage: [Double] = []
        for morale in [40.001, 40.0] {
            var post = heroTemplate
            let target = post.unit.position
            post.unit.state = .fighting; post.unit.targetSpawnID = 0
            post.unit.hp = 1000; post.unit.swingTicksLeft = 1000; post.enemySwingTicks = [0: 1]
            heroPosts = [post]
            walkers = [enemy(0, at: target, morale: morale)]
            garrisonsBySlot = [0: garrison(at: target, state: .holding, target: -1)]
            stepMilitiaTick()
            heroDamage.append(1000 - heroPosts[0].unit.hp)
            try require(garrisonsBySlot[0]!.units[0].targetSpawnID == -1,
                        "Militia claimed an enemy already fighting a hero")
        }
        try require(heroDamage[0] > 0 && abs(heroDamage[1] / heroDamage[0] - 2.0 / 3.0) < 1e-8,
                    "Morale did not reduce enemy damage to heroes by one third")

        heroPosts = []; garrisonsBySlot = [:]; walkers = []; blockedWalkerIDs = []

        for index in 0..<6 {
            let point = Point(origin.x + Double(index % 3 - 1) * 300,
                              origin.y + (index < 3 ? 95 : -95))
            walkers.append(enemy(index, at: point, morale: index < 3 ? 100 : 35, fixedDamage: 6))
            var g = garrison(at: point, state: .engaging, target: index)
            g.units[0].position = Point(point.x, point.y + Double(index % 3 - 1) * 12)
            g.units[0].swingTicksLeft = 0
            garrisonsBySlot[index] = g
        }
        var frames: [CombatReviewFrame] = []
        for tick in 0...60 {
            militiaPrevPositions = militiaPositionsById()
            stepMilitiaTick()
            updateMilitiaPoses()
            publishMilitia(alpha: 1)
            try require(walkers.count == 6 && walkers.allSatisfy { $0.hp > 0 },
                        "Living enemy vanished during melee")
            try require(blockedWalkerIDs.count == 6, "Melee enemy lost its blocking state")
            if [0, 12, 24, 36, 60].contains(tick) {
                frames.append(CombatReviewFrame(seconds: Double(tick) * SimClock.dt,
                                               presentation: presentation, militia: militia))
            }
        }
        for index in 0..<6 {
            let friendly = garrisonsBySlot[index]!.units[0].position
            try require(abs(friendly.x - walkers[index].position.x) >= 75,
                        "Combatants still overlap after taking their stance")
        }
        return (["enemyTypes": enemyTypesByID.count, "threshold": 0.4,
                 "speedMultiplier": 2.0 / 3.0, "attackMultiplier": 2.0 / 3.0,
                 "militiaDamageAboveAndAtThreshold": militiaDamage,
                 "heroDamageAboveAndAtThreshold": heroDamage,
                 "livingMeleeEnemies": walkers.count, "blockedMeleeEnemies": blockedWalkerIDs.count,
                 "militiaCannotClaimHeroOpponent": true, "meleeSpacing": combatRules.meleeCombatSpacing], frames)
    }

    func verifyDemolitionHapticsOnDevice() async throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionHapticsReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        defer { stop() }
        try require(CHHapticEngine.capabilitiesForHardware().supportsHaptics,
                    "This device does not support Core Haptics")
        let slot = try prepareDemolitionReview(stage: "preparing")
        demolitionHapticStarts = 0
        start()
        stopSimulation()
        try require(!detonateDemolition(atSlot: slot) && demolitionHapticStarts == 0,
                    "A preparing charge played a haptic")
        advanceDemolitionCharges(seconds: 8)
        let hp = walkers.map(\.hp)
        try require(detonateDemolition(atSlot: slot), "Ready charge did not detonate")
        try require(demolitionHapticStarts == 1 && lastDemolitionHapticPlayback == .coreHaptics,
                    "Detonation did not start the custom Core Haptics pattern")
        try require(walkers.map(\.hp) != hp && artilleryImpacts.count == 1,
                    "Haptic was disconnected from the actual explosion")
        try require(!detonateDemolition(atSlot: slot) && demolitionHapticStarts == 1,
                    "A duplicate tap replayed the haptic")
        let blastPlayer = demolitionHapticPlayer
        try require(blastPlayer != nil, "Explosion has no dedicated haptic player")
        try await Task.sleep(for: .milliseconds(80))
        playEnemyEscapeHaptic(.lifeLoss)
        try await Task.sleep(for: .milliseconds(80))
        playEnemyEscapeHaptic(.defeat)
        try require(demolitionHapticPlayer === blastPlayer && activeHapticPlayer != nil,
                    "Escape feedback replaced the explosion player")
        try await Task.sleep(for: .milliseconds(100))
        try require(demolitionHapticCompleted == nil,
                    "Escape feedback stopped the explosion before its rumble finished")
        try await Task.sleep(for: .milliseconds(650))
        try require(demolitionHapticCompleted == true, "Core Haptics did not finish successfully")
        try require(hapticEngine?.isMutedForHaptics == false, "The game haptic engine is muted")

        advanceDemolitionCharges(seconds: 8)
        try require(detonateDemolition(atSlot: slot) && demolitionHapticStarts == 2,
                    "A later detonation failed to play")
        stop()
        try require(activeHapticPlayer == nil && demolitionHapticPlayer == nil
                    && hapticEngine == nil && !hapticsActive,
                    "Leaving the level did not release the haptic player")
        try require(playGameplayHaptic(.demolitionExplosion) == .inactive && activeHapticPlayer == nil,
                    "An inactive level started feedback")

        start()
        stopSimulation()
        try require(demolitionHapticStarts == 2, "Resume replayed a stale explosion")
        advanceDemolitionCharges(seconds: 8)
        try require(detonateDemolition(atSlot: slot) && demolitionHapticStarts == 3
                    && lastDemolitionHapticPlayback == .coreHaptics,
                    "Haptics failed after level resume")
        try await Task.sleep(for: .milliseconds(650))
        try require(demolitionHapticCompleted == true, "Resumed explosion did not finish")
        return ["hardwareSupportsHaptics": true, "playback": lastDemolitionHapticPlayback.rawValue,
                "durationSeconds": GameplayHapticPattern.demolitionExplosion.duration,
                "completedWithoutError": true, "successfulDetonations": demolitionHapticStarts,
                "preparingAndDoubleTapSilent": true, "stopsOnExit": true,
                "inactiveLevelSilent": true, "resumeWorksWithoutReplay": true,
                "escapeAndDefeatDoNotCancelExplosion": true, "engineMuted": false,
                "physicalSensation": "Requires user confirmation; API completion does not measure sensation"]
    }

    @discardableResult func prepareDemolitionAutomaticReview() throws -> Int {
        let slot = try prepareDemolitionReview(stage: "first-placement", includeEnemies: false)
        guard let tower = placedTower(atSlot: slot), let charge = tower.demolitionCharge,
              let position = charge.position, let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "DemolitionAutoReview", code: 1)
        }
        for (pathIndex, path) in paths.enumerated() {
            let nearest = path.nearestDistance(to: Point(position.x, position.y))
            if let exit = stride(from: nearest, to: path.totalLength, by: 1).first(where: {
                charge.willEnemyExitBlast(on: path, from: $0, advancingBy: 2,
                    radius: tuning.aoeRadius, targetOffset: enemyBodyOffset)
            }) {
                walkers = [18.0, 60.0, 90.0].enumerated().map { index, gap in
                    let distance = max(0, exit - gap)
                    let p = path.point(atDistance: distance)
                    return Walker(id: index, assetName: "redcoat_regular", speed: 60,
                        maxHP: 5000, hp: 5000, bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7,
                        cover: 0, blockImmune: false, spawnTick: -10000, pathIndex: pathIndex, discipline: reviewEnemyStats.discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: p.x, y: p.y), pathDistance: distance)
                }
                blockedWalkerIDs = []
                start(); stopSimulation()
                return slot
            }
        }
        throw NSError(domain: "DemolitionAutoReview", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No outgoing route boundary in fixture"])
    }

    func advanceDemolitionAutomaticReview(seconds: Double) {
        advanceArtilleryImpacts(seconds: seconds)
        advanceWalkers(seconds: seconds, nowTicks: Double(timer.tick) + seconds / SimClock.dt)
    }

    func verifyDemolitionAutomationOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionAutoReview", code: 3,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareDemolitionReview(stage: "first-placement", includeEnemies: false)
        let index = placedTowers.firstIndex { $0.slotIndex == slot }!
        let charge = placedTowers[index].demolitionCharge!
        let center = charge.position!
        let savedPaths = paths
        defer { paths = savedPaths; blockedWalkerIDs = []; isCleared = false; isDefeated = false }
        paths = [Path(points: [Point(center.x - 500, center.y + 12), Point(center.x + 500, center.y + 12)]),
                 Path(points: [Point(center.x - 500, center.y + 512), Point(center.x + 500, center.y + 512)])]
        func enemy(_ id: Int, distance: Double, lane: Int = 0, hp: Double = 5000, speed: Double = 60) -> Walker {
            let point = paths[lane].point(atDistance: distance)
            return Walker(id: id, assetName: "redcoat_regular", speed: speed, maxHP: hp, hp: hp,
                bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: -10000, pathIndex: lane, discipline: reviewEnemyStats.discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: point.x, y: point.y),
                pathDistance: distance)
        }
        func move(_ seconds: Double) { advanceWalkers(seconds: seconds, nowTicks: 10000) }
        move(2)
        try require(artilleryImpacts.isEmpty, "Empty site detonated")
        walkers = [enemy(0, distance: 319)]
        move(1)
        try require(artilleryImpacts.isEmpty, "Charge fired at the incoming edge")
        walkers = [enemy(0, distance: 500)]
        move(1)
        try require(artilleryImpacts.isEmpty, "Charge fired at the center")
        walkers = [enemy(0, distance: 679)]
        blockedWalkerIDs = [0]
        move(0.5)
        try require(artilleryImpacts.isEmpty && walkers[0].pathDistance == 679, "Blocked enemy triggered a charge")
        blockedWalkerIDs = []
        move(0)
        try require(artilleryImpacts.isEmpty, "Paused frame fired")
        walkers = [enemy(0, distance: 679), enemy(1, distance: 500), enemy(2, distance: 679, lane: 1)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1 && walkers[0].hp < 5000 && walkers[1].hp < 5000
            && walkers[2].hp == 5000 && !placedTowers[index].demolitionCharge!.isReady,
            "Outgoing enemy failed to trigger one blast before leaving damage range")
        let hitPoints = walkers.map(\.hp)
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1 && walkers.map(\.hp) == hitPoints, "Cooling charge fired twice")
        walkers = []
        move(8)
        try require(placedTowers[index].demolitionCharge!.isReady, "Charge failed to rearm")
        walkers = [enemy(0, distance: 679, lane: 1)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Unrelated lane triggered charge")
        walkers = [enemy(0, distance: 679, hp: 0)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Dead enemy triggered charge")
        walkers = [enemy(0, distance: 679)]
        isCleared = true; move(SimClock.dt)
        isCleared = false; isDefeated = true; move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Ended match triggered charge")
        isDefeated = false
        move(SimClock.dt)
        try require(artilleryImpacts.count == 2, "Rearmed charge failed to fire automatically")
        placedTowers[index].demolitionCharge = charge
        artilleryImpacts = []
        walkers = [enemy(0, distance: 100, hp: 1, speed: 300)]
        let cash = money, livesBefore = lives
        let expectedKillMoney = cash + Int((Double(walkers[0].bounty) * combatRules.killBountyMultiplier).rounded())
        move(3)
        try require(artilleryImpacts.count == 1 && walkers.isEmpty && money == expectedKillMoney && lives == livesBefore,
            "Long frame skipped the blast, revived a killed enemy, or duplicated its bounty")
        return ["waitsAtEntryAndCenter": true, "firesBeforeOutgoingEnemyLeaves": true,
                "blockedAndPausedStayArmed": true, "emptyDeadAndOtherLaneIgnored": true,
                "oneBlastPerCharge": true, "automaticRearm": true, "longFrameCrossing": true,
                "killedEnemyStaysDeadAndPaysOnce": true, "blockedAfterGameEnd": true]
    }

    func verifySupplyBehaviorOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "SupplyBehaviorReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady && startingMoney > 0, "The level did not load its authored starting money")
        stop()
        let savedTowers = placedTowers, savedHeroes = heroPosts
        let savedMoney = money
        defer {
            placedTowers = savedTowers; heroPosts = savedHeroes; money = savedMoney
            walkers = []; projectiles = []; pendingSpawns = []; garrisonsBySlot = [:]
            paidSupplyWaves = []; nextFireTickBySlot = [:]
            waveSchedule = try! WaveStartSchedule(waves: waves)
            refreshWaveStartState(); publishMilitia(); publishHeroes()
        }
        let origin = CGPoint(x: playArea.midX, y: playArea.midY)
        func supply(_ level: Int, _ branch: Int = 1, slot: Int = 0,
                    point: CGPoint? = nil) -> PlacedTower {
            PlacedTower(combatRules: combatRules, slotIndex: slot, kind: .supply,
                        position: point ?? origin, level: level, branch: branch)
        }
        var payouts: [Int] = []
        for (level, branch) in [(1,1), (2,1), (3,1), (4,1), (4,2), (4,3)] {
            let tower = supply(level, branch)
            placedTowers = [tower]; paidSupplyWaves = []; money = 0
            waveSchedule = try WaveStartSchedule(waves: waves)
            startNextWave()
            let expected = towerLevel(for: tower)!.support.incomePerWave
            try require(money == expected, "Manual wave start failed to pay the authored income")
            payouts.append(money)
            paySupplyIncome(for: 0)
            try require(money == expected, "Wave paid twice")
            let second = waves[1]
            let waitTicks = Int(ceil((second.callButtonDelay! + second.autoStartCountdown!)
                                     * Double(SimClock.ticksPerSecond))) + 1
            for _ in 0..<waitTicks { timer.advanceTick() }
            advanceWaveSchedule()
            try require(money == expected * 2, "Automatic wave start failed to pay once")
        }
        let gun = PlacedTower(combatRules: combatRules, slotIndex: 1, kind: .ranged, position: origin)
        let normalRate = 1 / towerLevel(for: gun)!.fireInterval
        placedTowers = [gun, supply(4, 2), supply(4, 2, slot: 2)]
        let boosted = rateOfFire(for: gun)
        try require(abs(boosted / normalRate - 1.25) < 1e-9, "Ordnance speed missing or stacked")
        let nearTicks = fireCooldownTicks(for: gun)
        placedTowers = [gun, supply(4, 2, point: CGPoint(x: origin.x + 1000, y: origin.y))]
        try require(rateOfFire(for: gun) == normalRate && fireCooldownTicks(for: gun) > nearTicks,
                    "Ordnance affects a tower outside its displayed range")
        placedTowers = [gun]
        try require(rateOfFire(for: gun) == normalRate, "Removed depot left a permanent buff")

        guard let melee = reinforcementStats, var hero = savedHeroes.first else {
            throw NSError(domain: "SupplyBehaviorReview", code: 2)
        }
        let militiaTower = PlacedTower(combatRules: combatRules, slotIndex: 1, kind: .melee, position: origin)
        placedTowers = [supply(4, 3), supply(4, 3, slot: 2), militiaTower]
        walkers = []; garrisonsBySlot = [:]
        let point = Point(origin.x, origin.y)
        var wounded = MilitiaUnit(position: point, hp: 10)
        wounded.state = .returning
        garrisonsBySlot[1] = MilitiaGarrison(rallyPoint: Point(origin.x + 100, origin.y), units: [wounded])
        try require(callReinforcements(at: origin), "Could not deploy reinforcements for hospital test")
        let reinforcementSlot = nextReinforcementSlot + 1
        for index in garrisonsBySlot[reinforcementSlot]!.units.indices {
            garrisonsBySlot[reinforcementSlot]!.units[index].hp = 10
        }
        hero.unit.hp = 10; hero.unit.position = point; hero.unit.state = .returning
        hero.unit.targetSpawnID = -1
        heroPosts = [hero]
        stepMilitiaTick()
        let expectedHP = 10 + 8 * SimClock.dt
        try require(abs(garrisonsBySlot[1]!.units[0].hp - expectedHP) < 1e-8,
                    "Hospital did not heal militia, or hospitals stacked")
        try require(abs(garrisonsBySlot[reinforcementSlot]!.units[0].hp - expectedHP) < 1e-8,
                    "Hospital did not heal reinforcements")
        try require(abs(heroPosts[0].unit.hp - expectedHP) < 1e-8,
                    "Hospital did not heal heroes")
        try require(garrisonsBySlot[1]!.units[0].hp <= melee.hp, "Hospital overhealed militia")
        return ["incomeByTier": payouts, "manualAndAutomaticWavePayouts": true,
                "onePaymentPerWave": true, "ordnanceRateMultiplier": boosted / normalRate,
                "ordnanceReloadTicks": nearTicks, "rangeAndRemovalVerified": true,
                "healsMilitiaReinforcementsAndHeroes": true, "overlappingAurasDoNotStack": true,
                "charlestonStartingMoney": startingMoney]
    }

    @discardableResult func prepareTowerUpgradeReview(kind: TowerKind, atLevel: Int = 3) throws -> Int {
        guard isReady, let tuning = towerLevels[kind]?[atLevel]?[1],
              let slot = slotPositions.indices.sorted(by: {
                  hypot(slotPositions[$0].x - playArea.midX, slotPositions[$0].y - playArea.midY)
                    < hypot(slotPositions[$1].x - playArea.midX, slotPositions[$1].y - playArea.midY)
              }).first(where: {
                  tuning.attackMode == .none ||
                  tuning.attackRange.nearestPathPoint(to: slotPositions[$0], from: slotPositions[$0], paths: paths) != nil
              }) else {
            throw NSError(domain: "TowerUpgradeReview", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No valid upgrade fixture: \(status)"])
        }
        stop()
        placedTowers = []; walkers = []; projectiles = []; artilleryImpacts = []
        garrisonsBySlot = [:]; rallyPointsBySlot = [:]; militia = []
        rallyFlagFlash = nil; grapeshotHits = [:]
        nextFireTickBySlot = [:]; damageTotalBySlot = [:]
        money = 10_000; towerUnlocks[kind] = 4
        awaitingWaveStart = false; isCleared = false; isDefeated = false
        dismissMenu()
        selectSlot(slot); tapBuildButton(kind); tapBuildButton(kind)
        for _ in 1..<atLevel {
            selectPlacedTower(atSlot: slot)
            tapUpgradeButton(branch: 1); tapUpgradeButton(branch: 1)
        }
        selectPlacedTower(atSlot: slot)
        return slot
    }

    /// Exercises conditional meta effects in the actual runner with isolated, in-memory battle fixtures.
    func verifyHistoricalMetaUpgradesOnDevice() throws -> [String: Any] {
        func require(_ valid: Bool, _ message: String) throws {
            if !valid { throw NSError(domain: "HistoricalUpgradeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func enemy(_ id: Int, at point: CGPoint, cover: Double = 0) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7,
                cover: cover, blockImmune: false, spawnTick: 0, pathIndex: 0,
                discipline: reviewEnemyStats.discipline, moraleResponse: reviewEnemyStats.moraleResponse,
                morale: EnemyMorale(rules: combatRules), position: point)
        }
        var evidence: [String: Any] = [:]
        let slot = try prepareTowerUpgradeReview(kind: .ranged, atLevel: 1)
        let tower = placedTowers[0]
        // Fix the random damage range only in this disposable runner.
        pricedTowerLevels[.ranged]![1]![1]!.shotMinDamage = 100
        pricedTowerLevels[.ranged]![1]![1]!.shotMaxDamage = 100
        let target = CGPoint(x: tower.position.x + 50, y: tower.position.y)
        var shots: [Double] = []
        for index in 0..<3 {
            walkers = [enemy(index, at: target)]
            blockedWalkerIDs = [index]
            projectiles = []; nextFireTickBySlot = [:]
            updateCombat(gameDt: 0.000001)
            try require(projectiles.count == 1, "Prepared ranged tower failed to fire")
            shots.append(projectiles[0].damage)
        }
        try require(abs(shots[0] - 156) < 1e-8 && shots[0] == shots[1] && abs(shots[2] - 120) < 1e-8,
                    "Prepared pair, combined arms, or retarget behavior is incorrect")
        if selectedTowerSlotIndex != slot { selectPlacedTower(atSlot: slot) }
        upgradeSelectedTower(branch: 1)
        try require(placedTowers[0].preparedVolley?.shotsRemaining == 0, "Tier purchase refilled the volley")
        walkers = []; projectiles = []; blockedWalkerIDs = []
        updateCombat(gameDt: 0)
        try require(placedTowers[0].preparedVolley?.shotsRemaining == 0, "Pause refilled the volley")
        updateCombat(gameDt: 7.9)
        try require(placedTowers[0].preparedVolley?.shotsRemaining == 0, "A short gap refilled the volley")
        updateCombat(gameDt: 0.1)
        try require(placedTowers[0].preparedVolley?.shotsRemaining == 2, "Quiet tower did not prepare its next pair")
        evidence["preparedVolleyDamage"] = shots

        // Model Company and French Contracts affect offers and the amount actually paid.
        let trainedPrice = upgradeCost(for: .ranged, to: 2)!
        try require(trainedPrice == Int(ceil(Double(authoredTowerLevels[.ranged]![2]![1]!.cost) * 0.85)),
                    "Second same-family tier did not receive the model-company discount")
        let trainedSlot = try prepareTowerUpgradeReview(kind: .ranged, atLevel: 1)
        let beforeTraining = money
        upgradeSelectedTower(branch: 1)
        try require(beforeTraining - money == trainedPrice, "Training discount shown but not charged")
        selectPlacedTower(atSlot: trainedSlot); upgradeSelectedTower(branch: 1)
        selectPlacedTower(atSlot: trainedSlot)
        let firstOffer = upgradeOffers.first!
        let beforeContract = money
        upgradeSelectedTower(branch: firstOffer.branch)
        try require(beforeContract - money == firstOffer.cost && metaBattleProgress.hasSpecialization,
                    "French contract was not consumed by the actual purchase")
        let afterContract = upgradeCost(for: .ranged, to: 4, branch: firstOffer.branch)!
        try require(firstOffer.cost == Int(ceil(Double(afterContract) * 0.75)),
                    "French contract did not apply exactly once")
        evidence["modelCompanyPrice"] = trainedPrice
        evidence["firstSpecializationPrices"] = [firstOffer.cost, afterContract]

        // Coverage uses another post's authored range and does not stack.
        let supplySlot = try prepareTowerUpgradeReview(kind: .ranged, atLevel: 1)
        let point = slotPositions[supplySlot]
        let unserved = upgradeCost(for: .ranged, to: 2)!
        let postSlot = (supplySlot + 1) % slotPositions.count
        let post = PlacedTower(combatRules: combatRules, slotIndex: postSlot, kind: .supply, position: point)
        placedTowers.append(post)
        let served = upgradeCost(for: .ranged, to: 2)!
        placedTowers.append(PlacedTower(combatRules: combatRules, slotIndex: (postSlot + 1) % slotPositions.count,
            kind: .supply, position: point))
        try require(served < unserved && upgradeCost(for: .ranged, to: 2) == served, "Magazine discount missing or stacked")
        let beforeMagazine = money
        upgradeSelectedTower(branch: 1)
        try require(beforeMagazine - money == served, "Magazine offer differs from the charged price")
        placedTowers = [post]
        try require(!isServedByMagazine(postSlot), "Supply post discounted itself")
        evidence["magazineTierPrices"] = [unserved, served]

        // A shared abatis field qualifies at impact, once even if fields overlap.
        let engineerSlot = try prepareTowerUpgradeReview(kind: .special, atLevel: 1)
        let site = placedTower(atSlot: engineerSlot)!.engineerObstaclePosition!
        var secondField = PlacedTower(combatRules: combatRules, slotIndex: postSlot, kind: .special, position: site)
        secondField.engineerObstaclePosition = site
        placedTowers.append(secondField)
        let shot = Projectile(id: 0, kind: .ranged, position: site, heading: 0, damage: 100,
            targetID: 0, slotIndex: 0, speed: 640, splashRadius: 0)
        walkers = [enemy(0, at: site)]
        applyImpact(shot, at: site)
        try require(abs(walkers[0].hp - 885) < 1e-8, "Fire lane bonus missing or stacked")
        walkers = [enemy(0, at: CGPoint(x: site.x + 1000, y: site.y))]
        applyImpact(shot, at: site)
        try require(walkers[0].hp == 900, "Fire lane persisted after leaving the obstacle")
        evidence["fireLaneImpactAndOverlap"] = true

        // Shell cover penetration uses the actual explosion path.
        placedTowers = []
        let origin = CGPoint(x: playArea.midX, y: playArea.midY)
        let shell = towerLevels[.areaOfEffect]![1]![1]!
        walkers = [enemy(0, at: origin, cover: 0.5)]
        applyImpact(Projectile(id: 1, kind: .areaOfEffect, position: origin, heading: 0,
            damage: 100, targetID: 0, slotIndex: 0, speed: 640,
            splashRadius: CGFloat(shell.aoeRadius), splashCoverPierce: shell.splashCoverPierce,
            moraleStrike: ArtilleryMoraleStrike(tuning: shell)), at: origin)
        let shellDamage = 100 * (1 - 0.5 * (1 - shell.splashCoverPierce))
        try require(abs(1000 - walkers[0].hp - shellDamage) < 1e-8, "Shell doctrine ignored authored cover penetration")
        evidence["shellDamageAgainstHalfCover"] = shellDamage

        // Solid shot bonus begins with its second distinct contact, never its first.
        let boundary = TowerAttackRange(300, verticalFraction: combatRules.rangeVerticalFraction)
        walkers = (0..<3).map { enemy($0, at: CGPoint(x: origin.x + 30 + Double($0) * 50 - enemyBodyOffset.x,
                                                    y: origin.y - enemyBodyOffset.y)) }
        projectiles = [Projectile(id: 2, kind: .areaOfEffect, position: origin, heading: 0,
            damage: 100, targetID: 0, slotIndex: 0, speed: 640, splashRadius: 0,
            firingBoundary: boundary, firingOrigin: origin,
            solidShot: SolidShotFlight(range: 300, hitRadius: combatRules.solidShotHitRadius))]
        updateCombat(gameDt: 0.3)
        try require(walkers.map(\.hp) == [900, 875, 875], "Solid-shot doctrine did not distinguish the first victim")
        updateCombat(gameDt: 0.05)
        try require(walkers.map(\.hp) == [900, 875, 875], "Solid shot hit the same victim twice")
        evidence["solidShotDamage"] = [100, 125, 125]

        // Close grapeshot benefits only inside half the firing reach.
        var grapeDamage: [Double] = []
        for distance in [60.0, 240.0] {
            walkers = [enemy(0, at: CGPoint(x: origin.x + distance - enemyBodyOffset.x, y: origin.y - enemyBodyOffset.y))]
            grapeshotHits = [:]
            projectiles = [Projectile(id: 3, kind: .areaOfEffect, position: origin, heading: 0,
                damage: 100, targetID: 0, slotIndex: 0, speed: 640, splashRadius: 0,
                firingBoundary: boundary, firingOrigin: origin,
                grapeshot: GrapeshotFlight(volleyID: 3, range: 300))]
            updateCombat(gameDt: 0.5)
            grapeDamage.append(1000 - walkers[0].hp)
        }
        try require(grapeDamage == [125, 100], "Grapeshot doctrine ignored distance")
        evidence["grapeshotDamageNearAndFar"] = grapeDamage
        stop()
        return evidence
    }

    func verifyPurchasedTowerOnDevice(slot: Int) throws -> [String: Any] {
        func require(_ valid: Bool, _ message: String) throws {
            if !valid { throw NSError(domain: "TowerPathReview", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower),
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }) else {
            throw NSError(domain: "TowerPathReview", code: 2)
        }
        try require(tuning.upgradePaths.allSatisfy { tower.upgrades.rank(for: $0.id) == $0.ranks.count },
                    "Not all paths purchased")
        func enemy(at point: CGPoint) -> Walker {
            Walker(id: 0, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7,
                cover: 0, blockImmune: false, spawnTick: 0, pathIndex: 0, discipline: 0.6,
                moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules),
                position: CGPoint(x: point.x - enemyBodyOffset.x, y: point.y - enemyBodyOffset.y))
        }
        var evidence: [String: Any] = ["kind": tower.kind.rawValue, "branch": tower.branch,
                                       "ranks": tower.upgrades.ranks]
        defer { walkers = []; projectiles = []; artilleryImpacts = []; nextFireTickBySlot = [:] }
        if tuning.attackMode.firesProjectiles {
            let point = CGPoint(x: tower.position.x + 100, y: tower.position.y)
            walkers = [enemy(at: point)]
            placedTowers[index].artilleryAim = ArtilleryAim(heading: 0, firingTolerance: combatRules.firingTolerance)
            nextFireTickBySlot = [:]; grapeshotHits = [:]
            updateCombat(gameDt: 0.00001)
            let expectedCount = tuning.attackMode == .grapeshot ? combatRules.grapeshotSpreadDegrees.count : 1
            try require(projectiles.count == expectedCount, "Upgraded specialty failed to fire")
            try require(projectiles.allSatisfy {
                (tuning.shotMinDamage...tuning.shotMaxDamage).contains($0.damage)
            }, "Shot did not use purchased damage")
            try require(nextFireTickBySlot[slot] == timer.tick + fireCooldownTicks(for: placedTowers[index]),
                        "Shot did not use purchased reload")
            let snapshot = projectiles[0]
            updateProjectiles(gameDt: 2)
            try require(walkers[0].hp < 1000, "Purchased shot did not damage an enemy")
            if tuning.attackMode.requiresAim {
                try require(snapshot.moraleStrike == ArtilleryMoraleStrike(tuning: tuning)
                    && walkers[0].morale.value < 100, "Purchased shot lost its morale effect")
            }
            evidence["shotDamage"] = 1000 - walkers[0].hp
            evidence["reloadTicks"] = fireCooldownTicks(for: placedTowers[index])
        }
        if let seconds = tuning.demolitionPreparationSeconds {
            try require(tower.demolitionCharge?.isReadyForPlacement == true,
                        "Purchasing sapper paths placed or consumed the initial charge")
            selectPlacedTower(atSlot: slot)
            if selectedTowerSlotIndex != slot { selectPlacedTower(atSlot: slot) }
            beginDemolitionPlacement()
            let site = tuning.attackRange.nearestPathPoint(to: tower.position, from: tower.position, paths: paths)!
            placeDemolition(at: site)
            walkers = [enemy(at: site)]
            try require(detonateDemolition(atSlot: slot), "Upgraded charge did not detonate")
            try require((tuning.shotMinDamage...tuning.shotMaxDamage).contains(1000 - walkers[0].hp),
                        "Charge did not use purchased damage")
            try require(placedTowers[index].demolitionCharge?.remainingSeconds == seconds,
                        "Charge did not use purchased preparation time")
            evidence["chargePreparationSeconds"] = seconds
            evidence["chargeDamage"] = 1000 - walkers[0].hp
        }
        if let stats = tuning.engineerObstacles {
            let field = try { () throws -> EngineerObstacleField in
                guard let field = engineerObstacleFields.first else { throw NSError(domain: "TowerPathReview", code: 3) }
                return field
            }()
            try require(field.stats == stats, "Live obstacle field did not use purchased stats")
            let multiplier = EngineerObstacleField.movementMultiplier(at: field.position, retreating: false, fields: engineerObstacleFields)
            try require(abs(multiplier - (1 - stats.slowFraction)) < 1e-8, "Live obstacles ignored purchased slow")
            evidence["movementMultiplier"] = multiplier
        }
        if let melee = tuning.meleeUnit {
            publishMilitia()
            try require(militia.allSatisfy { $0.maxHP == melee.hp },
                        "Displayed soldiers ignored purchased health")
            evidence["soldierHP"] = melee.hp
            evidence["soldierDamage"] = melee.attackRating
            evidence["soldierInterval"] = melee.attackInterval
        }
        if tuning.support.incomePerWave > 0 {
            let before = money
            paySupplyIncome(for: Int.max)
            try require(money - before == tuning.support.incomePerWave, "Purchased supply income was ignored")
            paySupplyIncome(for: Int.max)
            try require(money - before == tuning.support.incomePerWave, "Supply purchase duplicated wave income")
            paidSupplyWaves.remove(Int.max)
            if tuning.support.healPerSecond > 0 {
                try require(TowerSupportSource.healing(at: tower.position, sources: supportSources) == tuning.support.healPerSecond,
                            "Purchased healing missing from live sources")
            }
            if tuning.support.attackSpeedMultiplier > 1 {
                try require(TowerSupportSource.attackSpeed(at: tower.position, for: .direct, sources: supportSources)
                            == tuning.support.attackSpeedMultiplier, "Purchased reload aura missing from live sources")
            }
            evidence["income"] = tuning.support.incomePerWave
            evidence["healing"] = tuning.support.healPerSecond
            evidence["reloadAura"] = tuning.support.attackSpeedMultiplier
        }
        return evidence
    }

    func verifyEngineerObstaclesOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "EngineerReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareTowerUpgradeReview(kind: .special, atLevel: 1)
        guard let site = placedTower(atSlot: slot)?.engineerObstaclePosition else {
            throw NSError(domain: "EngineerReview", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No initial obstacle field"])
        }
        let savedPaths = paths
        defer { paths = savedPaths; blockedWalkerIDs = []; walkers = [] }
        paths = [Path(points: [Point(site.x - 500, site.y), Point(site.x + 1000, site.y)]),
                 Path(points: [Point(site.x - 500, site.y + 300), Point(site.x + 1000, site.y + 300)])]
        func enemy(_ id: Int, lane: Int = 0) -> Walker {
            let point = paths[lane].point(atDistance: 500)
            return Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 100, hp: 100,
                bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: -10000, pathIndex: lane, discipline: reviewEnemyStats.discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: point.x, y: point.y), pathDistance: 500)
        }
        var travelByLevel: [Double] = []
        for tier in 1...3 {
            if tier > 1 {
                let before = money
                if selectedTowerSlotIndex != slot { selectPlacedTower(atSlot: slot) }
                tapUpgradeButton(branch: 1); tapUpgradeButton(branch: 1)
                try require(before - money == towerLevels[.special]?[tier]?[1]?.cost, "Incorrect upgrade cost")
            }
            try require(placedTower(atSlot: slot)?.level == tier
                && placedTower(atSlot: slot)?.engineerObstaclePosition == site, "Upgrade lost its field")
            walkers = [enemy(0), enemy(1, lane: 1)]
            try require(engineerObstacleFeedback.walkerIDs == [0]
                && engineerObstacleFeedback.towerSlots == [slot],
                "Slow feedback did not identify the affected enemy and its tower")
            advanceWalkers(seconds: 0.25, nowTicks: 10000)
            let travel = walkers[0].pathDistance - 500
            travelByLevel.append(travel)
            guard let authoredSlow = towerLevels[.special]?[tier]?[1]?.engineerObstacles?.slowFraction else {
                throw NSError(domain: "EngineerReview.MissingSlow", code: tier)
            }
            try require(abs(travel - 15 * (1 - authoredSlow)) < 0.001,
                        "Wrong tier \(tier) slowdown")
            try require(abs(walkers[1].pathDistance - 515) < 0.001, "Slowed an unrelated lane")
            updateCombat(gameDt: 0.25)
            try require(projectiles.isEmpty && walkers.allSatisfy { $0.hp == 100 && $0.morale.value == 100 },
                        "\(towerFamilyName(for: .special)) dealt direct damage")
        }
        let beforePause = walkers[0].pathDistance
        advanceWalkers(seconds: 0, nowTicks: 10000)
        try require(walkers[0].pathDistance == beforePause, "Pause moved an enemy")
        blockedWalkerIDs = [0]
        advanceWalkers(seconds: 0.25, nowTicks: 10000)
        try require(walkers[0].pathDistance == beforePause, "Obstacles overrode melee blocking")
        blockedWalkerIDs = []
        walkers[0].hp = 0
        try require(engineerObstacleFeedback.walkerIDs.isEmpty
            && engineerObstacleFeedback.towerSlots.isEmpty, "Dead enemies kept obstacles active")
        walkers[0].hp = 100
        walkers[0].position = CGPoint(x: site.x + 1000, y: site.y)
        try require(engineerObstacleFeedback.walkerIDs.isEmpty, "Slow feedback lingered after exit")
        walkers[0].position = site
        selectPlacedTower(atSlot: slot); beginEngineerObstaclePlacement()
        placeEngineerObstacles(at: CGPoint(x: -99999, y: -99999))
        try require(placedTower(atSlot: slot)?.engineerObstaclePosition == site
            && !isPlacingEngineerObstacles, "Invalid placement moved the field")
        selectPlacedTower(atSlot: slot); beginEngineerObstaclePlacement()
        placeEngineerObstacles(at: CGPoint(x: site.x + 30, y: site.y))
        try require(placedTower(atSlot: slot)?.engineerObstaclePosition == CGPoint(x: site.x + 30, y: site.y),
                    "Placement control failed to move obstacles")
        selectPlacedTower(atSlot: slot); tapUpgradeButton(branch: 3); tapUpgradeButton(branch: 3)
        try require(engineerObstacleFields.isEmpty
            && engineerObstacleFeedback.walkerIDs.isEmpty
            && engineerObstacleFeedback.towerSlots.isEmpty
            && placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true,
                    "Demolition upgrade retained obstacles or auto-placed its charge")
        return ["passed": true, "distanceInQuarterSecondByLevel": travelByLevel,
                "unaffectedLaneDistance": 15, "upgradeAndPlacement": true,
                "pauseAndMeleeBlocking": true, "demolitionTransition": true,
                "feedbackMatchesMovementAndClearsOnExitDeathAndRemoval": true]
    }

    @discardableResult func prepareEngineerObstacleReview(level: Int, entering: Bool = false) throws -> Int {
        let slot = try prepareTowerUpgradeReview(kind: .special, atLevel: level)
        guard let site = placedTower(atSlot: slot)?.engineerObstaclePosition else { return slot }
        let target = Point(site.x, site.y)
        if let lane = paths.indices.min(by: {
            paths[$0].point(atDistance: paths[$0].nearestDistance(to: target)).distance(to: target)
                < paths[$1].point(atDistance: paths[$1].nearestDistance(to: target)).distance(to: target)
        }) {
            let center = paths[lane].nearestDistance(to: target)
            let offsets = entering ? [-220.0, -345, -470] : [-65.0, 0, 65]
            walkers = offsets.enumerated().map { index, offset in
                let distance = max(0, center + offset)
                let point = paths[lane].point(atDistance: distance)
                return Walker(id: index, assetName: "redcoat_regular", speed: 60, maxHP: 100, hp: 100,
                    bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                    spawnTick: -10000, pathIndex: lane, discipline: reviewEnemyStats.discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: point.x, y: point.y), pathDistance: distance)
            }
            if entering {
                walkers[1].hp = 65
                walkers[1].morale.apply(loss: combatRules.moraleMax * 0.4, direction: 1)
            }
        }
        dismissMenu()
        return slot
    }

    func engineerRoadFitReviewFields() throws -> [(slot: Int, stage: String, field: EngineerObstacleField)] {
        guard let first = towerLevels[.special]?[1]?[1],
              let fourth = towerLevels[.special]?[4]?[2] else {
            throw NSError(domain: "EngineerRoadFit.MissingTuning", code: 1)
        }
        var progress = TowerUpgradeProgress(), reviewBudget = 10_000
        for path in fourth.upgradePaths {
            for _ in path.ranks {
                guard progress.purchase(pathID: path.id, from: fourth, money: &reviewBudget) == .ok else {
                    throw NSError(domain: "EngineerRoadFit.Upgrade", code: 2)
                }
            }
        }
        var stages: [(String, TowerLevel)] = try (1...3).map { tier in
            guard let tuning = towerLevels[.special]?[tier]?[1] else {
                throw NSError(domain: "EngineerRoadFit.MissingTier", code: tier)
            }
            return (String(tier), tuning)
        }
        stages += [("4", fourth), ("4-max", fourth.upgraded(with: progress))]
        return try slotPositions.enumerated().flatMap { slot, position in
            guard let site = first.attackRange.nearestPathPoint(to: position, from: position, paths: paths) else {
                throw NSError(domain: "EngineerRoadFit.NoSite", code: slot)
            }
            return try stages.map { stage, tuning in
                guard let stats = tuning.engineerObstacles else {
                    throw NSError(domain: "EngineerRoadFit.MissingObstacles", code: slot)
                }
                return (slot, stage, EngineerObstacleField(position: site, stats: stats, paths: paths))
            }
        }
    }

    func advanceEngineerObstacleReview(seconds: Double) {
        advanceWalkers(seconds: seconds, nowTicks: 10000)
    }

    @discardableResult func prepareDemolitionReview(stage: String, includeEnemies: Bool = true) throws -> Int {
        let slot = try prepareTowerUpgradeReview(kind: .special)
        guard let tuning = towerLevels[.special]?[4]?[3] else {
            throw NSError(domain: "DemolitionReview", code: 1)
        }
        if stage == "upgrade" { return slot }
        tapUpgradeButton(branch: 3); tapUpgradeButton(branch: 3)
        if stage == "unplaced" { return slot }
        if stage == "unplaced-menu" || stage == "unplaced-placement" {
            selectPlacedTower(atSlot: slot)
            if stage == "unplaced-placement" { beginDemolitionPlacement() }
            return slot
        }
        guard let tower = placedTower(atSlot: slot),
              let point = tuning.attackRange.nearestPathPoint(to: tower.position, from: tower.position, paths: paths) else {
            throw NSError(domain: "DemolitionReview", code: 2)
        }
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: point)
        if stage != "first-placement" { rallyFlagFlash = nil }
        guard let charge = placedTower(atSlot: slot)?.demolitionCharge, let chargePosition = charge.position else {
            throw NSError(domain: "DemolitionReview", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Manual placement did not plant the charge"])
        }
        if stage == "preparing" {
            detonateDemolition(atSlot: slot)
            artilleryImpacts = []
            advanceDemolitionCharges(seconds: 3)
        }
        for i in 0..<(includeEnemies ? 6 : 0) {
            walkers.append(Walker(id: i, assetName: "redcoat_regular", speed: 60,
                maxHP: 180, hp: 180, bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7,
                cover: 0, blockImmune: false, spawnTick: 0, pathIndex: 0, discipline: 0.6, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: chargePosition.x + Double(i % 3 - 1) * 65,
                                  y: chargePosition.y + Double(i / 3) * 65 + 12)))
        }
        if stage == "preparing" { return slot }
        advanceDemolitionCharges(seconds: 8)
        if stage == "blast" || stage == "after" {
            detonateDemolition(atSlot: slot)
            artilleryImpacts = artilleryImpacts.map { impact in
                var result = impact; result.age = 0.18; return result
            }
            if stage == "after" { artilleryImpacts = [] }
        }
        if stage == "menu" { selectPlacedTower(atSlot: slot) }
        if stage == "placement" || stage == "relocated" {
            selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
            if stage == "relocated", let tower = placedTower(atSlot: slot) {
                placeDemolition(at: CGPoint(x: tower.position.x + tuning.range * 0.8, y: tower.position.y))
            }
        }
        return slot
    }

    func advanceDemolitionReadinessReview(seconds: Double) {
        advanceDemolitionCharges(seconds: seconds)
        advanceArtilleryImpacts(seconds: seconds)
    }

    @discardableResult func prepareExplosionReview(ended: Bool = false) throws -> Int {
        let slot = try prepareDemolitionReview(stage: "ready")
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "DemolitionReview", code: 8)
        }
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x - tuning.range * 0.65,
                                    y: tower.position.y - tuning.range * 0.2))
        advanceDemolitionCharges(seconds: 8)
        guard let position = placedTower(atSlot: slot)?.demolitionCharge?.position else {
            throw NSError(domain: "DemolitionReview", code: 9)
        }
        for index in walkers.indices {
            walkers[index].position = CGPoint(x: position.x + Double(index % 3 - 1) * 65,
                                              y: position.y + Double(index / 3) * 65 + 12)
        }
        guard detonateDemolition(atSlot: slot) else {
            throw NSError(domain: "DemolitionReview", code: 10)
        }
        if ended { isCleared = true }
        return slot
    }

    func advanceExplosionReview(seconds: Double) {
        advanceArtilleryImpacts(seconds: seconds)
        for index in walkers.indices {
            _ = walkers[index].morale.advance(seconds: seconds, baseSpeed: 0,
                response: walkers[index].moraleResponse, blocked: true)
        }
    }

    func verifyDemolitionOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionReview", code: 3,
                                          userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareDemolitionReview(stage: "upgrade")
        try require(upgradeOffers.map(\.branch) == [1, 2, 3], "Expected engineer upgrade branches 1, 2 and 3")
        let before = money
        tapUpgradeButton(branch: 3)
        try require(placedTower(atSlot: slot)?.level == 3, "Preview spent money or upgraded")
        tapUpgradeButton(branch: 3)
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower),
              let initialCharge = tower.demolitionCharge else {
            throw NSError(domain: "DemolitionReview", code: 4)
        }
        try require(tower.kind == .special && tower.level == 4 && tower.branch == 3 && before - money == tuning.cost,
                    "Wrong upgrade or charge cost")
        try require(initialCharge.isReadyForPlacement && initialCharge.position == nil
                    && initialCharge.remainingSeconds == 0, "First charge was delayed or automatically placed")
        try require(!detonateDemolition(atSlot: slot), "Unplaced charge detonated")
        advanceDemolitionCharges(seconds: 100)
        try require(placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true,
                    "Elapsed time automatically placed the initial charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x + tuning.range + 1, y: tower.position.y))
        try require(placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true
                    && !isPlacingDemolition, "Cancelled first placement consumed the ready charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: tower.position)
        guard let charge = placedTower(atSlot: slot)?.demolitionCharge, let position = charge.position else {
            throw NSError(domain: "DemolitionReview", code: 4)
        }
        try require(charge.isReady && charge.remainingSeconds == 0 && !charge.isReadyForPlacement,
                    "First placement started an unnecessary cooldown")
        try require(rallyFlagFlash == nil, "Placement marker covered the armed first charge")
        func enemy(_ id: Int, offset: Double, hp: Double = 1000) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: hp, hp: hp,
                bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: 0.6, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: position.x + offset, y: position.y + 12))
        }
        walkers = [enemy(0, offset: 0), enemy(1, offset: tuning.aoeRadius - 1),
                   enemy(2, offset: tuning.aoeRadius + 1), enemy(3, offset: 20, hp: 1)]
        updateCombat(gameDt: 3)
        try require(projectiles.isEmpty && artilleryImpacts.isEmpty && walkers.allSatisfy { $0.hp == $0.maxHP },
                    "Charge incorrectly used ordinary ranged targeting")
        let cash = money
        let expectedKillMoney = cash + Int((Double(walkers[3].bounty) * combatRules.killBountyMultiplier).rounded())
        try require(detonateDemolition(atSlot: slot), "Armed charge did not detonate")
        let center = walkers.first { $0.id == 0 }!
        let edge = walkers.first { $0.id == 1 }!
        let outside = walkers.first { $0.id == 2 }!
        try require(center.hp < 1000 && center.morale.value < 100 && edge.hp < 1000,
                    "Blast failed HP or morale damage inside its radius")
        try require(outside.hp == 1000 && outside.morale.value == 100,
                    "Blast damaged enemy beyond its independent radius")
        try require(!walkers.contains { $0.id == 3 } && money == expectedKillMoney,
                    "Blast kill did not pay its bounty exactly once")
        try require(artilleryImpacts.count == 1 && artilleryImpacts[0].isDemolition,
                    "Missing demolition effect")
        try require(!detonateDemolition(atSlot: slot) && artilleryImpacts.count == 1,
                    "Consumed charge detonated twice")
        let hitPointsAfterBlast = walkers.map(\.hp)
        advanceArtilleryImpacts(seconds: 0.8)
        try require(artilleryImpacts.count == 1,
                    "Demolition smoke was removed at the ordinary artillery lifetime")
        advanceArtilleryImpacts(seconds: DemolitionExplosion.duration - 0.8 + 0.001)
        try require(artilleryImpacts.isEmpty && walkers.map(\.hp) == hitPointsAfterBlast && money == expectedKillMoney,
                    "Explosion failed to expire or applied damage/rewards during animation")
        try require(placedTower(atSlot: slot)?.demolitionCharge?.remainingSeconds == 8,
                    "Next charge did not restart preparation")
        advanceDemolitionCharges(seconds: 8)
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x + tuning.range + 1, y: tower.position.y))
        try require(!isPlacingDemolition && selectedTowerSlotIndex == nil
                    && placedTower(atSlot: slot)?.demolitionCharge?.position == charge.position,
                    "Outside tap did not cancel placement without moving the charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        let requested = CGPoint(x: tower.position.x + tuning.range * 0.8, y: tower.position.y)
        placeDemolition(at: requested)
        guard let moved = placedTower(atSlot: slot)?.demolitionCharge, let movedPosition = moved.position else {
            throw NSError(domain: "DemolitionReview", code: 5)
        }
        try require(!isPlacingDemolition && tuning.attackRange.contains(movedPosition, from: tower.position),
                    "Placement escaped the displayed range")
        try require(rallyFlagFlash?.position == moved.position,
                    "Charge placement did not show its destination flag")
        try require(moved.position == charge.position || moved.remainingSeconds == 8,
                    "Relocation kept a ready charge")
        advanceDemolitionCharges(seconds: 8)
        isCleared = true
        try require(!detonateDemolition(atSlot: slot), "Charge fired after victory")
        isCleared = false; isDefeated = true
        try require(!detonateDemolition(atSlot: slot), "Charge fired after defeat")
        isDefeated = false
        return ["family": towerFamilyName(for: .special), "branches": [1, 2, 3], "preparationSeconds": 8, "upgradeCost": tuning.cost,
                "initialChargeReadyAndUnplaced": true, "firstPlacementImmediatelyArmed": true,
                "unplacedChargeCannotDetonate": true, "cancelledFirstPlacementKeepsReadyCharge": true,
                "placementRange": tuning.range, "blastRadius": tuning.aoeRadius,
                "usesSeparateTrigger": true, "duplicateDetonationProtected": true, "hpAndMoraleDamage": true,
                "bountyOnce": true, "placementUsesDisplayedRange": true,
                "outsideTapCancelsPlacement": true, "destinationFlagShown": true,
                "relocationRestartsPreparation": true, "blockedAfterGameEnd": true,
                "explosionExpires": true, "animationNeverRepeatsDamage": true]
    }

    func verifySiegeOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "SiegeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareTowerUpgradeReview(kind: .areaOfEffect)
        tapUpgradeButton(branch: 4); tapUpgradeButton(branch: 4)
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "SiegeReview", code: 2)
        }
        try require(tower.demolitionCharge == nil && tuning.demolitionPreparationSeconds == nil,
                    "Siege inherited a demolition charge")
        let origin = tower.position
        func enemy(_ id: Int, x: Double, y: Double = 0, hp: Double = 1000,
                   discipline: Double = 0.6) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: hp, hp: hp,
                bounty: 5, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: origin.x + x, y: origin.y + y + 12),
                pathDistance: Double(100 - id))
        }
        placedTowers[0].artilleryAim = ArtilleryAim(heading: 0, firingTolerance: combatRules.firingTolerance)
        walkers = [enemy(0, x: 60, hp: 1), enemy(1, x: 140),
                   enemy(2, x: 220, discipline: 1), enemy(3, x: 140, y: 60),
                   enemy(4, x: tuning.range + 1)]
        let cash = money
        let expectedKillMoney = cash + Int((Double(walkers[0].bounty) * combatRules.killBountyMultiplier).rounded())
        updateCombat(gameDt: 0.00001)
        try require(projectiles.count == 1 && projectiles[0].solidShot != nil
                    && projectiles[0].impactPoint == nil, "Siege did not launch one solid shot")
        let shotDamage = projectiles[0].damage
        let heading = projectiles[0].heading
        updateCombat(gameDt: 0.00001)
        try require(projectiles.count == 1, "Siege ignored its reload interval")
        updateProjectiles(gameDt: 0.13)
        try require(!walkers.contains(where: { $0.id == 0 }) && money == expectedKillMoney,
                    "First penetration failed to kill or pay its bounty once")
        try require(projectiles.count == 1, "Solid shot stopped when its target died")
        for _ in 0..<30 { updateProjectiles(gameDt: 0.01) }
        let middle = walkers.first { $0.id == 1 }!
        let disciplined = walkers.first { $0.id == 2 }!
        try require(abs(middle.hp - (1000 - shotDamage)) < 0.001
                    && abs(disciplined.hp - (1000 - shotDamage)) < 0.001,
                    "Shot failed to pierce multiple enemies or dealt repeated frame damage")
        try require(abs(middle.morale.value - (100 - tuning.terrorMax * 0.4)) < 0.001
                    && disciplined.morale.value == 100,
                    "Solid shot morale shock or discipline immunity failed")
        try require(projectiles.count == 1 && projectiles[0].heading == heading,
                    "Solid shot changed its launch bearing")
        updateProjectiles(gameDt: 10)
        try require(projectiles.isEmpty && artilleryImpacts.isEmpty,
                    "Solid shot travelled beyond its range or exploded like a shell")
        try require(walkers.filter { $0.id >= 3 }.allSatisfy { $0.hp == 1000 && $0.morale.value == 100 }
                    && money == expectedKillMoney, "Shot damaged an off-line/out-of-range enemy or duplicated bounty")
        try require(abs(damageTotalBySlot[slot, default: 0] - (1 + 2 * shotDamage)) < 0.001,
                    "Penetration damage was attributed incorrectly")

        walkers = [enemy(0, x: 80)]
        placedTowers[0].artilleryAim = ArtilleryAim(heading: 0, firingTolerance: combatRules.firingTolerance)
        nextFireTickBySlot = [:]
        updateCombat(gameDt: 0.00001)
        walkers[0].position.y += 90
        walkers.append(enemy(5, x: 130)); walkers.append(enemy(6, x: 260))
        updateProjectiles(gameDt: 10)
        try require(walkers[0].hp == 1000 && walkers.dropFirst().allSatisfy { $0.hp < 1000 }
                    && projectiles.isEmpty, "Shot homed or skipped enemies during a long frame")
        return ["level": 4, "branch": 4, "solidShot": true, "penetratesMultipleEnemies": true,
                "oneHitPerEnemy": true, "continuesAfterTargetDeath": true, "fixedBearing": true,
                "rangeLimited": true, "noSplashDamage": true, "bountyOnce": true,
                "reloadRespected": true, "moraleShockAndDisciplineVerified": true,
                "longFrameCollision": true, "damageAttributed": true]
    }

    func verifyArtilleryRangeOnDevice() throws -> [[String: Any]] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ArtilleryRangeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        let origin = CGPoint(x: playArea.midX, y: playArea.midY)
        func enemy(_ id: Int, at point: CGPoint) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: 0.6, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: point)
        }
        guard let levels = towerLevels[.areaOfEffect] else {
            throw NSError(domain: "ArtilleryRangeReview", code: 2)
        }
        var checks: [[String: Any]] = []
        defer {
            placedTowers = []
            walkers = []
            projectiles = []
            artilleryImpacts = []
            nextFireTickBySlot = [:]
            grapeshotHits = [:]
        }
        for level in levels.keys.sorted() {
            for branch in levels[level]!.keys.sorted() {
                let tuning = levels[level]![branch]!
                guard tuning.attackMode.firesProjectiles else { continue }
                let swivel = tuning.attackMode == .grapeshot
                let tower = PlacedTower(combatRules: combatRules, slotIndex: 0, kind: .areaOfEffect,
                                        position: origin, level: level, branch: branch)
                let overlayRadius = try { () throws -> CGFloat in
                    guard let radius = rangeOverlayRadius(for: tower) else {
                        throw NSError(domain: "ArtilleryRangeReview", code: 3)
                    }
                    return radius
                }()
                let ring = TowerRangeOverlay.size(range: overlayRadius, verticalFraction: combatRules.rangeVerticalFraction, runtimeCanvas: runtimeCanvas)
                let rx = ring.width / (2 * runtimeCanvas.scaleFactor)
                let ry = ring.height / (2 * runtimeCanvas.scaleFactor)
                func insideRing(_ point: CGPoint) -> Bool {
                    pow((point.x - origin.x) / rx, 2) + pow((point.y - origin.y) / ry, 2) <= 1 + 1e-9
                }
                func prepareShot(at point: CGPoint) {
                    walkers = [enemy(0, at: point)]
                    var aimed = tower
                    let target = tuning.attackRange.clamped(bodyPoint(walkers[0]), from: origin)
                    aimed.artilleryAim = ArtilleryAim(heading: atan2(target.y - origin.y, target.x - origin.x), firingTolerance: combatRules.firingTolerance)
                    placedTowers = [aimed]
                    projectiles = []
                    artilleryImpacts = []
                    grapeshotHits = [:]
                    nextFireTickBySlot = [:]
                }

                for degrees in stride(from: 0, to: 360, by: 15) {
                    let angle = Double(degrees) * .pi / 180
                    for factor in [0.999, 1.001] {
                        prepareShot(at: CGPoint(x: origin.x + cos(angle) * rx * factor,
                                                y: origin.y + sin(angle) * ry * factor))
                        updateCombat(gameDt: 0.00001)
                        try require(projectiles.count == (factor < 1 ? (swivel ? 5 : 1) : 0),
                                    "Wrong firing boundary at \(level)/\(branch), \(degrees) degrees, \(factor)")
                        for shot in projectiles {
                            try require(insideRing(shot.position), "Projectile escaped the ring")
                            if let aim = shot.impactPoint {
                                try require(insideRing(aim), "Shell aim escaped the ring")
                            }
                        }
                        updateProjectiles(gameDt: 10)
                        try require(artilleryImpacts.allSatisfy { insideRing($0.position) },
                                    "Impact body offset escaped the ring at \(level)/\(branch), \(degrees) degrees")
                    }
                }
                prepareShot(at: CGPoint(x: origin.x + rx * 0.98, y: origin.y + 12))
                updateCombat(gameDt: 0.00001)
                try require(!projectiles.isEmpty, "Missing moving-target test shot")
                if swivel || tuning.attackMode == .solidShot {

                    walkers = [enemy(1, at: CGPoint(x: origin.x + rx + 1, y: origin.y + 12))]
                    for _ in 0..<200 {
                        updateProjectiles(gameDt: 0.01)
                        try require(projectiles.allSatisfy { insideRing($0.position) },
                                    "Swivel pellet travelled outside its range")
                    }
                    try require(projectiles.isEmpty && walkers[0].hp == 1000,
                                "Swivel hit an enemy outside its range")
                } else {
                    let aim = projectiles[0].impactPoint!

                    walkers[0].position = CGPoint(x: origin.x + rx * 4, y: origin.y)
                    let splashOnly = CGPoint(x: aim.x + tuning.aoeRadius / 2, y: aim.y + 12)
                    try require(!insideRing(splashOnly), "Invalid splash-only test fixture")
                    walkers.append(enemy(1, at: splashOnly))
                    walkers.append(enemy(2, at: CGPoint(x: aim.x + tuning.aoeRadius + 1, y: aim.y + 12)))
                    updateProjectiles(gameDt: 10)
                    try require(projectiles.isEmpty && artilleryImpacts.count == 1,
                                "Shell failed to land after its target left range")
                    try require(artilleryImpacts[0].position == aim && insideRing(aim),
                                "Shell chased the target beyond its launch-time aim")
                    try require(walkers[0].hp == 1000 && walkers[1].hp < 1000
                                && walkers[1].morale.value < 100 && walkers[2].hp == 1000,
                                "Blast radius was tied to firing range")
                    prepareShot(at: CGPoint(x: origin.x + rx / 2, y: origin.y))
                    updateCombat(gameDt: 0.00001)
                    walkers = []
                    updateCombat(gameDt: 10)
                    try require(artilleryImpacts.count == 1, "Shell vanished when its target died")
                }
                checks.append(["level": level, "branch": branch, "range": tuning.range,
                    "aoeRadius": tuning.aoeRadius, "overlayWidth": ring.width, "overlayHeight": ring.height,
                    "boundaryCases": 48, "projectilesStayInRange": true,
                    "blastIndependentOfRange": true, "swivel": swivel])
            }
        }
        try require(checks.count == 6, "Expected six automatic artillery tiers/branches")
        return checks
    }

    func verifyArtilleryMoraleOnDevice() throws -> (walkers: [Walker], checks: [[String: Any]]) {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ArtilleryMoraleReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        let center = CGPoint(x: playArea.midX, y: playArea.midY)
        func enemy(_ id: Int, x: Double, y: Double = 0, discipline: Double = 0.6) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, livesCost: reviewEnemyStats.livesCost, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: discipline, moraleResponse: reviewEnemyStats.moraleResponse, morale: EnemyMorale(rules: combatRules), position: CGPoint(x: center.x + x, y: center.y + y + 12))
        }
        var checks: [[String: Any]] = []
        placedTowers = []
        guard let levels = towerLevels[.areaOfEffect] else {
            throw NSError(domain: "ArtilleryMoraleReview", code: 2)
        }
        for level in levels.keys.sorted() {
            for branch in levels[level]!.keys.sorted() {
                let tuning = levels[level]![branch]!
                guard tuning.attackMode.firesProjectiles else { continue }
                if tuning.attackMode == .solidShot {
                    let result = try verifySiegeOnDevice()
                    checks.append(result)
                    placedTowers = []
                    continue
                }
                try require(tuning.terrorMax > tuning.terrorMin && tuning.terrorMin > 0,
                            "Missing artillery morale tuning at \(level)/\(branch)")
                walkers = [enemy(0, x: 0), enemy(1, x: 40, y: 25),
                           enemy(2, x: max(100, tuning.aoeRadius + 1)),
                           enemy(3, x: 20, discipline: 1),
                           enemy(4, x: max(100, tuning.aoeRadius * 0.9)),
                           enemy(5, x: max(100, tuning.aoeRadius - 0.01))]
                artilleryImpacts = []
                let shot = Projectile(id: 0, kind: .areaOfEffect,
                    position: CGPoint(x: center.x - 10, y: center.y), heading: 0,
                    damage: 12, targetID: 0, slotIndex: 0, speed: 640,
                    splashRadius: CGFloat(tuning.aoeRadius),
                    splashCoverPierce: tuning.splashCoverPierce,
                    moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
                if tuning.attackMode == .grapeshot {
                    grapeshotHits = [:]
                    projectiles = (0..<3).map { index in
                        var pellet = shot
                        pellet = Projectile(id: index, kind: pellet.kind, position: pellet.position,
                            heading: 0, damage: pellet.damage, targetID: 0, slotIndex: 0,
                            speed: pellet.speed, splashRadius: 0,
                            firingBoundary: tuning.attackRange, firingOrigin: pellet.position,
                            moraleStrike: pellet.moraleStrike,
                            grapeshot: GrapeshotFlight(volleyID: 0, range: 100))
                        return pellet
                    }
                    updateCombat(gameDt: 0.03)
                    try require(abs(walkers[0].morale.value - (100 - tuning.terrorMax * 0.4)) < 0.001,
                                "Grapeshot must not stack morale loss per pellet")
                    try require(walkers[1].morale.value == 100, "Grapeshot shocked an unhit neighbor")
                } else {
                    applyImpact(shot, at: center)
                    try require(walkers[1].morale.value < 100, "Shell missed the nearby morale target")
                    try require(walkers[4].hp < walkers[4].maxHP && walkers[4].morale.value < 100,
                                "Shell missed HP or morale damage in the outer blast area")
                    try require(walkers[5].hp < walkers[5].maxHP && walkers[5].morale.value < 100,
                                "Shell missed HP or morale damage just inside the blast boundary")
                }
                try require(walkers[0].morale.isVisible, "Direct artillery hit did not reveal morale")
                try require(walkers[2].morale.value == 100, "Morale loss outside impact radius")
                try require(walkers[2].hp == walkers[2].maxHP, "HP damage outside impact radius")
                try require(walkers[3].morale.value == 100, "Discipline immunity ignored")
                try require(artilleryImpacts.count == 1, "Expected one shared impact effect")
                checks.append(["level": level, "branch": branch,
                    "aoeRadius": tuning.aoeRadius, "outerProbeDistance": max(100, tuning.aoeRadius * 0.9),
                    "hp": walkers.map { $0.hp },
                    "morale": walkers.map { $0.morale.value }, "impactCount": artilleryImpacts.count])
            }
        }
        try require(checks.count == 6, "Expected six automatic artillery tiers/branches")
        let tuning = levels[1]![1]!
        var display: [Walker] = []
        for count in 0..<7 {
            walkers = [enemy(count, x: 0)]
            let shot = Projectile(id: count, kind: .areaOfEffect, position: center, heading: 0,
                damage: 12, targetID: count, slotIndex: 0, speed: 320,
                splashRadius: CGFloat(tuning.aoeRadius), splashCoverPierce: tuning.splashCoverPierce,
                moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
            for _ in 0..<count { applyImpact(shot, at: center) }
            walkers[0].morale.advance(seconds: 0.8)
            try require(abs(walkers[0].morale.displayedFraction - walkers[0].morale.value / 100) < 0.001,
                        "Level 1 displayed morale must settle at its remaining value")
            display.append(walkers[0])
        }
        return (display, checks)
    }

    func applyLevelOneReviewImpact(to targets: [Walker]) throws -> [Walker] {
        guard let tuning = towerLevels[.areaOfEffect]?[1]?[1] else {
            throw NSError(domain: "ArtilleryMoraleReview", code: 3)
        }
        let center = CGPoint(x: playArea.midX, y: playArea.midY)
        walkers = targets
        let shot = Projectile(id: 100, kind: .areaOfEffect, position: center, heading: 0,
            damage: 12, targetID: targets.first?.id ?? 0, slotIndex: 0, speed: 320,
            splashRadius: CGFloat(tuning.aoeRadius), splashCoverPierce: tuning.splashCoverPierce,
            moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
        applyImpact(shot, at: center)
        return walkers
    }
}
#endif
