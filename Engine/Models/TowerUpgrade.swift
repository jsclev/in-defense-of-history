import Foundation

/// Attribute identifiers are behavior, while every amount and capability change
/// comes from the authored upgrade rows in SQLite.
public enum TowerUpgradeAttribute: String, Codable, Sendable, CaseIterable {
    case range, fireInterval, damage, terror, blastRadius, coverPierce, turnRate
    case meleeAttack, meleeDefense, meleeHP, meleeInterval, meleeRespawn, meleeHealing, rallyRadius
    case preparation, obstacleRadius, obstacleSlow, income, supportSpeed, supportHealing

    func apply(_ delta: Double, to tuning: inout TowerLevel, record: String) throws {
        func invalid(_ reason: String) -> DbError {
            .Db(message: "tower_upgrade_rank[\(record)]: attribute '\(rawValue)' \(reason)")
        }
        let reduces = self == .fireInterval || self == .meleeInterval || self == .meleeRespawn || self == .preparation
        guard delta.isFinite, reduces ? delta < 0 : delta > 0 else {
            throw invalid("must have a finite, beneficial delta")
        }
        let projectile = tuning.attackMode.firesProjectiles
        switch self {
        case .range:
            tuning.range += delta
        case .fireInterval:
            guard projectile else { throw invalid("requires a projectile attack") }
            tuning.fireInterval += delta
        case .damage:
            guard projectile || tuning.attackMode == .demolition else { throw invalid("requires a damaging attack") }
            tuning.shotMinDamage += delta; tuning.shotMaxDamage += delta
        case .terror:
            guard tuning.attackMode.requiresAim || tuning.attackMode == .demolition else {
                throw invalid("requires artillery or demolition morale damage")
            }
            tuning.terrorMin += delta; tuning.terrorMax += delta
        case .blastRadius:
            guard tuning.attackMode == .shell || tuning.attackMode == .demolition else { throw invalid("requires an explosive attack") }
            tuning.aoeRadius += delta
        case .coverPierce:
            guard tuning.attackMode == .shell || tuning.attackMode == .demolition else { throw invalid("requires splash damage") }
            tuning.splashCoverPierce += delta
        case .turnRate:
            guard tuning.attackMode.requiresAim else { throw invalid("requires an aimed gun") }
            tuning.turnRateDegrees += delta
        case .meleeAttack, .meleeDefense, .meleeHP, .meleeInterval, .meleeRespawn, .meleeHealing, .rallyRadius:
            guard var melee = tuning.meleeUnit else { throw invalid("requires authored melee soldiers") }
            switch self {
            case .meleeAttack: melee.attackRating += delta
            case .meleeDefense: melee.defenseRating += delta
            case .meleeHP: melee.hp += delta
            case .meleeInterval: melee.attackInterval += delta
            case .meleeRespawn: melee.respawnSeconds += delta
            case .meleeHealing: melee.healPerSecond += delta
            case .rallyRadius: melee.rallyPointRadius += delta
            default: break
            }
            tuning.meleeUnit = melee
        case .preparation:
            guard let seconds = tuning.demolitionPreparationSeconds else { throw invalid("requires demolition charges") }
            tuning.demolitionPreparationSeconds = seconds + delta
        case .obstacleRadius, .obstacleSlow:
            guard var obstacles = tuning.engineerObstacles else { throw invalid("requires engineer obstacles") }
            if self == .obstacleRadius { obstacles.radius += delta }
            else { obstacles.slowFraction += delta }
            tuning.engineerObstacles = obstacles
        case .income:
            guard delta.rounded() == delta,
                  let amount = Int(exactly: delta),
                  !tuning.support.incomePerWave.addingReportingOverflow(amount).overflow else {
                throw invalid("requires a whole, representable coin amount")
            }
            tuning.support.incomePerWave += amount
        case .supportSpeed:
            tuning.support.attackSpeedMultiplier += delta
        case .supportHealing:
            tuning.support.healPerSecond += delta
        }
    }
}

public struct TowerUpgradeEffect: Codable, Equatable, Sendable {
    public let attribute: TowerUpgradeAttribute
    public let delta: Double
}

public struct TowerUpgradeRank: Codable, Equatable, Sendable {
    public let rank: Int
    public let cost: Int
    public let description: String
    public let effects: [TowerUpgradeEffect]
}

public struct TowerUpgradePath: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let slot: Int
    public let name: String
    public let description: String
    public let iconName: String
    public let historicalBasis: String
    public let sourceURL: String
    public let ranks: [TowerUpgradeRank]

    public var overview: String {
        name + ": " + description + "\n" + ranks.map {
            "\($0.rank)/\(ranks.count) — \($0.cost) coins: \($0.description)"
        }.joined(separator: "\n")
    }

    public func menuDetails(purchasedRank: Int) -> TowerMenuDetails {
        let next = ranks.first { $0.rank == purchasedRank + 1 }
        let title = next.map { "\(name) · \($0.rank)/\(ranks.count)" }
            ?? "\(name) · \(ranks.count)/\(ranks.count)"
        let status = next.map { "\($0.cost) coins · \($0.description)" } ?? "Fully upgraded."
        let acquired = ranks.filter { $0.rank <= purchasedRank }.map { $0.description }.joined(separator: " ")
        return TowerMenuDetails(name: title,
            description: description + "\n\n" + status + (acquired.isEmpty ? "" : "\n\nPurchased: " + acquired))
    }
}

