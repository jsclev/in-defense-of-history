import Foundation

public struct EnemyType: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let key: String
    /// Compact database-authored label for headings and lists.
    public let name: String
    /// Full database-authored name for detail pages.
    public let longName: String
    public let description: String
    public let imageName: String
    public let iconImageName: String
    public var stats: EnemyStats
    public var traits: [Trait]

    public init(id: UUID, key: String, name: String, longName: String, description: String, imageName: String, iconImageName: String,
                stats: EnemyStats, traits: [Trait] = []) {
        self.id = id
        self.key = key
        self.name = name
        self.longName = longName
        self.description = description
        self.imageName = imageName
        self.iconImageName = iconImageName
        self.stats = stats
        self.traits = traits
    }

    private enum CodingKeys: String, CodingKey {
        case id, key, name, longName, description, imageName, iconImageName, stats, traits
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        key = try values.decode(String.self, forKey: .key)
        name = try values.decode(String.self, forKey: .name)
        // Older saved recordings stored one name. This compatibility path
        // applies only to decoded recordings; the DAO requires both columns.
        longName = values.contains(.longName)
            ? try values.decode(String.self, forKey: .longName) : name
        guard !longName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .longName, in: values,
                debugDescription: "Enemy full name must not be empty")
        }
        description = try values.decode(String.self, forKey: .description)
        imageName = try values.decode(String.self, forKey: .imageName)
        // Legacy recordings predate separate encyclopedia artwork. New
        // database content always provides its required icon_image_name.
        iconImageName = values.contains(.iconImageName)
            ? try values.decode(String.self, forKey: .iconImageName) : imageName
        guard !iconImageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .iconImageName, in: values,
                debugDescription: "Enemy icon artwork name must not be empty")
        }
        stats = try values.decode(EnemyStats.self, forKey: .stats)
        traits = try values.decode([Trait].self, forKey: .traits)
    }

    public func has(_ trait: Trait) -> Bool {
        traits.contains(trait)
    }
}
