import Foundation

final class TowerUpgradeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "tower_upgrade_path", loggerName: TowerUpgradeDAO.self)
    }

    func allPaths(towerIDs: Set<UUID>) throws -> [UUID: [TowerUpgradePath]] {
        let ranks = try authoredRows("SELECT * FROM tower_upgrade_rank ORDER BY path_id, rank", entity: "tower_upgrade_rank") { row in
            let path = try row.text("path_id")
            let rank = try row.integer("rank", minimum: 1)
            let row = AuthoredRow(statement: row.statement, entity: "tower_upgrade_rank[\(path):\(rank)]")
            let effects: [TowerUpgradeEffect]
            do { effects = try JSONDecoder().decode([TowerUpgradeEffect].self, from: Data(try row.text("effects_json").utf8)) }
            catch { throw row.invalid("effects_json", "must contain known attributes and numeric deltas: \(error)") }
            guard !effects.isEmpty, Set(effects.map(\.attribute)).count == effects.count else {
                throw row.invalid("effects_json", "must contain nonempty, unique attributes")
            }
            return (path, TowerUpgradeRank(rank: rank, cost: try row.integer("cost", minimum: 1),
                description: try row.text("rank_description"), effects: effects))
        }
        var ids = Set<String>()
        let paths = try authoredRows("SELECT * FROM tower_upgrade_path ORDER BY tower_id, slot", entity: "tower_upgrade_path") { row in
            let id = try row.text("id")
            let row = AuthoredRow(statement: row.statement, entity: "tower_upgrade_path[\(id)]")
            guard ids.insert(id).inserted else { throw row.invalid("id", "is duplicated") }
            let towerID = try row.uuid("tower_id")
            guard towerIDs.contains(towerID) else { throw row.invalid("tower_id", "does not identify an authored tower") }
            let slot = try row.integer("slot", minimum: 1)
            guard slot <= 2 else { throw row.invalid("slot", "must be 1 or 2") }
            let count = try row.integer("rank_count", minimum: 2)
            let selected = ranks.filter { $0.0 == id }.map(\.1)
            guard count == selected.count, selected.enumerated().allSatisfy({ $0.element.rank == $0.offset + 1 }) else {
                throw row.invalid("rank_count", "requires every sequential tower_upgrade_rank from 1 through \(count)")
            }
            let source = try row.text("source_url")
            guard let url = URL(string: source), url.scheme == "https", url.host != nil else {
                throw row.invalid("source_url", "must be an HTTPS historical reference")
            }
            return (towerID, TowerUpgradePath(id: id, slot: slot,
                name: try row.text("path_name"), description: try row.text("path_description"),
                iconName: try row.text("icon_name"), historicalBasis: try row.text("historical_basis"),
                sourceURL: source, ranks: selected))
        }
        guard Set(ranks.map(\.0)).isSubset(of: ids) else {
            throw DbError.Db(message: "tower_upgrade_rank: path_id does not identify an authored tower_upgrade_path")
        }
        return Dictionary(grouping: paths, by: \.0).mapValues { $0.map(\.1) }
    }

    func paths(for towerID: UUID, level: Int, expectedCount: Int,
               from all: [UUID: [TowerUpgradePath]]) throws -> [TowerUpgradePath] {
        guard expectedCount == (level == 4 ? 2 : 0) else {
            throw DbError.Db(message: "tower[\(towerID)]: upgrade_path_count must be 2 at level 4 and 0 before specialization")
        }
        let paths = all[towerID] ?? []
        guard paths.count == expectedCount, Set(paths.map(\.slot)) == Set(1..<(expectedCount + 1)) else {
            throw DbError.Db(message: "tower[\(towerID)]: upgrade_path_count requires exactly \(expectedCount) tower_upgrade_path rows with unique slots")
        }
        return paths
    }

    /// Validate every purchasable combination, including cross-track bounds.
    func validateCombinations(_ tuning: TowerLevel) throws {
        guard tuning.upgradePaths.count == 2 else { return }
        let first = tuning.upgradePaths[0], second = tuning.upgradePaths[1]
        for a in 0...first.ranks.count {
            for b in 0...second.ranks.count {
                _ = try tuning.resolvingUpgrades(ranks: [first.id: a, second.id: b])
            }
        }
    }
}
