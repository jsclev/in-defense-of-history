import Foundation

public struct EnemyType: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public var stats: EnemyStats
    public var traits: [Trait]

    public init(id: UUID, name: String, stats: EnemyStats, traits: [Trait] = []) {
        self.id = id
        self.name = name
        self.stats = stats
        self.traits = traits
    }

    public func has(_ trait: Trait) -> Bool {
        traits.contains(trait)
    }
}
