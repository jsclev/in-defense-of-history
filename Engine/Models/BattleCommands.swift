import Foundation

public enum BuildResult: Sendable, Equatable {
    case ok
    case needGold
    case invalid
}

/// Player intent only. The battle engine owns validation and every side effect.
public enum BattleCommand: Sendable {
    case build(slot: Int, kind: TowerKind)
    case upgrade(slot: Int, branch: Int)
    case purchaseUpgrade(slot: Int, pathID: String)
    case placeDemolition(slot: Int, point: Point)
    case placeObstacles(slot: Int, point: Point)
    case rally(slot: Int, point: Point)
    case moveHero(id: UUID, point: Point)
    case reinforcements(point: Point)
    case startWave
}

public struct BattleTowerSnapshot {
    public let slot: Int
    public let kind: TowerKind
    public let level: Int
    public let branch: Int
    public let name: String
    public let position: Point
    public let tuning: TowerLevel
    public let damage: Double
    public let upgrades: TowerUpgradeProgress
}

public struct BattleEnemySnapshot {
    public let id: Int
    public let typeID: UUID
    public let position: Point
    public let hp: Double
    public let maxHP: Double
    public let morale: Double
    public let livesCost: Int
}

extension BattleEngine {
    public var elapsedTime: Double { Double(outcomeTick ?? timer.tick) * SimClock.dt }
    public var outcome: Outcome? { isDefeated ? .defeat : isCleared ? .victory : nil }

    /// This entry point invokes the same handlers as the interactive controls.
    @discardableResult
    public func perform(_ command: BattleCommand) -> BuildResult {
        guard acceptsPlayerInput else { return .invalid }
        switch command {
        case let .build(slot, kind):
            dismissMenu()
            selectSlot(slot)
            tapBuildButton(kind)
            return tapBuildButton(kind) ?? .invalid
        case let .upgrade(slot, branch):
            dismissMenu()
            selectPlacedTower(atSlot: slot)
            tapUpgradeButton(branch: branch)
            return tapUpgradeButton(branch: branch) ?? .invalid
        case let .purchaseUpgrade(slot, pathID):
            dismissMenu()
            selectPlacedTower(atSlot: slot)
            tapUpgradePath(pathID)
            return tapUpgradePath(pathID) ?? .invalid
        case let .placeDemolition(slot, point):
            dismissMenu()
            selectPlacedTower(atSlot: slot)
            beginDemolitionPlacement()
            return placeDemolition(at: CGPoint(x: point.x, y: point.y))
        case let .placeObstacles(slot, point):
            dismissMenu()
            selectPlacedTower(atSlot: slot)
            beginEngineerObstaclePlacement()
            return placeEngineerObstacles(at: CGPoint(x: point.x, y: point.y))
        case let .rally(slot, point):
            dismissMenu()
            selectPlacedTower(atSlot: slot)
            toggleRallyPlacement()
            return placeRallyPoint(at: CGPoint(x: point.x, y: point.y))
        case let .moveHero(id, point):
            guard let index = hudHeroIndex(for: id) else { return .invalid }
            if selectedHeroIndex != index { selectHero(heroID: id) }
            return commandSelectedHero(to: CGPoint(x: point.x, y: point.y)) ? .ok : .invalid
        case let .reinforcements(point):
            if !isPlacingReinforcements { toggleReinforcementPlacement() }
            return placeReinforcements(at: CGPoint(x: point.x, y: point.y))
        case .startWave:
            return startNextWave()
        }
    }

    public var towerSnapshots: [BattleTowerSnapshot] {
        placedTowers.map { tower in
            let tuning = towerLevel(for: tower)!
            return BattleTowerSnapshot(slot: tower.slotIndex, kind: tower.kind, level: tower.level,
                branch: tower.branch, name: towerName(for: tower.kind, atLevel: tower.level, branch: tower.branch),
                position: Point(tower.position.x, tower.position.y), tuning: tuning,
                damage: damageTotalBySlot[tower.slotIndex, default: 0], upgrades: tower.upgrades)
        }
    }

    public var readyDemolitionSites: [(slot: Int, point: Point)] {
        placedTowers.compactMap { tower in
            guard tower.demolitionCharge?.isReadyForPlacement == true,
                  let tuning = towerLevel(for: tower),
                  let site = tuning.attackRange.nearestPathPoint(to: tower.position, from: tower.position, paths: paths)
            else { return nil }
            return (tower.slotIndex, Point(site.x, site.y))
        }
    }

    public var enemySnapshots: [BattleEnemySnapshot] {
        walkers.map { enemy in
            guard let origin = spawnOrigins[enemy.id] else { fatalError("Missing origin for enemy \(enemy.id)") }
            return BattleEnemySnapshot(id: enemy.id, typeID: origin.type,
                position: Point(enemy.position.x, enemy.position.y), hp: enemy.hp, maxHP: enemy.maxHP,
                morale: enemy.morale.value, livesCost: enemy.livesCost)
        }
    }

    public func simulationResult() -> SimulationResult {
        SimulationResult(outcome: outcome ?? .timeout, seconds: elapsedTime,
            livesRemaining: lives, goldRemaining: money, goldEarned: goldEarned,
            killed: killedCount, routed: 0, captured: 0, leaked: escapedEnemyCount,
            fatesByTypeID: fatesByType, waveMaxProgress: waveMaxProgress, leaksByWave: leaksByWave)
    }
}
