import Foundation

/// Constrain factory choices to the earned ledger for a campaign experiment.
/// Stars group comparisons; each choice is explicit validated upgrade DNA.
public struct GeneticMetaSearch {
    public let earnedStars: Int
    public let factory: MetaUpgradesFactory
    public let choicesByStars: [Int: [MetaUpgradeProgression]]

    public static func key(_ selection: MetaUpgradeProgression) -> String { selection.key }
    public static func nearestSelections(to selection: MetaUpgradeProgression,
        among choices: [MetaUpgradeProgression]) -> [MetaUpgradeProgression] {
        MetaUpgradesFactory.nearest(to: selection, among: choices)
    }

    public init(player: PlayerMetaUpgradeState) throws {
        factory = try MetaUpgradesFactory(catalog: player.loadout.catalog)
        earnedStars = player.loadout.starBudget
        let budget = player.loadout.starBudget
        choicesByStars = factory.progressionsBySpentStars.filter { $0.key <= budget }
    }
}
