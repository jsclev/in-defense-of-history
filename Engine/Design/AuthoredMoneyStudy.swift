import Foundation

/// A money experiment retains the authored map, spawn schedule and tower tuning.
/// Its alternative catalogs describe legal upgrade paths, including every final
/// branch; choosing a path never changes the cost or stats of a shared lower tier.
public struct AuthoredMoneyStudy {
    public struct TowerPath: Sendable {
        public let kind: TowerKind
        public let tierIDs: [UUID]
        public let type: TowerType
    }

    public let level: LevelInfo
    public let arsenal: DesignArsenal
    public let towerPaths: [TowerPath]
    public let catalog: ContentCatalog
    public let difficulty: Difficulty
    public let battle: BattleContent

    public init(db: Db, levelID: UUID) throws {
        try self.init(battle: BattleContent(db: db, levelID: levelID))
    }

    public func selectingMetaUpgrades(_ selected: Set<MetaUpgrade>) throws -> Self {
        try Self(battle: battle.selectingMetaUpgrades(selected))
    }

    private init(battle: BattleContent) throws {
        self.battle = battle
        level = battle.level
        let levelID = level.id
        guard !level.paths.isEmpty, !level.towerSlots.isEmpty, !level.waves.isEmpty else {
            throw DbError.Db(message: "level_info[\(levelID)]: money study requires paths, tower slots and authored waves")
        }
        guard level.waves.count == level.numWaves else {
            throw DbError.Db(message: "level_info[\(levelID)]: num_waves disagrees with level_wave")
        }
        let selected = battle.difficulty
        difficulty = selected
        arsenal = battle.arsenal
        let unlocks = battle.unlocks
        var paths: [TowerPath] = []
        for definition in arsenal.towers {
            guard let maximum = unlocks[definition.kind] else {
                throw DbError.Db(message: "level_tower_unlock[\(levelID)]: missing \(definition.kind.rawValue)")
            }
            guard maximum > 0 else { continue }
            let finalTiers = definition.tiers.filter { $0.level == maximum }
            guard !finalTiers.isEmpty else {
                throw DbError.Db(message: "tower[\(definition.id)]: missing unlocked tier \(maximum)")
            }
            for finalTier in finalTiers {
                var tiers: [DesignArsenal.Tier] = []
                for number in 1..<maximum {
                    let candidates = definition.tiers.filter { $0.level == number }
                    guard candidates.count == 1, let tier = candidates.first else {
                        throw DbError.Db(message: "tower[\(definition.id)]: level \(number) needs an unambiguous predecessor")
                    }
                    tiers.append(tier)
                }
                tiers.append(finalTier)
                paths.append(TowerPath(kind: definition.kind, tierIDs: tiers.map(\.id),
                    type: TowerType(id: finalTier.id, name: finalTier.details.name, levels: tiers.map(\.tuning))))
            }
        }
        guard !paths.isEmpty else {
            throw DbError.Db(message: "level_tower_unlock[\(levelID)]: money study has no unlocked towers")
        }
        towerPaths = paths
        catalog = ContentCatalog(combatRules: arsenal.combatRules, enemyTypes: battle.enemies,
                                 towerTypes: paths.map(\.type))
    }

    /// Experimental money exists only in this in-memory level. Campaign entry
    /// and the database's starting_money continue to use LevelInfoDAO unchanged.
    public func level(startingMoney: Int) -> LevelInfo {
        precondition(startingMoney > 0)
        return LevelInfo(id: level.id, name: level.name, campaign: level.campaign,
            startedAt: level.startedAt, endedAt: level.endedAt,
            startingMoney: startingMoney, numStartingLives: level.numStartingLives,
            numWaves: level.numWaves, playArea: level.playArea, mapImageName: level.mapImageName,
            paths: level.paths, towerSlots: level.towerSlots, waves: level.waves)
    }
}

/// Paired study dimensions, separate from authored combat attributes. A plan and
/// combat seed keep the same identity at every starting-money value.
public struct MoneyStudyGrid: Sendable, Equatable {
    public let money: [Int]
    public let placementPlans: Int
    public let upgradePolicies: Int
    public let combatSeeds: Int
    public var strategyCount: Int { placementPlans * upgradePolicies }
    public var runCount: Int { money.count * strategyCount * combatSeeds }

    public init(minimum: Int, maximum: Int, step: Int,
                placementPlans: Int, upgradePolicies: Int, combatSeeds: Int) throws {
        guard minimum > 0, maximum >= minimum, step > 0,
              (maximum - minimum) % step == 0,
              placementPlans > 0, upgradePolicies > 0, combatSeeds > 0 else {
            throw DbError.Db(message: "money study: invalid budget range or sample counts")
        }
        let count = (maximum - minimum) / step + 1
        var total = count
        for factor in [placementPlans, upgradePolicies, combatSeeds] {
            let product = total.multipliedReportingOverflow(by: factor)
            guard !product.overflow else { throw DbError.Db(message: "money study: run count overflows Int") }
            total = product.partialValue
        }
        self.money = Array(stride(from: minimum, through: maximum, by: step))
        self.placementPlans = placementPlans
        self.upgradePolicies = upgradePolicies
        self.combatSeeds = combatSeeds
    }
}
