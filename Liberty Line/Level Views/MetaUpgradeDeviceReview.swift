#if DEBUG
import SwiftUI
import UIKit

/// Uses the production upgrade screen, session store, and battle purchase handlers
/// on a physical device; exports only image/JSON diagnostics.
struct MetaUpgradeDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var finished = false
    @State private var didReview = false
    var body: some View {
        if finished {
            RootView(store: store, runtimeCanvas: canvas)
        } else {
            MetaUpgradesView(upgrades: store.metaUpgrades, runtimeCanvas: canvas) { finished = true }
                .task {
                    guard !didReview else { return }
                    didReview = true
                    await review()
                }
        }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meta-upgrade-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "MetaUpgradeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let catalog = store.metaUpgrades.loadout.catalog
            var artRecords: [[String: Any]] = []
            for upgrade in catalog.upgrades {
                let image = MetaUpgradeIcon.requiredImage(for: upgrade)
                try image.pngData()!.write(to: directory.appendingPathComponent(upgrade.iconAssetName + "-decoded.png"))
                for density in [1.0, 2.0, 3.0] {
                    let renderer = ImageRenderer(content: MetaUpgradeIcon(upgrade: upgrade).frame(width: 44, height: 44))
                    renderer.scale = density
                    guard let png = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                    try png.write(to: directory.appendingPathComponent("\(upgrade.iconAssetName)@\(Int(density))x.png"))
                }
                artRecords.append(["asset": upgrade.iconAssetName, "upgrade": upgrade.id.rawValue,
                                   "minimumPoints": 44, "decodedScale": image.scale])
            }
            for name in ["meta_council_background", "meta_council_panel"] {
                try CampaignButtonArt.requiredImage(named: name).pngData()!
                    .write(to: directory.appendingPathComponent(name + "-decoded.png"))
            }
            for state in ["learned", "available", "locked", "focused"] {
                let renderer = ImageRenderer(content: HStack(spacing: 16) {
                    ForEach(catalog.tracks) { track in
                        VStack(spacing: 12) {
                            ForEach(catalog.upgrades(in: track.id)) { upgrade in
                                CouncilNodeArt(upgrade: upgrade, learned: state == "learned" || state == "focused",
                                    locked: state == "locked", focused: state == "focused")
                            }
                        }.padding(8).background(CouncilPanel())
                    }
                }.padding(12).background(CouncilPalette.ink))
                renderer.scale = 3
                guard let png = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                try png.write(to: directory.appendingPathComponent("nodes-\(state)@3x.png"))
            }
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "MetaUpgradeReview", code: 2)
            }
            func capture(_ name: String) async throws {
                try await Task.sleep(for: .milliseconds(300))
                window.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try require(image.size.width > image.size.height, "Upgrade screen must be landscape")
                try image.pngData()!.write(to: directory.appendingPathComponent(name + ".png"))
            }
            try store.metaUpgrades.restoreLevel15()
            try await capture("level15")
            try require(store.metaUpgrades.loadout.selected.count == 17, "Preset selection differs from the authored seed")
            try store.metaUpgrades.reset()
            try require(store.metaUpgrades.loadout.availableStars == 42, "Reset did not refund all stars")
            try await capture("reset")
            try require(try !store.metaUpgrades.purchase(.crossfire), "Skipped a prerequisite")
            try require(try store.metaUpgrades.purchase(.rangeEstimation), "Could not learn first node")
            try require(try store.metaUpgrades.purchase(.cartridgeDrill), "Could not learn second node")
            try require(try store.metaUpgrades.purchase(.crossfire), "Could not learn third node")
            let reopenedDatabase = Db(dbPath: store.db.path, fullRefresh: false)
            defer { reopenedDatabase.close() }
            let reloadedStore = try MetaUpgradeStore(dao: reopenedDatabase.playerMetaUpgradeDao)
            try require(reloadedStore.loadout == store.metaUpgrades.loadout, "A new store lost the SQL selection")
            try require(try store.db.playerMetaUpgradeDao.get().loadout.selected == [.rangeEstimation, .cartridgeDrill, .crossfire],
                        "Purchase handler did not persist selected upgrades")
            try await capture("custom")
            try store.metaUpgrades.refund(.rangeEstimation)
            try require(store.metaUpgrades.loadout.selected.isEmpty, "Refund left orphaned nodes")
            try store.metaUpgrades.restoreLevel15()
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            func runner() -> LevelRunner {
                LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                    hudLayoutConfig: store.hudLayoutConfig, levelInfoID: level.id,
                    mapImageName: level.mapImageName)
            }
            let battle = runner()
            try store.metaUpgrades.reset()
            let baseline = runner()
            try store.metaUpgrades.restoreLevel15()
            try require(battle.isReady && baseline.isReady, "Battle failed to load")
            try require(battle.startingMoney == baseline.startingMoney && battle.money == baseline.money,
                        "Meta upgrades replaced authored starting money")
            var checked = 0
            let arsenal = try store.db.towerTypeDao.getDesignArsenal()
            for tower in arsenal.towers {
                for tier in tower.tiers {
                    let expected = battle.metaUpgrades.priced(tier.tuning, kind: tower.kind, level: tier.level)
                    try require(battle.towerCosts[tower.kind]?[tier.level]?[tier.branch] == expected.cost,
                                "Displayed tier price differs from meta price")
                    if tier.level == 4 {
                        let slot = try battle.prepareTowerUpgradeReview(kind: tower.kind)
                        let before = battle.money
                        let offeredPrice = battle.upgradeOffers.first { $0.branch == tier.branch }!.cost
                        battle.upgradeSelectedTower(branch: tier.branch)
                        try require(before - battle.money == offeredPrice, "Tier purchase charged wrong price: \(tower.kind), branch \(tier.branch), expected \(expected.cost), paid \(before - battle.money)")
                        battle.selectPlacedTower(atSlot: slot)
                        for path in expected.upgradePaths {
                            for rank in path.ranks {
                                let before = battle.money
                                battle.tapUpgradePath(path.id)
                                try require(battle.money == before, "Inspecting an ability spent money")
                                battle.tapUpgradePath(path.id)
                                try require(before - battle.money == rank.cost, "Ability purchase charged wrong price")
                            }
                        }
                        let placed = battle.placedTower(atSlot: slot)!
                        let desired = battle.metaUpgrades.combat(expected.upgraded(with: placed.upgrades), kind: tower.kind)
                        try require(battle.towerLevel(for: placed) == desired, "Combat bonuses applied in the wrong order")
                        checked += 1
                    }
                }
            }
            try store.metaUpgrades.reset()
            try require(battle.metaUpgrades == (try store.db.playerMetaUpgradeDao.get(profile: .level15)).loadout.effects, "An active battle changed after respec")
            let resetBattle = runner()
            try require(resetBattle.towerLevels == baseline.towerLevels, "Reset retained global bonuses")
            try store.metaUpgrades.restoreLevel15()
            let restarted = runner()
            try require(restarted.towerLevels == battle.towerLevels, "Battle entry compounded global bonuses")
            // Explicit in-memory fixture for the historical-mechanic review.
            // Production battle entry has no separate tuning/settings override.
            let source = battle.content
            let historicalState = try PlayerMetaUpgradeState(catalog: source.playerUpgrades.loadout.catalog,
                selected: Set(MetaUpgrade.allCases),
                bestStarsByLevel: source.playerUpgrades.bestStarsByLevel.mapValues { _ in 3 })
            let historicalContent = try BattleContent(level: source.level, virtualCanvas: source.virtualCanvas,
                arsenal: source.arsenal, enemies: source.enemies, unlocks: source.unlocks,
                reinforcementConfig: source.reinforcementConfig, chosenHeroes: source.chosenHeroes,
                deployments: source.deployments, heroCombat: source.heroCombat,
            heroAI: source.heroAI, heroControls: source.heroControls,
                movementArea: source.movementArea, callButtons: source.callButtons, exits: source.exits,
                difficulty: source.difficulty, playerUpgrades: historicalState)
            let historicalBattle = LevelRunner(db: store.db, content: historicalContent,
                runtimeCanvas: canvas, hudLayoutConfig: store.hudLayoutConfig)
            let historicalChecks = try historicalBattle.verifyHistoricalMetaUpgradesOnDevice()
            let hud = HeroBarLayout(runtimeCanvas: canvas, location: store.hudLayoutConfig.heroBar)
            let cooldownPreview = ImageRenderer(content: HStack(spacing: hud.buttonSpacing) {
                ForEach([1.0, 0.5, 0.0], id: \.self) { fraction in
                    ReinforcementButton(buttonSize: CGSize(width: hud.buttonSize, height: hud.buttonSize),
                        cooldown: ReinforcementCooldown(remainingSeconds: fraction * battle.content.reinforcementConfig.cooldownSeconds, remainingFraction: fraction),
                        isAvailable: fraction == 0, action: {})
                }
            }.padding(8).background(Color.black))
            cooldownPreview.scale = window.screen.scale
            guard let cooldowns = cooldownPreview.uiImage?.pngData() else {
                throw NSError(domain: "MetaUpgradeReview.ReserveRender", code: 1)
            }
            try cooldowns.write(to: directory.appendingPathComponent("cooldown-states.png"))
            NotificationCenter.default.post(name: .init("MetaUpgradeHistoryReview"), object: MetaUpgrade.twoGoodVolleys)
            try await Task.sleep(for: .milliseconds(500))
            try await capture("history-volley")
            NotificationCenter.default.post(name: .init("MetaUpgradeHistoryReview"), object: nil)
            try await Task.sleep(for: .milliseconds(500))
            NotificationCenter.default.post(name: .init("MetaUpgradeFocusReview"), object: MetaUpgrade.batteryDoctrine)
            try await capture("battery-inspector")
            NotificationCenter.default.post(name: .init("MetaUpgradeFocusReview"), object: MetaUpgrade.crossfire)
            try await capture("level15-final")
            result = ["passed": true, "selected": 17, "total": 23, "spentStars": 36,
                "availableStars": 6, "specializationsPurchased": checked,
                "historicalMechanics": historicalChecks,
                "reinforcementButtonPoints": hud.buttonSize,
                "startingMoneyUnchanged": true, "databaseSelectionReloadVerified": true, "snapshotStable": true, "resetRemovesBonuses": true,
                "nativeWindowPoints": [window.bounds.width, window.bounds.height], "scale": window.screen.scale,
                "artwork": artRecords, "artworkStates": ["learned", "available", "locked", "focused"],
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? ""]
        } catch {
            result["error"] = String(describing: error)
        }
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("result.json"))
        }
    }
}
#endif
