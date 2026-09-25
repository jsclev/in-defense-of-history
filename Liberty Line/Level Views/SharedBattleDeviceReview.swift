#if DEBUG
import SwiftUI

/// Device verification of the actual UI adapter against headless command input.
struct SharedBattleDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var runner: LevelRunner?
    @State private var node: CampaignNode?

    var body: some View {
        Group {
            if let runner, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node,
                    hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            } else { Color.black }
        }.task { await verify() }
    }

    @MainActor private func verify() async {
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shared-engine-review.json")
        var report: [String: Any] = ["passed": false]
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "SharedBattleReview", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        do {
            guard let id = try store.db.levelInfoDao.getIdBy(levelName: "Charleston") else {
                throw DbError.Db(message: "Missing Charleston for shared battle verification")
            }
            // Exercise AI through the same live SQLite-backed settings as the
            // pause screen, before both adapters load their battle snapshots.
            let originalControls = store.settings.heroControls
            defer {
                for control in originalControls {
                    do { try store.settings.setHeroAIEnabled(control.aiEnabled, heroID: control.id) }
                    catch { fatalError("Unable to restore review hero controls: \(error)") }
                }
            }
            for id in try store.db.heroDao.getSelectedHeroIds() {
                try store.settings.setHeroAIEnabled(true, heroID: id)
            }
            let content = try BattleContent(db: store.db, levelID: id)
            let player = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, hudLayoutConfig: store.hudLayoutConfig, levelInfoID: id,
                mapImageName: content.level.mapImageName)
            player.random = SeededRNG(seed: 1776)
            let headless = try GameSimulation(recording: .database(store.db.levelRunDao, .simulator), content: content, startingMoney: nil, heroesEnabled: true, seed: 1776)
            self.runner = player
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first { $0.id == id }!
            self.node = CampaignNode(order: 15, level: level)
            for (slot, kind) in [(17, TowerKind.ranged), (5, .ranged), (11, .ranged),
                                 (4, .melee), (14, .areaOfEffect), (0, .supply)] {
                let definition = content.arsenal.towers.first { $0.kind == kind }!
                let tier = definition.tiers.first { $0.level == content.unlocks[kind] }!
                try require(headless.build(slot: slot, towerID: tier.id) == .ok, "Headless opening purchase failed")
                player.selectSlot(slot); player.tapBuildButton(kind); player.tapBuildButton(kind)
                try require(player.money == headless.gold && player.placedTowers.count == headless.engine.placedTowers.count,
                            "Player and headless opening purchases differ")
            }
            player.startNextWave(); headless.startNextWave()
            func requireParity() throws {
                try require(player.money == headless.gold && player.lives == headless.lives,
                            "Money or lives diverged")
                try require(player.walkers.map(\.hp) == headless.engine.walkers.map(\.hp)
                    && player.walkers.map(\.pathDistance) == headless.engine.walkers.map(\.pathDistance)
                    && player.walkers.map { $0.morale.value } == headless.engine.walkers.map { $0.morale.value },
                    "Enemy damage, movement or morale diverged")
                try require(player.heroPosts.map { $0.unit.position } == headless.engine.heroPosts.map { $0.unit.position }
                    && player.heroPosts.map { $0.unit.hp } == headless.engine.heroPosts.map { $0.unit.hp },
                    "Hero movement or health diverged")
                try require(player.shotsByMode == headless.shotsByMode
                    && player.killedCount == headless.engine.killedCount
                    && player.goldEarned == headless.engine.goldEarned, "Attacks or rewards diverged")
            }
            let starts = Dictionary(uniqueKeysWithValues: player.heroPosts.map { ($0.hero.id, $0.unit.position) })
            var movedHeroes = Set<UUID>()
            for block in 0..<225 {
                if block % 2 == 0 {
                    for _ in 0..<4 {
                        player.advance(ticks: 0, interpolation: 0.5)
                        player.advance(ticks: 1, interpolation: 0)
                    }
                } else { player.advance(ticks: 4, interpolation: 0.75) }
                for _ in 0..<4 { headless.step() }
                try requireParity()
                for post in player.heroPosts where starts[post.hero.id] != post.unit.position {
                    movedHeroes.insert(post.hero.id)
                }
            }
            try require(movedHeroes == Set(starts.keys), "An enabled hero never moved under AI control")
            let before = player.timer.tick
            player.start()
            try await Task.sleep(for: .seconds(2))
            player.pause()
            try require(player.timer.tick > before, "Native display clock did not advance the shared battle engine")
            while headless.engine.timer.tick < player.timer.tick { headless.step() }
            try requireParity()
            let pausedTick = player.timer.tick
            if let hero = player.heroPosts.first {
                try store.settings.setHeroAIEnabled(false, heroID: hero.hero.id)
                try require(headless.perform(.setHeroAI(id: hero.hero.id, enabled: false)) == .ok,
                            "Headless AI disable failed")
                try require(player.heroAIEnabled[hero.hero.id] == false, "Live settings did not disable hero AI")
                try requireParity()
                try store.settings.setHeroAIEnabled(true, heroID: hero.hero.id)
                try require(headless.perform(.setHeroAI(id: hero.hero.id, enabled: true)) == .ok,
                            "Headless AI enable failed")
                try require(player.heroAIEnabled[hero.hero.id] == true, "Live settings did not enable hero AI")
            }
            try await Task.sleep(for: .milliseconds(250))
            try require(player.timer.tick == pausedTick, "Paused display clock advanced")
            player.resume(); player.speedUp(); player.start()
            try await Task.sleep(for: .seconds(1))
            player.pause()
            try require(player.timer.tick > pausedTick, "Native display clock did not resume")
            while headless.engine.timer.tick < player.timer.tick { headless.step() }
            try requireParity()
            report = ["passed": true, "matchedTicks": player.timer.tick, "startingMoney": content.level.startingMoney,
                "difficulty": content.difficulty.name, "heroes": true,
                "heroAI": true, "liveHeroAISettingsWhilePaused": true,
                "heroesMovedUnderAI": player.heroPosts.filter { movedHeroes.contains($0.hero.id) }.map { $0.hero.shortName },
                "selectedCampaignUpgrades": content.playerUpgrades.loadout.selected.map(\.rawValue).sorted(),
                "matchedDamageMovementMoraleMoneyLivesRewards": true,
                "nativeDisplayClockAdvanced": player.timer.tick > before,
                "nativeDisplayClockReplayMatched": true, "pauseResumeAndSpeedChangeMatched": true,
                "fractionalAndBatchedFramesMatched": true,
                "nativeGameTick": player.timer.tick, "matchedKills": headless.engine.killedCount]
        } catch { report["error"] = String(describing: error) }
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "--review-id"), arguments.indices.contains(flag + 1) {
            report["reviewID"] = arguments[flag + 1]
        }
        report["completedAt"] = ISO8601DateFormatter().string(from: Date())
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output, options: .atomic)
        } catch { print("Unable to save shared battle device verification: \(error)") }
    }
}
#endif
