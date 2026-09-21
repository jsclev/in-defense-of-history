import Foundation

/// Enumerate purchase choices, not gameplay outcomes. Every edge is accepted
/// by the same MetaUpgradeLoadout.purchase API used by PlayerMetaUpgradeDAO.
/// No prerequisite, cost, or effect is reimplemented in the search.
public struct GeneticMetaSearch {
    public let earnedStars: Int
    public let choicesByStars: [Int: [[MetaUpgrade]]]

    public init(player: PlayerMetaUpgradeState) throws {
        earnedStars = player.loadout.starBudget
        let empty = try player.selecting([]).loadout
        let upgrades = empty.catalog.upgrades.map(\.id)
        var groups: [Int: [[MetaUpgrade]]] = [:]
        func visit(_ index: Int, _ loadout: MetaUpgradeLoadout) {
            guard index < upgrades.count else {
                groups[loadout.spentStars, default: []].append(loadout.selected.sorted { $0.rawValue < $1.rawValue })
                return
            }
            visit(index + 1, loadout)
            var purchased = loadout
            if purchased.purchase(upgrades[index]) { visit(index + 1, purchased) }
        }
        // DAO order places every prerequisite before its dependent upgrade.
        visit(0, empty)
        choicesByStars = groups
    }
}
