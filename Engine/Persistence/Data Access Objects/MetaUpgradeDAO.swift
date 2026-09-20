import Foundation

/// Reads the entire authored tree, including unselected nodes. Invalid content
/// is fatal to the caller rather than silently hiding an unavailable upgrade.
public final class MetaUpgradeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "meta_upgrade", loggerName: MetaUpgradeDAO.self)
    }

    public func get() throws -> MetaUpgradeCatalog {
        let tracks = try authoredRows("SELECT * FROM meta_upgrade_track ORDER BY display_order", entity: "meta_upgrade_track") { row in
            let key = try row.text("track_key")
            let row = AuthoredRow(statement: row.statement, entity: "meta_upgrade_track[\(key)]")
            guard let id = MetaUpgradeTrack(rawValue: key) else { throw row.invalid("track_key", "is unknown") }
            return MetaUpgradeTrackDefinition(id: id, title: try row.text("title"),
                shortTitle: try row.text("short_title"), order: try row.integer("display_order", minimum: 1))
        }
        for key in MetaUpgradeTrack.allCases where !tracks.contains(where: { $0.id == key }) {
            throw DbError.Db(message: "meta_upgrade_track[\(key.rawValue)]: missing record")
        }
        guard Set(tracks.map(\.id)).count == tracks.count, Set(tracks.map(\.order)).count == tracks.count else {
            throw DbError.Db(message: "meta_upgrade_track: duplicate track_key or display_order")
        }
        let effects = try authoredRows("SELECT * FROM meta_upgrade_effect ORDER BY upgrade_key, parameter", entity: "meta_upgrade_effect") { row in
            let key = try row.text("upgrade_key"), parameter = try row.text("parameter")
            let row = AuthoredRow(statement: row.statement, entity: "meta_upgrade_effect[\(key):\(parameter)]")
            guard let upgrade = MetaUpgrade(rawValue: key) else { throw row.invalid("upgrade_key", "is unknown") }
            guard let field = MetaUpgradeParameter(rawValue: parameter), upgrade.requiredParameters.contains(field) else {
                throw row.invalid("parameter", "is unsupported for this upgrade")
            }
            let value = try row.number("value", minimum: 0, strictlyGreater: true)
            guard field.accepts(value) else { throw row.invalid("value", "is outside the valid range for \(parameter)") }
            return (upgrade, field, value)
        }
        let upgrades = try authoredRows("SELECT * FROM meta_upgrade ORDER BY track_key, display_order", entity: "meta_upgrade") { row in
            let key = try row.text("upgrade_key")
            let row = AuthoredRow(statement: row.statement, entity: "meta_upgrade[\(key)]")
            guard let id = MetaUpgrade(rawValue: key) else { throw row.invalid("upgrade_key", "is unknown") }
            guard let track = MetaUpgradeTrack(rawValue: try row.text("track_key")), tracks.contains(where: { $0.id == track }) else {
                throw row.invalid("track_key", "does not identify an authored track")
            }
            let prerequisite: MetaUpgrade?
            if let key = try row.optionalText("prerequisite_key") {
                guard let parsed = MetaUpgrade(rawValue: key) else { throw row.invalid("prerequisite_key", "is unknown") }
                prerequisite = parsed
            } else { prerequisite = nil }
            let amounts = effects.filter { $0.0 == id }
            let keys = Set(amounts.map(\.1))
            for missing in id.requiredParameters.subtracting(keys) {
                throw row.invalid("effects", "missing meta_upgrade_effect parameter '\(missing.rawValue)'")
            }
            guard amounts.count == keys.count else { throw row.invalid("effects", "contains duplicate parameters") }
            let cost = try row.integer("star_cost", minimum: 1)
            guard cost <= 1000 else { throw row.invalid("star_cost", "must be <= 1000") }
            let source = try row.text("source_url")
            guard let url = URL(string: source), url.scheme == "https", let host = url.host, !host.isEmpty else {
                throw row.invalid("source_url", "must be an HTTPS historical reference")
            }
            let iconName = try row.text("icon_name")
            guard iconName.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil else {
                throw row.invalid("icon_name", "must identify a canonical image asset using lowercase letters, digits and underscores")
            }
            return MetaUpgradeDefinition(id: id, track: track,
                tier: try row.integer("display_order", minimum: 1), cost: cost, prerequisite: prerequisite,
                title: try row.text("title"), detail: try row.text("description"), iconAssetName: iconName,
                historicalInformation: try row.text("historical_information"), sourceTitle: try row.text("source_title"),
                sourceURL: url, parameters: Dictionary(uniqueKeysWithValues: amounts.map { ($0.1, $0.2) }))
        }
        for key in MetaUpgrade.allCases where !upgrades.contains(where: { $0.id == key }) {
            throw DbError.Db(message: "meta_upgrade[\(key.rawValue)]: missing record")
        }
        guard Set(upgrades.map(\.id)).count == upgrades.count else {
            throw DbError.Db(message: "meta_upgrade: duplicate upgrade_key")
        }
        for track in tracks {
            let nodes = upgrades.filter { $0.track == track.id }.sorted { $0.tier < $1.tier }
            guard !nodes.isEmpty, nodes.enumerated().allSatisfy({ $0.element.tier == $0.offset + 1 }) else {
                throw DbError.Db(message: "meta_upgrade_track[\(track.id.rawValue)]: display_order requires contiguous upgrade rows")
            }
            for node in nodes {
                if let key = node.prerequisite {
                    guard let predecessor = nodes.first(where: { $0.id == key }), predecessor.tier < node.tier else {
                        throw DbError.Db(message: "meta_upgrade[\(node.id.rawValue)]: prerequisite_key must reference an earlier upgrade in the same track")
                    }
                }
            }
        }
        return MetaUpgradeCatalog(tracks: tracks, upgrades: tracks.flatMap { track in
            upgrades.filter { $0.track == track.id }.sorted { $0.tier < $1.tier }
        })
    }
}
