import Foundation

/// A player's preferred road position. The commander resolves it against the
/// actual tower's authored range, then issues the same command as a screen tap.
public struct GeneticTacticalOrder: Codable, Equatable, Sendable {
    public typealias Kind = BattleTacticalKind
    public var slot: Int
    public var kind: Kind
    public var pathIndex: Int
    public var progress: Double

    public init(slot: Int, kind: Kind, pathIndex: Int, progress: Double) {
        self.slot = slot; self.kind = kind; self.pathIndex = pathIndex; self.progress = progress
    }
    func supported(by tuning: TowerLevel) -> Bool {
        BattleTacticalTargeting.supports(kind, tuning: tuning)
    }
    func command(point: Point) -> BattleCommand {
        switch kind {
        case .rally: return .rally(slot: slot, point: point)
        case .obstacles: return .placeObstacles(slot: slot, point: point)
        case .demolition: return .placeDemolition(slot: slot, point: point)
        }
    }
    func target(tower: BattleTowerSnapshot, paths: [Path]) -> Point? {
        guard supported(by: tower.tuning) else { return nil }
        var best: (point: Point, distance: Double)?
        for (index, path) in paths.enumerated() where path.totalLength > 0 {
            // Include the exact desired point and the closest road point as well
            // as a one-percent route grid. This is an input policy, not combat.
            let samples = [progress, path.nearestDistance(to: tower.position) / path.totalLength]
                + (0...100).map { Double($0) / 100 }
            for fraction in samples {
                let point = path.point(atDistance: fraction * path.totalLength)
                guard BattleTacticalTargeting.contains(CGPoint(x: point.x, y: point.y),
                    from: CGPoint(x: tower.position.x, y: tower.position.y), kind: kind, tuning: tower.tuning) else { continue }
                let distance = abs(fraction - progress) + (index == pathIndex ? 0 : 2)
                if best == nil || distance < best!.distance { best = (point, distance) }
            }
        }
        return best?.point
    }
}

public struct GeneticTacticalReceipt: Codable, Equatable, Sendable {
    public let seconds: Double
    public let wave: Int
    public let slot: Int
    public let kind: GeneticTacticalOrder.Kind
    public let point: Point
}

extension GeneticStrategy {
    func validateTactics(study: AuthoredMoneyStudy) throws {
        var seen: Set<String> = []
        for order in tactics {
            guard seen.insert("\(order.slot):\(order.kind.rawValue)").inserted,
                  study.level.paths.indices.contains(order.pathIndex), order.progress.isFinite,
                  (0...1).contains(order.progress), let build = decisions.first(where: { $0.step.action.slot == order.slot }),
                  case let .build(_, id) = build.step.action,
                  let path = study.towerPaths.first(where: { $0.type.id == id }),
                  path.type.levels.contains(where: order.supported) else {
                throw DbError.Db(message: "genetic tactic[slot \(order.slot), \(order.kind.rawValue)]: invalid target or unsupported tower")
            }
        }
    }

    public mutating func randomizeTactics(study: AuthoredMoneyStudy, rng: inout SeededRNG) {
        tactics = []
        for decision in decisions {
            guard case let .build(slot, id) = decision.step.action,
                  let path = study.towerPaths.first(where: { $0.type.id == id }) else { continue }
            for kind in GeneticTacticalOrder.Kind.allCases {
                var order = GeneticTacticalOrder(slot: slot, kind: kind, pathIndex: 0, progress: 0)
                guard path.type.levels.contains(where: order.supported) else { continue }
                order.pathIndex = Int.random(in: study.level.paths.indices, using: &rng)
                order.progress = Double.random(in: 0...1, using: &rng)
                tactics.append(order)
            }
        }
    }

    mutating func mutateTactics(study: AuthoredMoneyStudy, rng: inout SeededRNG) {
        // Add previously absent choices too, including legacy seeded strategies.
        var all = self; all.randomizeTactics(study: study, rng: &rng)
        guard !all.tactics.isEmpty else { return }
        let next = all.tactics[Int.random(in: all.tactics.indices, using: &rng)]
        if let index = tactics.firstIndex(where: { $0.slot == next.slot && $0.kind == next.kind }) {
            tactics[index] = next
        } else { tactics.append(next) }
    }
}

struct GeneticTacticalCommander {
    let orders: [GeneticTacticalOrder]
    private var purchaseCount = -1
    private var targets: [Int: Point] = [:]
    private var placed: [Int: Point] = [:]
    private(set) var receipts: [GeneticTacticalReceipt] = []
    init(_ orders: [GeneticTacticalOrder]) { self.orders = orders }
    func controlsDemolition(slot: Int) -> Bool { orders.contains { $0.slot == slot && $0.kind == .demolition } }

    @MainActor mutating func tick(sim: GameSimulation, purchases: Int) throws {
        guard !orders.isEmpty else { return }
        if purchaseCount != purchases {
            purchaseCount = purchases
            let towers = Dictionary(uniqueKeysWithValues: sim.towers.map { ($0.slot, $0) })
            for (index, order) in orders.enumerated() {
                targets[index] = towers[order.slot].flatMap { order.target(tower: $0, paths: sim.content.level.paths) }
            }
        }
        let ready = Set(sim.readyDemolitionSites.map(\.slot))
        for (index, order) in orders.enumerated() {
            guard let point = targets[index] else { continue }
            if order.kind == .demolition {
                guard ready.contains(order.slot) else { continue }
            } else if placed[index] == point { continue }
            guard sim.perform(order.command(point: point)) == .ok else {
                throw DbError.Db(message: "Engine rejected tactical command at slot \(order.slot): \(order.kind.rawValue)")
            }
            placed[index] = point
            guard let tower = sim.towers.first(where: { $0.slot == order.slot }),
                  let actual = order.kind == .rally ? tower.rallyPoint : order.kind == .obstacles ? tower.obstaclePoint : tower.demolitionPoint else {
                throw DbError.Db(message: "Successful tactical command has no observed position at slot \(order.slot)")
            }
            receipts.append(.init(seconds: sim.time, wave: sim.currentWave, slot: order.slot, kind: order.kind, point: actual))
        }
    }
}
