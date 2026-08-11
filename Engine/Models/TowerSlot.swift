import Foundation
import CoreGraphics

public struct TowerSlot: Codable, Equatable, Hashable, Sendable  {
    public let id: UUID
    public let position: Point

    /// Physical footprint of the slot pad, in canonical units, from
    /// tower_slot.slot_width/slot_height (synced from the level GeoJSON).
    /// `.zero` means this slot has no per-slot size and the level default in
    /// level_info applies.
    public let size: CGSize

    public init(id: UUID, position: Point, size: CGSize = .zero) {
        self.id = id
        self.position = position
        self.size = size
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
