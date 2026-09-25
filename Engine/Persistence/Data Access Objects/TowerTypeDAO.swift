import Foundation
import SQLite3

public class TowerTypeDAO: BaseDAO {
    private let meleeUnitDao: MeleeUnitDAO
    private let combatRulesDao: CombatRulesDAO

    init(conn: OpaquePointer?, meleeUnitDao: MeleeUnitDAO, combatRulesDao: CombatRulesDAO) {
        self.meleeUnitDao = meleeUnitDao
        self.combatRulesDao = combatRulesDao
        super.init(conn: conn, table: "tower_type", loggerName: TowerTypeDAO.self)
    }

    private struct Identity {
        let id: UUID
        let category: String
        let kind: TowerKind
        let name: String
        let layout: [[Int]]
    }

    private struct Record {
        let id: UUID
        let typeID: UUID
        let level: Int
        let branch: Int
        let details: TowerMenuDetails
        let history: DesignArsenal.History
        let tuning: TowerLevel
    }

    public func validateAuthoredContent() throws {
        _ = try content()
    }

    private func histories(towerIDs: Set<UUID>) throws -> [UUID: DesignArsenal.History] {
        var result: [UUID: DesignArsenal.History] = [:]
        _ = try authoredRows("SELECT * FROM tower_history", entity: "tower_history") { row in
            let id = try row.uuid("tower_id")
            let row = AuthoredRow(statement: row.statement, entity: "tower_history[\(id)]")
            guard towerIDs.contains(id) else {
                throw row.invalid("tower_id", "does not identify an authored tower")
            }
            guard result[id] == nil else { throw row.invalid("tower_id", "is duplicated") }
            let source = try row.text("source_url")
            guard let url = URL(string: source), url.scheme == "https",
                  let host = url.host, !host.isEmpty,
                  !source.contains(where: \.isWhitespace) else {
                throw row.invalid("source_url", "must be an absolute HTTPS URL")
            }
            let presentation = try row.text("presentation_kind")
            let guide: DesignArsenal.History.DemonstrationGuide?
            if presentation == "standard" {
                try row.requireNull("strategy_text")
                try row.requireNull("inclusion_reason")
                guide = nil
            } else if let style = DesignArsenal.History.DemonstrationGuide.Style(rawValue: presentation) {
                guide = .init(style: style, strategy: try row.text("strategy_text"),
                              inclusionReason: try row.text("inclusion_reason"))
            } else {
                throw row.invalid("presentation_kind", "is unsupported")
            }
            result[id] = DesignArsenal.History(description: try row.text("historical_description"),
                sourceTitle: try row.text("source_title"), sourceURL: url, guide: guide)
        }
        for id in towerIDs where result[id] == nil {
            throw DbError.Db(message: "tower_history[\(id)]: attribute 'tower_id' is missing its required history row")
        }
        return result
    }

