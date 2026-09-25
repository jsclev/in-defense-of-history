import Foundation

/// Presentation of the same authored tuning used by combat. Values are base
/// attributes, before optional upgrades, campaign bonuses or nearby support.
public struct TowerEncyclopediaStat: Identifiable, Equatable, Sendable {
    public let label: String
    public let value: String
    public var id: String { label }

    public static func values(for tuning: TowerLevel) -> [Self] {
        var result: [Self] = []
        func add(_ label: String, _ value: String) {
            result.append(Self(label: label, value: value))
        }
        func number(_ value: Double) -> String {
            value.formatted(.number.precision(.fractionLength(0...2)))
        }
        func interval(_ low: Double, _ high: Double) -> String {
            low == high ? number(low) : "\(number(low))–\(number(high))"
        }
        if tuning.attackMode.firesProjectiles || tuning.attackMode == .demolition {
            add(tuning.attackMode == .grapeshot ? "Damage per pellet" : "Damage",
                interval(tuning.shotMinDamage, tuning.shotMaxDamage))
        }
        if tuning.attackMode.firesProjectiles {
            add("Time between shots", "\(number(tuning.fireInterval)) s")
        }
        if tuning.range > 0 {
            let label: String
            switch tuning.attackMode {
            case .obstacles, .demolition: label = "Placement range"
            case .none: label = "Support range"
            case .melee: label = "Tower range"
            default: label = "Attack range"
            }
            if tuning.attackMode != .melee { add(label, number(tuning.range)) }
        }
        if tuning.terrorMax > 0 && (tuning.attackMode.requiresAim || tuning.attackMode == .demolition) {
            add("Morale damage", interval(tuning.terrorMin, tuning.terrorMax))
        }
        if tuning.attackMode == .shell || tuning.attackMode == .demolition {
            add("Blast radius", number(tuning.aoeRadius))
        }
        if let soldiers = tuning.meleeUnit {
            add("Soldiers", String(soldiers.soldierCount))
            add("Damage per soldier", interval(soldiers.damageRange.lowerBound, soldiers.damageRange.upperBound))
            add("Health per soldier", number(soldiers.hp))
            add("Damage reduction", "\(number(soldiers.defenseRating * 100))%")
            add("Time between attacks", "\(number(soldiers.attackInterval)) s")
            add("Rally range", number(soldiers.rallyPointRadius))
            add("Replacement time", "\(number(soldiers.respawnSeconds)) s")
            add("Recovery out of combat", "\(number(soldiers.healPerSecond)) HP/s")
        }
        if let obstacles = tuning.engineerObstacles {
            add("Enemy slowdown", "\(number(obstacles.slowFraction * 100))%")
            add("Obstacle radius", number(obstacles.radius))
        }
        if let seconds = tuning.demolitionPreparationSeconds {
            add("Charge preparation", "\(number(seconds)) s")
        }
        if tuning.support.incomePerWave > 0 {
            add("Income each wave", "\(tuning.support.incomePerWave) coins")
        }
        if tuning.support.attackSpeedMultiplier > 1 {
            add("Nearby firing speed", "+\(number((tuning.support.attackSpeedMultiplier - 1) * 100))%")
        }
        if tuning.support.healPerSecond > 0 {
            add("Nearby healing", "\(number(tuning.support.healPerSecond)) HP/s")
        }
        return result
    }
}
