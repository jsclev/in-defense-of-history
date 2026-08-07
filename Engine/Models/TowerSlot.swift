import Foundation

public struct TowerSlot: Codable, Equatable, Hashable, Sendable  {
    public let id: UUID
    public let position: Point

    public init(id: UUID, position: Point) {
        self.id = id
        self.position = position
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
