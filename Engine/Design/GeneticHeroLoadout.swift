import Foundation

/// Fixed player choice for a GA run, including the level's actual deployments.
/// The engine owns ranking, spawn eligibility, combat and autonomous hero AI.
public struct GeneticHeroLoadout: Codable, Equatable, Sendable {
    public struct Deployment: Codable, Equatable, Sendable {
        public let heroID: UUID
        public let role: HeroSelection.Role
        public let spawnFeatureID: String
        public let position: Point
        public let aiEnabled: Bool
    }

    /// Primary then secondary, as resolved by HeroSelection from DAO rankings.
    public let selectedHeroIDs: [UUID]
    public let deployments: [Deployment]

    public init(content: BattleContent) throws {
        selectedHeroIDs = content.chosenHeroes.ids
        deployments = try content.deployments.map { deployment in
            guard let control = content.heroControls.first(where: { $0.id == deployment.hero.id }) else {
                throw DbError.Db(message: "player_hero_control[\(deployment.hero.id)]: missing ai_enabled")
            }
            return Deployment(heroID: deployment.hero.id, role: deployment.spawn.role,
                spawnFeatureID: deployment.spawn.featureID, position: deployment.spawn.position, aiEnabled: control.aiEnabled)
        }
        try validate()
    }

    func validate() throws {
        guard (1...HeroSelection.maxSelected).contains(selectedHeroIDs.count),
              Set(selectedHeroIDs).count == selectedHeroIDs.count,
              Set(deployments.map(\.heroID)).count == deployments.count,
              Set(deployments.map(\.role)).count == deployments.count else {
            throw DbError.Db(message: "genetic hero loadout: invalid or duplicate selectedHeroIDs/deployments")
        }
        for deployment in deployments {
            let slot = deployment.role == .primary ? 0 : 1
            guard selectedHeroIDs.indices.contains(slot), selectedHeroIDs[slot] == deployment.heroID,
                  !deployment.spawnFeatureID.isEmpty, deployment.position.x.isFinite, deployment.position.y.isFinite else {
                throw DbError.Db(message: "genetic hero loadout[\(deployment.heroID)]: invalid role/spawn/position")
            }
        }
    }
}
