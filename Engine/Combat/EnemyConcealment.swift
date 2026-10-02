import Foundation

/// Enemy-specific content, authored in enemy_type.traits and validated by its DAO.
public struct EnemyConcealmentRules: Codable, Equatable, Sendable {
    public let duration: Double
    public let visibleInterval: Double
    public let troopRadius: Double
    public let heroRevealRadius: Double
    public let opacity: Double
}

/// Tick deadlines only change on transitions, so recordings retain concealment
/// without adding per-tick countdown data or predicting it during playback.
struct EnemyConcealment: Codable, Equatable {
    let rules: EnemyConcealmentRules
    var hiddenUntilTick: Int64?
    var readyAtTick: Int64
    var automaticAtTick: Int64

    var isHidden: Bool { hiddenUntilTick != nil }

    init(rules: EnemyConcealmentRules, spawnTick: Int64) {
        self.rules = rules
        readyAtTick = spawnTick
        automaticAtTick = spawnTick + Int64(BattleGeometry.fireTicks(rules.visibleInterval))
    }

    mutating func reveal(at tick: Int64) {
        guard isHidden else { return }
        hiddenUntilTick = nil
        readyAtTick = tick + Int64(BattleGeometry.fireTicks(rules.visibleInterval))
        automaticAtTick = readyAtTick
    }

    mutating func advance(at tick: Int64, heroNearby: Bool,
                          hasTroopsOnPath: Bool, troopNearby: Bool) {
        if let until = hiddenUntilTick, tick >= until { hiddenUntilTick = nil }
        if heroNearby {
            reveal(at: tick)
            return
        }
        guard !isHidden, tick >= readyAtTick,
              troopNearby || (!hasTroopsOnPath && tick >= automaticAtTick) else { return }
        let until = tick + Int64(BattleGeometry.fireTicks(rules.duration))
        hiddenUntilTick = until
        readyAtTick = until + Int64(BattleGeometry.fireTicks(rules.visibleInterval))
        automaticAtTick = readyAtTick
    }
}

extension EnemyType {
    var concealmentRules: EnemyConcealmentRules? {
        traits.compactMap { if case let .concealment(rules) = $0 { return rules }; return nil }.first
    }
}

extension BattleEngine {
    /// Only living troops from melee towers count as a patrol trigger. Heroes
    /// reveal Rangers instead; temporary reinforcements do not disable the
    /// unattended-path cycle. Presence is evaluated on each Ranger's own path.
    func advanceEnemyConcealment() {
        guard walkers.contains(where: { $0.concealment != nil }) else { return }
        let troops = garrisonsBySlot.flatMap { slot, garrison -> [Point] in
            guard placedTower(atSlot: slot)?.kind == .melee else { return [] }
            return garrison.units.filter { $0.state != .dead && $0.hp > 0 }.map(\.position)
        }
        let troopsByPath = paths.map { path in
            troops.filter { troop in
                path.point(atDistance: path.nearestDistance(to: troop)).distance(to: troop)
                    <= virtualCanvas.pathWidth / 2
            }
        }
        let heroes = heroPosts.filter { $0.unit.state != .dead && $0.unit.hp > 0 }.map { $0.unit.position }
        for index in walkers.indices {
            guard var concealment = walkers[index].concealment else { continue }
            let walker = walkers[index]
            let position = Point(walker.position.x, walker.position.y)
            let nearbyTroops = troopsByPath[walker.pathIndex]
            concealment.advance(at: timer.tick,
                heroNearby: heroes.contains { $0.distance(to: position) <= concealment.rules.heroRevealRadius },
                hasTroopsOnPath: !nearbyTroops.isEmpty,
                troopNearby: nearbyTroops.contains { $0.distance(to: position) <= concealment.rules.troopRadius })
            walkers[index].concealment = concealment
            if concealment.isHidden { blockedWalkerIDs.remove(walker.id) }
        }
    }

    /// Called after hero movement as well, so entering reveal range exposes the
    /// enemy to tower fire in the same tick.
    func revealEnemiesNearHeroes() {
        for index in walkers.indices where walkers[index].isConcealed {
            let position = Point(walkers[index].position.x, walkers[index].position.y)
            let radius = walkers[index].concealment!.rules.heroRevealRadius
            if heroPosts.contains(where: { $0.unit.state != .dead && $0.unit.hp > 0
                && $0.unit.position.distance(to: position) <= radius }) {
                walkers[index].concealment?.reveal(at: timer.tick)
            }
        }
    }
}
