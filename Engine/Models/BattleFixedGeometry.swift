import Foundation

/// Cache keys preserve signed zero as well as the coordinate value. None of
/// these caches quantizes positions or changes nearest-path tie breaking.
struct BattleGeometryPoint: Hashable {
    let x: UInt64
    let y: UInt64
    init(_ point: Point) { x = point.x.bitPattern; y = point.y.bitPattern }
    init(_ point: CGPoint) { x = Double(point.x).bitPattern; y = Double(point.y).bitPattern }
}

/// Only flag positions and squad sizes determine the shared formation. Unit
/// motion, health, deaths and respawns must not rebuild this immutable snapshot.
@MainActor final class BattleMilitiaGeometry {
    private struct Squad {
        let slot: Int
        let rally: BattleGeometryPoint
        let count: Int
    }
    struct March {
        let path: Path?
        let targetAlong: Double?
    }
    private let squads: [Squad]
    let slots: [Int]
    let posts: [Int: [Point]]
    let marches: [Int: March]

    init(_ engine: BattleEngine) {
        let ordered = engine.garrisonsBySlot.sorted { $0.key < $1.key }
        slots = ordered.map(\.key)
        squads = ordered.map { Squad(slot: $0.key, rally: BattleGeometryPoint($0.value.rallyPoint), count: $0.value.units.count) }
        posts = engine.meleeFormation.sharedPosts(squads: ordered.map {
            (slot: $0.key, rallyPoint: $0.value.rallyPoint, count: $0.value.units.count)
        })
        var byFlag: [BattleGeometryPoint: March] = [:], bySlot: [Int: March] = [:]
        for (slot, garrison) in ordered {
            let key = BattleGeometryPoint(garrison.rallyPoint)
            if byFlag[key] == nil {
                let path = engine.pathNearest(to: garrison.rallyPoint)
                byFlag[key] = March(path: path, targetAlong: path?.nearestDistance(to: garrison.rallyPoint))
            }
            bySlot[slot] = byFlag[key]!
        }
        marches = bySlot
    }

    func matches(_ garrisons: [Int: BattleEngine.MilitiaGarrison]) -> Bool {
        guard squads.count == garrisons.count else { return false }
        return squads.allSatisfy { squad in
            guard let garrison = garrisons[squad.slot] else { return false }
            return squad.count == garrison.units.count && squad.rally == BattleGeometryPoint(garrison.rallyPoint)
        }
    }
}

/// Geometry follows placement and resolved tower configuration, not changing
/// aim/cooldown state. BattleEngine invalidates it when loaded tuning or paths
/// change, and this key also covers direct purchases, replacement and removal.
@MainActor final class BattleObstacleGeometry {
    private struct Input {
        let slot: Int
        let kind: TowerKind
        let level: Int
        let branch: Int
        let upgrades: TowerUpgradeProgress
        let position: BattleGeometryPoint?

        init(_ tower: PlacedTower) {
            slot = tower.slotIndex; kind = tower.kind; level = tower.level; branch = tower.branch
            upgrades = tower.upgrades; position = tower.engineerObstaclePosition.map(BattleGeometryPoint.init)
        }
        func matches(_ tower: PlacedTower) -> Bool {
            slot == tower.slotIndex && kind == tower.kind && level == tower.level && branch == tower.branch
                && upgrades == tower.upgrades && position == tower.engineerObstaclePosition.map(BattleGeometryPoint.init)
        }
    }
    private let inputs: [Input]
    let fields: [EngineerObstacleField]
    /// Parallel to fields, in original tower order for identical overlap rules.
    let slots: [Int]

    init(_ engine: BattleEngine) {
        inputs = engine.placedTowers.map(Input.init)
        var fields: [EngineerObstacleField] = [], slots: [Int] = []
        for tower in engine.placedTowers {
            guard let field = engine.engineerObstacleField(for: tower) else { continue }
            fields.append(field); slots.append(tower.slotIndex)
        }
        self.fields = fields; self.slots = slots
    }

    func matches(_ towers: [PlacedTower]) -> Bool {
        guard inputs.count == towers.count else { return false }
        return inputs.indices.allSatisfy { inputs[$0].matches(towers[$0]) }
    }
}
