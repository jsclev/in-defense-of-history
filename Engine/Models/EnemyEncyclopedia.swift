import Foundation

/// References the production enemy record; never carries a second stat or art catalog.
public struct EnemyEncyclopediaEntry: Identifiable {
    public var id: UUID { enemy.id }
    public let enemy: EnemyType
    public let strategy: String
    public let history: String
    public let inclusionReason: String
    public let adaptation: String
    public let sourceTitle: String
    public let sourceURL: URL
}

struct EnemyEncyclopediaStats {
    struct Row: Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }
    let rows: [Row]

    init(enemy: EnemyType, rules: CombatRules) {
        func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
        func percent(_ value: Double) -> String { value.formatted(.percent.precision(.fractionLength(0...1))) }
        let stats = enemy.stats
        rows = [
            Row(label: "Health", value: number(stats.maxHP)),
            Row(label: "Movement", value: "\(number(stats.speed)) units/s"),
            Row(label: "Melee damage", value: "\(number(stats.damageMin))–\(number(stats.damageMax))"),
            Row(label: "Melee interval", value: "\(number(rules.enemySwingInterval)) s"),
            Row(label: "Cover", value: percent(stats.cover)),
            Row(label: "Discipline", value: percent(stats.discipline)),
            Row(label: "Kill reward", value: "\(rules.killReward(baseBounty: stats.gold)) coins"),
            Row(label: "Lives lost at exit", value: "\(stats.livesCost)"),
            Row(label: "Infantry can block", value: enemy.has(.rideDown) ? "No" : "Yes"),
            Row(label: "Slows at morale", value: "≤ \(percent(stats.moraleResponse.speedThreshold))"),
            Row(label: "Speed when shaken", value: percent(stats.moraleResponse.speedMultiplier)),
            Row(label: "Weaker hits at morale", value: "≤ \(percent(stats.moraleResponse.attackThreshold))"),
            Row(label: "Damage when shaken", value: percent(stats.moraleResponse.attackMultiplier))
        ]
    }
}