/// Per-emplacement battle state, discarded with the level. Zero means that the
/// player has not bought a rank; it is not a replacement for authored content.
public struct TowerUpgradeProgress: Codable, Equatable, Sendable {
    public private(set) var ranks: [String: Int] = [:]
    public init() {}
    public func rank(for pathID: String) -> Int { ranks[pathID] ?? 0 }

    @discardableResult
    public mutating func purchase(pathID: String, from base: TowerLevel, money: inout Int) -> BuildResult {
        guard let path = base.upgradePaths.first(where: { $0.id == pathID }),
              let next = path.ranks.first(where: { $0.rank == rank(for: pathID) + 1 }) else { return .invalid }
        guard money >= next.cost else { return .needGold }
        money -= next.cost
        ranks[pathID] = next.rank
        return .ok
    }
}

extension MilitiaUnit {
    /// Improve living soldiers without healing unrelated damage or resurrecting
    /// casualties. Active swings and relief retain their fractional progress.
    public mutating func applyUpgrade(from old: MeleeUnitStats, to new: MeleeUnitStats) {
        if state != .dead { hp = min(new.hp, hp + max(0, new.hp - old.hp)) }
        swingTicksLeft = Int((Double(swingTicksLeft) * new.attackInterval / old.attackInterval).rounded(.up))
        respawnTicksLeft = Int((Double(respawnTicksLeft) * new.respawnSeconds / old.respawnSeconds).rounded(.up))
    }
}

extension TowerLevel {
    public func upgraded(with progress: TowerUpgradeProgress) -> TowerLevel {
        do { return try resolvingUpgrades(ranks: progress.ranks) }
        catch { fatalError("Invalid authored tower upgrade: \(error)") }
    }

    func resolvingUpgrades(ranks: [String: Int]) throws -> TowerLevel {
        guard Set(ranks.keys).isSubset(of: Set(upgradePaths.map(\.id))) else {
            throw DbError.Db(message: "tower_upgrade_path: progress contains an unknown path_id")
        }
        var result = self
        for path in upgradePaths {
            let count = ranks[path.id] ?? 0
            guard (0...path.ranks.count).contains(count) else {
                throw DbError.Db(message: "tower_upgrade_path[\(path.id)]: invalid purchased rank \(count)")
            }
            for rank in path.ranks.prefix(count) {
                for effect in rank.effects {
                    try effect.attribute.apply(effect.delta, to: &result, record: "\(path.id):\(rank.rank)")
                }
                try result.validateUpgradeResult(record: "\(path.id):\(rank.rank)")
            }
        }
        return result
    }

    private func validateUpgradeResult(record: String) throws {
        func check(_ field: String, _ valid: Bool) throws {
            guard valid else { throw DbError.Db(message: "tower_upgrade_rank[\(record)]: attribute '\(field)' produces invalid combined tuning") }
        }
        try check("range", range.isFinite && range >= 0 && (!support.hasAura || range > 0))
        try check("fireInterval", fireInterval.isFinite && (!attackMode.firesProjectiles || fireInterval > 0))
        try check("damage", shotMinDamage.isFinite && shotMaxDamage.isFinite && shotMinDamage >= 0 && shotMaxDamage >= shotMinDamage)
        try check("terror", terrorMin.isFinite && terrorMax.isFinite && terrorMin >= 0 && terrorMax >= terrorMin)
        try check("blastRadius", aoeRadius.isFinite && aoeRadius >= 0)
        try check("coverPierce", (0...1).contains(splashCoverPierce))
        try check("turnRate", turnRateDegrees.isFinite && (!attackMode.requiresAim || turnRateDegrees > 0))
        try check("supportSpeed", support.attackSpeedMultiplier.isFinite && support.attackSpeedMultiplier >= 1)
        try check("supportHealing", support.healPerSecond.isFinite && support.healPerSecond >= 0)
        if let melee = meleeUnit {
            try check("meleeAttack", melee.attackRating.isFinite && melee.attackRating > 0)
            try check("meleeDefense", melee.defenseRating >= 0 && melee.defenseRating < 1)
            try check("meleeHP", melee.hp.isFinite && melee.hp > 0)
            try check("meleeInterval", melee.attackInterval.isFinite && melee.attackInterval > 0)
            try check("meleeRespawn", melee.respawnSeconds.isFinite && melee.respawnSeconds > 0)
            try check("meleeHealing", melee.healPerSecond.isFinite && melee.healPerSecond >= 0)
            try check("rallyRadius", melee.rallyPointRadius.isFinite && melee.rallyPointRadius > 0)
        }
        if let preparation = demolitionPreparationSeconds { try check("preparation", preparation.isFinite && preparation > 0) }
        if let obstacles = engineerObstacles {
            try check("obstacleRadius", obstacles.radius.isFinite && obstacles.radius > 0)
            try check("obstacleWidthFraction", obstacles.widthFraction.isFinite && obstacles.widthFraction > 0 && obstacles.widthFraction <= 1)
            try check("obstacleSlow", obstacles.slowFraction > 0 && obstacles.slowFraction < 1)
        }
    }
}
