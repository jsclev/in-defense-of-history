import Foundation

extension HeroDAO {
    public func getAIConfigurations() throws -> [UUID: HeroAIConfiguration] {
        let rows = try authoredRows("""
            SELECT h.id, a.controller, a.decision_interval,
                   a.retreat_health_fraction, a.resume_health_fraction
            FROM hero h LEFT JOIN hero_ai a ON a.hero_id = h.id ORDER BY h.id
            """, entity: "hero_ai") { row in
                let id = try row.uuid("id")
                let row = AuthoredRow(statement: row.statement, entity: "hero_ai[\(id)]")
                let key = try row.text("controller")
                guard let controller = HeroAIKind(rawValue: key) else {
                    throw row.invalid("controller", "unknown identifier '\(key)'")
                }
                let retreat = try row.number("retreat_health_fraction", minimum: 0, strictlyGreater: true, maximum: 1)
                let resume = try row.number("resume_health_fraction", minimum: retreat, strictlyGreater: true, maximum: 1)
                return (id, HeroAIConfiguration(controller: controller,
                    decisionInterval: try row.number("decision_interval", minimum: 0, strictlyGreater: true, maximum: 60),
                    retreatHealthFraction: retreat, resumeHealthFraction: resume))
            }
        guard !rows.isEmpty else { throw DbError.Db(message: "hero_ai: missing authored roster") }
        return Dictionary(uniqueKeysWithValues: rows)
    }
}
