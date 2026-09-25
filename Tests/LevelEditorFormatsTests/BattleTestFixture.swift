import XCTest
@testable import LevelEditorFormats

/// Complete in-memory fixtures around the real battle engine. No combat is
/// implemented here, and the authored database is never modified.
enum BattleTestFixture {
    static func authored(db: Db? = nil) throws -> BattleContent {
        if let db { return try BattleContent(db: db, levelID: XCTUnwrap(db.levelInfoDao.getIdBy(levelName: "Charleston"))) }
        let url = Db.authoredDatabaseURL
        let connection = Db(dbPath: url.path, fullRefresh: false,
                            levelGeoJSONDao: LevelGeoJSONDAO(directory: url.deletingLastPathComponent()))
        defer { connection.close() }
        return try authored(db: connection)
    }

    struct Tier: Hashable {
        let kind: TowerKind
        let level: Int
        let branch: Int
        init(_ kind: TowerKind, _ level: Int, _ branch: Int = 1) {
            self.kind = kind; self.level = level; self.branch = branch
        }
    }

    static func content(level: LevelInfo, enemies: [EnemyType],
                        tiers: [Tier: TowerLevel] = [:], base: BattleContent? = nil) throws -> BattleContent {
        let source = try base ?? authored()
        let definitions = source.arsenal.towers.map { tower in
            DesignArsenal.Definition(id: tower.id, kind: tower.kind, category: tower.category, name: tower.name,
                tiers: tower.tiers.map { tier in
                    DesignArsenal.Tier(id: tier.id, level: tier.level, branch: tier.branch, details: tier.details,
                        history: tier.history,
                        tuning: tiers[Tier(tower.kind, tier.level, tier.branch)] ?? tier.tuning)
                })
        }
        var ledger = source.playerUpgrades.bestStarsByLevel
        ledger[level.id] = 0
        return try BattleContent(level: level, playSpeeds: source.playSpeeds, virtualCanvas: source.virtualCanvas,
            arsenal: DesignArsenal(towers: definitions, combatRules: source.arsenal.combatRules),
            enemies: enemies, unlocks: source.unlocks, reinforcementConfig: source.reinforcementConfig,
            chosenHeroes: source.chosenHeroes, deployments: [], heroCombat: source.heroCombat,
            heroAI: source.heroAI, heroControls: source.heroControls,
            // Synthetic paths do not retain Charleston's route IDs. Give the
            // fixture explicit level-wide controls at its authored positions.
            movementArea: source.movementArea,
            callButtons: source.callButtons.map { CallWaveButtonPosition(position: $0.position) }, exits: source.exits,
            difficulty: Difficulty(id: source.difficulty.id, level: source.difficulty.level, name: source.difficulty.name,
                detail: source.difficulty.detail, enemyHPMultiplier: 1),
            playerUpgrades: PlayerMetaUpgradeState(catalog: source.playerUpgrades.loadout.catalog,
                selected: [], bestStarsByLevel: ledger))
    }

    static func level(enemy: EnemyType, slots: [Point], starts: [Point] = [Point(0, 0)],
                      money: Int = 100_000, waveTimes: [Double] = [0]) -> LevelInfo {
        LevelInfo(id: UUID(), name: "Battle fixture", campaign: Campaign(id: UUID(), name: "Test"),
            startedAt: Date(), endedAt: Date(), startingMoney: money, numStartingLives: 100,
            numWaves: waveTimes.count, playArea: CGRect(x: -1000, y: -1000, width: 6000, height: 3000),
            paths: starts.map { Path(points: [$0, Point($0.x + 4000, $0.y)]) },
            towerSlots: slots.map { TowerSlot(id: UUID(), position: $0) },
            waves: waveTimes.enumerated().map { index, time in
                Wave(startTime: time, spawns: starts.indices.map {
                    SpawnEntry(enemyTypeID: enemy.id, count: 1, interval: 1, pathIndex: $0)
                }, callButtonDelay: index == 0 ? 0 : time - waveTimes[index - 1],
                     autoStartCountdown: 0, earlyCallBonus: 0)
            })
    }

    @MainActor static func build(_ kind: TowerKind, level: Int = 1, branch: Int = 1,
                                 slot: Int = 0, in sim: GameSimulation) throws {
        XCTAssertEqual(sim.perform(.build(slot: slot, kind: kind)), .ok)
        if level > 1 {
            for next in 2...level {
                XCTAssertEqual(sim.perform(.upgrade(slot: slot, branch: next == level ? branch : 1)), .ok)
            }
        }
    }
}
