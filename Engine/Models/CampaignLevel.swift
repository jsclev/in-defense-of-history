import Foundation
import CoreGraphics

public struct CampaignLevel: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let worldMapPosition: CGPoint
    public let mapImageName: String

    public init(id: UUID,
                name: String,
                worldMapPosition: CGPoint,
                mapImageName: String) {
        self.id = id
        self.name = name
        self.worldMapPosition = worldMapPosition
        self.mapImageName = mapImageName
    }
}