    private func identities() throws -> [Identity] {
        let values = try authoredRows("SELECT * FROM tower_type", entity: "tower_type") { row in
            let id = try row.uuid("id")
            let row = AuthoredRow(statement: row.statement, entity: "tower_type[\(id)]")
            let category = try row.text("tower_type_category")
            guard let kind = TowerKind(rawValue: try row.text("tower_type_key")) else {
                throw row.invalid("tower_type_key", "is unsupported")
            }
            let layout: [[Int]]
            do { layout = try JSONDecoder().decode([[Int]].self, from: Data(try row.text("level_layout").utf8)) }
            catch { throw row.invalid("level_layout", "must contain arrays of branch numbers") }
            guard !layout.isEmpty, layout.first == [1],
                  layout.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 > 0 }
                      && Set($0).count == $0.count }) else {
                throw row.invalid("level_layout", "is invalid")
            }
            return Identity(id: id, category: category, kind: kind, name: try row.text("tower_type_name"), layout: layout)
        }
        let kinds = values.map(\.kind)
        guard Set(kinds) == Set(TowerKind.allCases), Set(kinds).count == values.count else {
            throw DbError.Db(message: "tower_type: missing or duplicate tower_type_key")
        }
        return values
    }

    private func tuning(_ row: AuthoredRow, melee: MeleeUnitStats?, rules: CombatRules,
                        upgrades: [TowerUpgradePath]) throws -> TowerLevel {
        guard let mode = TowerAttackMode(rawValue: try row.text("attack_mode")) else {
            throw row.invalid("attack_mode", "is unsupported")
        }
        let turnRate = try row.number("turn_rate_degrees", minimum: 0, strictlyGreater: mode.requiresAim)
        let hasMelee = try row.flag("has_melee_unit")
        guard hasMelee == (melee != nil) else {
            throw row.invalid("melee_unit", hasMelee ? "is missing" : "exists while its capability is disabled")
        }
        let hasCharge = try row.flag("has_demolition_charge")
        let hasObstacles = try row.flag("has_engineer_obstacles")
        guard mode != .none || (!hasMelee && !hasCharge && !hasObstacles) else {
            throw row.invalid("attack_mode", "none requires melee, demolition and obstacle capabilities to be disabled")
        }
        let preparation: Double?
        if hasCharge {
            preparation = try row.number("demolition_prepare_seconds", minimum: 0, strictlyGreater: true)
        } else {
            try row.requireNull("demolition_prepare_seconds")
            preparation = nil
        }
        let obstacles: EngineerObstacleStats?
        if hasObstacles {
            let slow = try row.number("obstacle_slow_fraction", minimum: 0, strictlyGreater: true, maximum: 1)
            guard slow < 1 else { throw row.invalid("obstacle_slow_fraction", "must be less than 1") }
            obstacles = EngineerObstacleStats(
                radius: try row.number("obstacle_radius", minimum: 0, strictlyGreater: true),
                slowFraction: slow, widthFraction: try row.number("obstacle_width_fraction", minimum: 0, strictlyGreater: true, maximum: 1))
        } else {
            try row.requireNull("obstacle_radius")
            try row.requireNull("obstacle_width_fraction")
            try row.requireNull("obstacle_slow_fraction")
            obstacles = nil
        }
        guard let targeting = Targeting(rawValue: try row.text("targeting")) else {
            throw row.invalid("targeting", "is unsupported")
        }
        let minimumDamage = try row.number("shot_min_damage", minimum: 0)
        let minimumTerror = try row.number("terror_min", minimum: 0)
        let support = TowerSupportStats(
            incomePerWave: try row.integer("income_per_wave", minimum: 0),
            attackSpeedMultiplier: try row.number("support_attack_speed_multiplier", minimum: 1),
            healPerSecond: try row.number("support_heal_per_second", minimum: 0))
        return TowerLevel(
            combatRules: rules, attackMode: mode, turnRateDegrees: turnRate,
            cost: try row.integer("cost", minimum: 0),
            range: try row.number("tower_range", minimum: 0, strictlyGreater: mode != .none || support.hasAura),
            fireInterval: try row.number("fire_interval", minimum: 0),
            shotMinDamage: minimumDamage,
            shotMaxDamage: try row.number("shot_max_damage", minimum: minimumDamage),
            terrorMin: minimumTerror,
            terrorMax: try row.number("terror_max", minimum: minimumTerror),
            aoeRadius: try row.number("aoe_radius", minimum: 0),
            aoeFalloffExponent: try row.number("aoe_falloff_exponent", minimum: 0, strictlyGreater: true),
            splashCoverPierce: try row.number("splash_cover_pierce", minimum: 0, maximum: 1),
            contagionChance: try row.number("contagion_chance", minimum: 0, maximum: 1),
            targeting: targeting,
            projectileSpeed: try row.number("projectile_speed", minimum: 0),
            meleeUnit: melee,
            demolitionPreparationSeconds: preparation,
            engineerObstacles: obstacles, support: support, upgradePaths: upgrades)
    }

    private func content() throws -> DesignArsenal {
        let rules = try combatRulesDao.get()
        let types = try identities()
        let melee = try meleeUnitDao.getStatsByTowerId(combatRules: rules)
        let upgradeDAO = TowerUpgradeDAO(conn: conn)
        let towerIDs = try authoredRows("SELECT id FROM tower", entity: "tower") { try $0.uuid("id") }
        let history = try histories(towerIDs: Set(towerIDs))
        let allUpgrades = try upgradeDAO.allPaths(towerIDs: Set(towerIDs))
        let values = try authoredRows("""
            SELECT * FROM tower ORDER BY tower_type_id, tower_level, branch
            """, entity: "tower") { row in
                let id = try row.uuid("id")
                let row = AuthoredRow(statement: row.statement, entity: "tower[\(id)]")
                let level = try row.integer("tower_level", minimum: 1)
                let upgrades = try upgradeDAO.paths(for: id, level: level,
                    expectedCount: row.integer("upgrade_path_count", minimum: 0), from: allUpgrades)
                let attributes = try tuning(row, melee: melee[id], rules: rules, upgrades: upgrades)
                if history[id]!.guide?.style == .mortarStudy, attributes.attackMode != .shell {
                    throw row.invalid("attack_mode", "mortarStudy requires shell combat")
                }
                if history[id]!.guide?.style == .siegeStudy, attributes.attackMode != .solidShot {
                    throw row.invalid("attack_mode", "siegeStudy requires solidShot combat")
                }
                try upgradeDAO.validateCombinations(attributes)
                return Record(id: id, typeID: try row.uuid("tower_type_id"),
                    level: level,
                    branch: try row.integer("branch", minimum: 1),
                    details: TowerMenuDetails(name: try row.text("tower_name"),
                                              description: try row.text("tower_description")),
                    history: history[id]!,
                    tuning: attributes)
            }
        guard Set(melee.keys).isSubset(of: Set(values.map(\.id))) else {
            throw DbError.Db(message: "melee_unit: tower_id does not identify an authored tower")
        }
        guard Set(values.map(\.typeID)).isSubset(of: Set(types.map(\.id))) else {
            throw DbError.Db(message: "tower: tower_type_id does not identify an authored tower type")
        }
        for type in types {
            let rows = values.filter { $0.typeID == type.id }
            let expected = Set(type.layout.enumerated().flatMap { index, branches in
                branches.map { "\(index + 1):\($0)" }
            })
            let actual = rows.map { "\($0.level):\($0.branch)" }
            guard Set(actual) == expected, actual.count == expected.count else {
                throw DbError.Db(message: "tower_type[\(type.id)]: tower rows do not match level_layout; missing \(expected.subtracting(actual).sorted())")
            }
        }
        return try DesignArsenal(towers: types.map { type in
            DesignArsenal.Definition(id: type.id, kind: type.kind, category: type.category, name: type.name,
                tiers: values.filter { $0.typeID == type.id }.map {
                    DesignArsenal.Tier(id: $0.id, level: $0.level, branch: $0.branch,
                                       details: $0.details, history: $0.history, tuning: $0.tuning)
                })
        }, combatRules: rules)
    }

    public func getDesignArsenal() throws -> DesignArsenal {
        try content()
    }

    public func getCostsByLevel() throws -> [TowerKind: [Int: [Int: Int]]] {
        var result: [TowerKind: [Int: [Int: Int]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.tuning.cost
            }
        }
        return result
    }

    public func getNamesByLevel() throws -> [TowerKind: [Int: [Int: String]]] {
        var result: [TowerKind: [Int: [Int: String]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.details.name
            }
        }
        return result
    }

    public func getMenuDetailsByLevel() throws -> [TowerKind: [Int: [Int: TowerMenuDetails]]] {
        var result: [TowerKind: [Int: [Int: TowerMenuDetails]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.details
            }
        }
        return result
    }

    public func getTowerLevels() throws -> [TowerKind: [TowerLevel]] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.kind, $0.type.levels) })
    }

    public func getTowerLevelsByBranch() throws -> [TowerKind: [Int: [Int: TowerLevel]]] {
        var result: [TowerKind: [Int: [Int: TowerLevel]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.tuning
            }
        }
        return result
    }

    public func getTowerTypes() throws -> [TowerKind: TowerType] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.kind, $0.type) })
    }

    public func getDisplayNames() throws -> [TowerKind: String] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.kind, $0.name) })
    }
}
