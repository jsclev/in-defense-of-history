import Foundation

public struct DesignArsenal: Sendable {
    public struct History: Sendable {
        public struct DemonstrationGuide: Sendable {
            public enum Style: String, Sendable { case mortarStudy, siegeStudy }
            public let style: Style
            public let strategy: String
            public let inclusionReason: String
        }
        public let description: String
        public let sourceTitle: String
        public let sourceURL: URL
        public let guide: DemonstrationGuide?
    }

    public struct Tier: Sendable {
        public let id: UUID
        public let level: Int
        public let branch: Int
        public let details: TowerMenuDetails
        public let history: History
        public let tuning: TowerLevel
    }

    public struct Definition: Sendable {
        public let id: UUID
        public let kind: TowerKind
        public let category: String
        public let name: String
        public let tiers: [Tier]

        public var type: TowerType {
            TowerType(id: id, name: name,
                      levels: tiers.filter { $0.branch == 1 }.map(\.tuning))
        }
    }

    public let combatRules: CombatRules
    public let towers: [Definition]

    init(towers: [Definition], combatRules: CombatRules) throws {
        guard Set(towers.map(\.kind)) == Set(TowerKind.allCases),
              Set(towers.map(\.kind)).count == towers.count,
              Set(towers.map(\.id)).count == towers.count else {
            throw DbError.Db(message: "tower_type: missing or duplicate tower identity")
        }
        for tower in towers {
            guard tower.tiers.contains(where: { $0.level == 1 && $0.branch == 1 }) else {
                throw DbError.Db(message: "tower_type[\(tower.id)]: missing first tower tier")
            }
        }
        self.towers = towers.sorted { $0.kind.rawValue < $1.kind.rawValue }
        self.combatRules = combatRules
    }

    public var kinds: [TowerKind] { towers.map(\.kind) }
    public var towerTypes: [TowerType] { towers.map(\.type) }

    public func type(_ kind: TowerKind) -> TowerType {
        guard let tower = towers.first(where: { $0.kind == kind }) else {
            fatalError("tower_type: missing authored tower kind \(kind.rawValue)")
        }
        return tower.type
    }

    public func kind(forTowerID id: UUID) -> TowerKind {
        guard let tower = towers.first(where: { $0.id == id }) else {
            fatalError("tower_type[\(id)]: unknown tower ID")
        }
        return tower.kind
    }

    public func emplacement(for persistedValue: String) -> TowerKind? {
        guard let kind = TowerKind(rawValue: persistedValue), kinds.contains(kind) else { return nil }
        return kind
    }

    public var rangeRings: [(name: String, range: Double)] {
        towerTypes.map { (name: $0.name, range: $0.levels[0].range) }.sorted { $0.range < $1.range }
    }

    public var maximumRange: Double {
        towers.flatMap(\.tiers).map { $0.tuning.range }.max()!
    }

    public func catalog(roster: DesignRoster) -> ContentCatalog {
        ContentCatalog(combatRules: combatRules, enemyTypes: roster.enemyTypes, towerTypes: towerTypes)
    }
}
