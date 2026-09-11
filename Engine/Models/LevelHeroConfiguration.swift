import Foundation

/// The exact GeoJSON starting point for a ranking-based role, independent of hero ID.
public struct HeroSpawn: Sendable, Equatable {
    public let role: HeroSelection.Role
    public let featureID: String
    public let position: Point

    public init(role: HeroSelection.Role, featureID: String, position: Point) {
        self.role = role
        self.featureID = featureID
        self.position = position
    }
}

public struct HeroDeployment: Sendable, Equatable {
    public let hero: Hero
    public let spawn: HeroSpawn
}

/// Level capacity and starting positions come from GeoJSON. The player's choices
/// determine who fills those roles, using the latest database rankings.
public struct LevelHeroConfiguration: Sendable, Equatable {
    public let heroCount: Int
    public let spawns: [HeroSpawn]

    public init(heroCount: Int, spawns: [HeroSpawn]) throws {
        guard (0...2).contains(heroCount) else {
            throw DbError.Db(message: "GeoJSON heroCount must be 0, 1 or 2")
        }
        let expected: Set<HeroSelection.Role> = heroCount == 0 ? []
            : heroCount == 1 ? [.primary] : [.primary, .secondary]
        guard spawns.count == heroCount, Set(spawns.map(\.role)) == expected else {
            throw DbError.Db(message: "Place each available hero's starting point in the level editor and export the GeoJSON: primary for one hero; primary and secondary for two")
        }
        guard spawns.allSatisfy({ !$0.featureID.isEmpty && $0.position.x.isFinite && $0.position.y.isFinite }) else {
            throw DbError.Db(message: "Hero starts need an ID and finite coordinates")
        }
        self.heroCount = heroCount
        self.spawns = spawns.sorted { $0.role == .primary && $1.role == .secondary }
    }

    public func deployments(for chosen: HeroSelection) -> [HeroDeployment] {
        spawns.compactMap { spawn in
            let hero = spawn.role == .primary ? chosen.primary : chosen.secondary
            return hero.map { HeroDeployment(hero: $0, spawn: spawn) }
        }
    }
}
