import Foundation

public struct Difficulty: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let level: Int
    public let name: String
    public let detail: String
    public let enemyHPMultiplier: Double

    public init(id: UUID, level: Int, name: String, detail: String,
                enemyHPMultiplier: Double) {
        self.id = id
        self.level = level
        self.name = name
        self.detail = detail
        self.enemyHPMultiplier = enemyHPMultiplier
    }
}
