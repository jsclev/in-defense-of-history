import Foundation

public class EnemyTypeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "enemy_type", loggerName: EnemyTypeDAO.self)
    }

    public func getEncyclopedia() throws -> [EnemyEncyclopediaEntry] {
        let enemies = try getAll()
        let roster = try DesignRoster(enemyTypes: enemies).enemyTypes
        if let unknown = enemies.first(where: { enemy in !roster.contains(where: { $0.id == enemy.id }) }) {
            throw DbError.Db(message: "enemy_type[\(unknown.id)].enemy_type_key: unknown identity '\(unknown.key)'")
        }
        let entries = try authoredRows("SELECT * FROM enemy_encyclopedia", entity: "enemy_encyclopedia") { row in
            let id = try row.uuid("enemy_type_id")
            let record = AuthoredRow(statement: row.statement, entity: "enemy_encyclopedia[\(id)]")
            guard let enemy = roster.first(where: { $0.id == id }) else {
                throw record.invalid("enemy_type_id", "has no matching authored enemy")
            }
            let rawURL = try record.text("source_url")
            guard let url = URL(string: rawURL), url.scheme == "https",
                  let host = url.host, host.contains("."), url.user == nil, url.password == nil,
                  !rawURL.contains(where: \.isWhitespace) else {
                throw record.invalid("source_url", "must be an absolute HTTPS source URL")
            }
            return EnemyEncyclopediaEntry(enemy: enemy, strategy: try record.text("strategy_text"),
                history: try record.text("historical_description"), inclusionReason: try record.text("inclusion_reason"),
                adaptation: try record.text("adaptation_text"), sourceTitle: try record.text("source_title"), sourceURL: url)
        }
        return try roster.map { enemy in
            let matches = entries.filter { $0.id == enemy.id }
            guard matches.count == 1, let entry = matches.first else {
                throw DbError.Db(message: "enemy_encyclopedia[\(enemy.key)].enemy_type_id: missing or duplicate record")
            }
            return entry
        }
    }

    public func getAll() throws -> [EnemyType] {
        let roster = try authoredRows("SELECT * FROM enemy_type ORDER BY enemy_type_name", entity: "enemy_type") { row in
            let id = try row.uuid("id")
            let record = AuthoredRow(statement: row.statement, entity: "enemy_type \(id)")
            let minimum = try record.number("damage_min", minimum: 0)
            let maximum = try record.number("damage_max", minimum: minimum)
            let bandLo = try record.number("break_band_lo", minimum: 0, maximum: 1)
            let bandHi = try record.number("break_band_hi", minimum: bandLo, maximum: 1)
            let traits: [Trait]
            do {
                traits = try JSONDecoder().decode([Trait].self, from: Data(record.text("traits").utf8))
            } catch {
                throw record.invalid("traits", "must contain valid, complete authored traits: \(error)")
            }
            for trait in traits {
                switch trait {
                case let .rallyBeat(radius, rate):
                    guard radius.isFinite, radius > 0, rate.isFinite, rate >= 0 else {
                        throw record.invalid("traits.rallyBeat", "has invalid radius or moralePerSecond")
                    }
                case let .commandAura(radius, bonus, shock):
                    guard radius.isFinite, radius > 0, bonus.isFinite, (0...1).contains(bonus),
                          shock.isFinite, shock >= 0 else {
                        throw record.invalid("traits.commandAura", "has invalid radius, disciplineBonus or deathShock")
                    }
                default: break
                }
            }
            return EnemyType(id: id, key: try record.text("enemy_type_key"),
                name: try record.text("enemy_type_name"), description: try record.text("enemy_type_description"),
                imageName: try record.text("image_name"),
                stats: EnemyStats(
                    maxHP: try record.number("max_hp", minimum: 0, strictlyGreater: true),
                    speed: try record.number("speed", minimum: 0),
                    cover: try record.number("cover", minimum: 0, maximum: 1),
                    discipline: try record.number("discipline", minimum: 0, maximum: 1),
                    hardiness: try record.number("hardiness", minimum: 0, maximum: 1),
                    damageMin: minimum, damageMax: maximum,
                    gold: try record.integer("bounty", minimum: 0),
                    livesCost: try record.integer("lives_cost", minimum: 0), breakBand: bandLo...bandHi,
                    moraleResponse: EnemyMoraleResponse(
                        speedThreshold: try record.number("morale_speed_threshold", minimum: 0, maximum: 1),
                        attackThreshold: try record.number("morale_attack_threshold", minimum: 0, maximum: 1),
                        speedMultiplier: try record.number("morale_speed_multiplier", minimum: 0, maximum: 1),
                        attackMultiplier: try record.number("morale_attack_multiplier", minimum: 0, maximum: 1))),
                traits: traits)
        }
        guard !roster.isEmpty else { throw DbError.Db(message: "enemy_type: missing authored roster") }
        return roster
    }
}
