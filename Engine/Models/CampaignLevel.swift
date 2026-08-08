import Foundation
import CoreGraphics

public struct CampaignLevel: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let worldMapPosition: CGPoint
    public let mapImageName: String
    public let mapImageSize: CGSize

    public init(id: UUID,
                name: String,
                worldMapPosition: CGPoint,
                mapImageName: String,
                mapImageSize: CGSize) {
        self.id = id
        self.name = name
        self.worldMapPosition = worldMapPosition
        self.mapImageName = mapImageName
        self.mapImageSize = mapImageSize
    }
}
