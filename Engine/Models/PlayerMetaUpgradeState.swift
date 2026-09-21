import Foundation

public enum MetaUpgradeProfile: String, CaseIterable, Sendable {
    case active, level15
}

/// Database snapshot. The earned budget is derived from the complete level ledger.
public struct PlayerMetaUpgradeState: Equatable, Sendable {
    public let loadout: MetaUpgradeLoadout
    public let bestStarsByLevel: [UUID: Int]

    /// A pre-battle respec uses the same validation as a persisted selection.
    /// The earned ledger and SQL catalog remain unchanged.
    public func selecting(_ upgrades: Set<MetaUpgrade>) throws -> Self {
        try Self(catalog: loadout.catalog, selected: upgrades, bestStarsByLevel: bestStarsByLevel)
    }

    init(catalog: MetaUpgradeCatalog, selected: Set<MetaUpgrade>, bestStarsByLevel: [UUID: Int], profile: MetaUpgradeProfile = .active) throws {
        for (level, stars) in bestStarsByLevel where !(0...3).contains(stars) {
            throw DbError.Db(message: "player_meta_upgrade_level_stars[\(profile.rawValue):\(level)]: attribute 'best_stars' must be between 0 and 3")
        }
        for upgrade in selected {
            if let prerequisite = catalog[upgrade].prerequisite, !selected.contains(prerequisite) {
                throw DbError.Db(message: "player_meta_upgrade_selection[\(profile.rawValue):\(upgrade.rawValue)]: attribute 'is_selected' requires \(prerequisite.rawValue)")
            }
        }
        let budget = bestStarsByLevel.values.reduce(0, +)
        guard selected.reduce(0, { $0 + catalog[$1].cost }) <= budget else {
            throw DbError.Db(message: "player_meta_upgrade_selection[\(profile.rawValue)]: attribute 'is_selected' spends more than the \(budget) stars in player_meta_upgrade_level_stars")
        }
        self.loadout = try MetaUpgradeLoadout(catalog: catalog, starBudget: budget, selected: selected)
        self.bestStarsByLevel = bestStarsByLevel
    }
}
