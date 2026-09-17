import Foundation

public struct EnemyType: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let key: String
    public let name: String
    public let description: String
    public let imageName: String
    public var stats: EnemyStats
    public var traits: [Trait]

    public init(id: UUID, key: String, name: String, description: String, imageName: String,
                stats: EnemyStats, traits: [Trait] = []) {
        self.id = id
        self.key = key
        self.name = name
        self.description = description
        self.imageName = imageName
        self.stats = stats
        self.traits = traits
    }

    public func has(_ trait: Trait) -> Bool {
        traits.contains(trait)
    }
}
