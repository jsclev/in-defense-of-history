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
        let category: String
        let level: Int
        let branch: Int
        let details: TowerMenuDetails
        let tuning: TowerLevel
    }

    public func validateAuthoredContent() throws {
        _ = try content()
    }

    private func identities() throws -> [Identity] {
        let values = try authoredRows("SELECT * FROM tower_type", entity: "tower_type") { row in
            let id = try row.uuid("id")
            let row = AuthoredRow(statement: row.statement, entity: "tower_type[\(id)]")
            let category = try row.text("tower_type_category")
            guard let kind = TowerKind(categoryName: category) else {
                throw row.invalid("tower_type_category", "is unsupported")
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
        let kinds = values.compactMap { TowerKind(categoryName: $0.category) }
        guard Set(kinds) == Set(TowerKind.allCases), Set(kinds).count == values.count else {
            throw DbError.Db(message: "tower_type: missing or duplicate tower category")
        }
        return values
    }

    private func tuning(_ row: AuthoredRow, melee: MeleeUnitStats?, rules: CombatRules) throws -> TowerLevel {
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
                slowFraction: slow, verticalFraction: rules.rangeVerticalFraction)
        } else {
            try row.requireNull("obstacle_radius")
            try row.requireNull("obstacle_slow_fraction")
            obstacles = nil
        }
        guard let targeting = Targeting(rawValue: try row.text("targeting")) else {
            throw row.invalid("targeting", "is unsupported")
        }
        let minimumDamage = try row.number("shot_min_damage", minimum: 0)
        let minimumTerror = try row.number("terror_min", minimum: 0)
        return TowerLevel(
            combatRules: rules, attackMode: mode, turnRateDegrees: turnRate,
            cost: try row.integer("cost", minimum: 0),
            range: try row.number("tower_range", minimum: 0, strictlyGreater: true),
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
            engineerObstacles: obstacles)
    }

    private func content() throws -> DesignArsenal {
        let rules = try combatRulesDao.get()
        let types = try identities()
        let melee = try meleeUnitDao.getStatsByTowerId(combatRules: rules)
        let values = try authoredRows("""
            SELECT t.*, tt.tower_type_category
            FROM tower t LEFT JOIN tower_type tt ON tt.id = t.tower_type_id
            ORDER BY tt.tower_type_category, t.tower_level, t.branch
            """, entity: "tower") { row in
                let id = try row.uuid("id")
                let row = AuthoredRow(statement: row.statement, entity: "tower[\(id)]")
                return Record(id: id, category: try row.text("tower_type_category"),
                    level: try row.integer("tower_level", minimum: 1),
                    branch: try row.integer("branch", minimum: 1),
                    details: TowerMenuDetails(name: try row.text("tower_name"),
                                              description: try row.text("tower_description")),
                    tuning: try tuning(row, melee: melee[id], rules: rules))
            }
        guard Set(melee.keys).isSubset(of: Set(values.map(\.id))) else {
            throw DbError.Db(message: "melee_unit: tower_id does not identify an authored tower")
        }
        for type in types {
            let rows = values.filter { $0.category == type.category }
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
                tiers: values.filter { $0.category == type.category }.map {
                    DesignArsenal.Tier(id: $0.id, level: $0.level, branch: $0.branch,
                                       details: $0.details, tuning: $0.tuning)
                })
        }, combatRules: rules)
    }

    public func getDesignArsenal() throws -> DesignArsenal {
        try content()
    }

    public func getCostsByLevel() throws -> [String: [Int: [Int: Int]]] {
        var result: [String: [Int: [Int: Int]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.category, default: [:]][tier.level, default: [:]][tier.branch] = tier.tuning.cost
            }
        }
        return result
    }

    public func getNamesByLevel() throws -> [String: [Int: [Int: String]]] {
        var result: [String: [Int: [Int: String]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.category, default: [:]][tier.level, default: [:]][tier.branch] = tier.details.name
            }
        }
        return result
    }

    public func getMenuDetailsByLevel() throws -> [String: [Int: [Int: TowerMenuDetails]]] {
        var result: [String: [Int: [Int: TowerMenuDetails]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.category, default: [:]][tier.level, default: [:]][tier.branch] = tier.details
            }
        }
        return result
    }

    public func getTowerLevels() throws -> [String: [TowerLevel]] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.category, $0.type.levels) })
    }

    public func getTowerLevelsByBranch() throws -> [String: [Int: [Int: TowerLevel]]] {
        var result: [String: [Int: [Int: TowerLevel]]] = [:]
        for tower in try content().towers {
            for tier in tower.tiers {
                result[tower.category, default: [:]][tier.level, default: [:]][tier.branch] = tier.tuning
            }
        }
        return result
    }

    public func getTowerTypes() throws -> [String: TowerType] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.category, $0.type) })
    }

    public func getDisplayNames() throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: try content().towers.map { ($0.category, $0.name) })
    }
}
