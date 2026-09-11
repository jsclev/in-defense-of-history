import Foundation

/// Hero orders and walking state. Both the live runner and host integration
/// tests use this model with the same MilitiaUnit and MilitiaAI decisions.
public struct HeroMovement {
    public enum InvalidSpawn: Error { case outsideMovementArea }
    public let area: HeroMovementArea
    public let spawn: Point
    public private(set) var station: Point
    private var route: [Point] = []
    private var routeIndex = 0
    private var routeTarget: Point?

    public init(area: HeroMovementArea, spawn: Point) throws {
        guard area.contains(spawn) else { throw InvalidSpawn.outsideMovementArea }
        self.area = area; self.spawn = spawn; station = spawn
    }

    /// An invalid or unreachable command is atomic: keep the old station,
    /// route, combat target and unit state. No snapping of player destinations.
    @discardableResult
    public mutating func command(to destination: Point, unit: inout MilitiaUnit) -> Bool {
        guard unit.state != .dead, let planned = area.route(from: unit.position, to: destination) else { return false }
        station = destination; routeTarget = destination; route = planned; routeIndex = 0
        unit.state = .returning; unit.targetSpawnID = -1
        return true
    }

    /// Resolves navigation before the runner handles attacks/healing. Movement
    /// never depends on publishing a sprite or a SwiftUI frame being delivered.
    public mutating func update(_ unit: inout MilitiaUnit, context: MilitiaContext,
                                moveSpeed: Double, deltaTime: Double) -> MilitiaDecision {
        var context = context
        context.rallyPoint = station; context.towerPosition = station
        let decision = MilitiaAI.decide(unit, context: context)
        switch decision {
        case .idle where unit.state == .returning:
            // MilitiaAI uses a two-unit arrival radius; heroes still finish at
            // the exact commanded point, including orders shorter than that.
            if advance(&unit, toward: station, distance: moveSpeed * deltaTime), unit.position == station {
                unit.state = .holding
            }
        case let .move(toward):
            if !advance(&unit, toward: toward, distance: moveSpeed * deltaTime), unit.state == .engaging {
                return .disengage
            }
        default: break
        }
        return decision
    }

    public mutating func respawn(unit: inout MilitiaUnit, hp: Double) {
        station = spawn; route = []; routeIndex = 0; routeTarget = nil
        unit = MilitiaUnit(position: spawn, hp: hp)
    }

    @discardableResult
    private mutating func advance(_ unit: inout MilitiaUnit, toward target: Point, distance: Double) -> Bool {
        guard distance.isFinite, distance >= 0 else { return false }
        if routeTarget != target {
            guard let planned = area.route(from: unit.position, to: target) else { return false }
            route = planned; routeIndex = 0; routeTarget = target
        }
        var remaining = distance
        while routeIndex < route.count {
            let goal = route[routeIndex]
            let gap = unit.position.distance(to: goal)
            if gap <= remaining {
                unit.position = goal; routeIndex += 1; remaining -= gap
            } else {
                if remaining > 0 { unit.position = Point.lerp(unit.position, goal, remaining / gap) }
                break
            }
        }
        return true
    }
}
