import Foundation

/// Strategic orders only. Navigation, attacks, healing and death remain in the
/// existing battle engine. Each deployed hero owns a separate controller instance.
protocol HeroAI: AnyObject {
    var isRecovering: Bool { get }
    func reset()
    func destination(in context: HeroAIContext) -> Point?
}

struct HeroAIContext {
    struct Threat {
        let id: Int
        let position: Point
        let secondsToExit: Double
    }
    let unit: MilitiaUnit
    let combat: HeroCombatStats
    let movement: HeroMovement
    let configuration: HeroAIConfiguration
    let engageScanRadius: Double
    let threats: [Threat]
}

/// Reusable starter tactic, deliberately separate from the individual policies.
/// No RNG or wall clock: identical battle ticks produce identical orders.
final class HeroAITactics {
    private(set) var isRecovering = false

    func reset() { isRecovering = false }

    func interceptThreat(in context: HeroAIContext) -> Point? {
        let unit = context.unit
        guard unit.state != .dead else { reset(); return nil }
        let health = unit.hp / context.combat.hp
        if health <= context.configuration.retreatHealthFraction { isRecovering = true }
        if isRecovering {
            if health < context.configuration.resumeHealthFraction {
                return context.movement.station == context.movement.spawn
                    && unit.state != .engaging && unit.state != .fighting ? nil : context.movement.spawn
            }
            isRecovering = false
        }
        // Preserve active fights and attack cooldowns until retreat is needed.
        guard unit.state != .engaging, unit.state != .fighting else { return nil }
        let threats = context.threats.sorted {
            if $0.secondsToExit != $1.secondsToExit { return $0.secondsToExit < $1.secondsToExit }
            let lhs = unit.position.distance(to: $0.position)
            let rhs = unit.position.distance(to: $1.position)
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
        for threat in threats {
            // An unreachable lane must not prevent considering another threat.
            guard context.movement.area.route(from: unit.position, to: threat.position) != nil else { continue }
            if unit.position.distance(to: threat.position) <= context.engageScanRadius {
                // Stop walking so the normal melee handler can acquire a target.
                return context.movement.station == unit.position ? nil : unit.position
            }
            if context.movement.station.distance(to: threat.position) <= context.engageScanRadius {
                return nil
            }
            return threat.position
        }
        // With no reachable enemies, return to the authored defensive post.
        return context.movement.station == context.movement.spawn ? nil : context.movement.spawn
    }
}
