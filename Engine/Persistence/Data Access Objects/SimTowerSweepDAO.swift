import Foundation

public struct SimTowerSweepTuning: Decodable {
    public let upgradeGrowth: [Double]
    public let rof: [String: [Double]]
    public let splash: [String: [Double]]
    public let falloff: [Double]
    public let projectileSpeed: [String: [Double]]
    public let rangeModes: [String: String]
}

public final class SimTowerSweepDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "sim_tower_sweep", loggerName: SimTowerSweepDAO.self)
    }

    public func get(profile: String) throws -> SimTowerSweepTuning {
        let rows = try authoredRows("SELECT * FROM sim_tower_sweep", entity: "sim_tower_sweep") { row in
            let key = try row.text("profile")
            let row = AuthoredRow(statement: row.statement, entity: "sim_tower_sweep[\(key)]")
            let tuning: SimTowerSweepTuning
            do {
                tuning = try JSONDecoder().decode(SimTowerSweepTuning.self,
                    from: Data(try row.text("tuning").utf8))
            } catch {
                throw row.invalid("tuning", "cannot be decoded: \(error)")
            }
            func validate(_ values: [Double], field: String, positive: Bool) throws {
                guard !values.isEmpty, values.allSatisfy({ $0.isFinite && (positive ? $0 > 0 : $0 >= 0) }) else {
                    throw row.invalid(field, "must contain finite, valid search values")
                }
            }
            try validate(tuning.upgradeGrowth, field: "upgradeGrowth", positive: true)
            try validate(tuning.falloff, field: "falloff", positive: true)
            let kinds = Set(TowerKind.allCases.map(\.rawValue))
            for (field, grid) in [("rof", tuning.rof), ("splash", tuning.splash), ("projectileSpeed", tuning.projectileSpeed)] {
                guard Set(grid.keys) == kinds else { throw row.invalid(field, "must declare every tower kind") }
                for (kind, values) in grid { try validate(values, field: "\(field).\(kind)", positive: false) }
            }
            guard Set(tuning.rangeModes.keys) == kinds,
                  tuning.rangeModes.values.allSatisfy({ ["authored", "sweep"].contains($0) }) else {
                throw row.invalid("rangeModes", "must declare a range mode for every tower kind")
            }
            return (key, tuning)
        }
        let matches = rows.filter { $0.0 == profile }
        guard matches.count == 1 else { throw DbError.Db(message: "sim_tower_sweep: missing or duplicate profile '\(profile)'") }
        return matches[0].1
    }
}
