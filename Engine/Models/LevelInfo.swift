import Foundation
import CoreGraphics

public struct LevelInfo: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let campaign: Campaign
    public let startingMoney: Int
    public var numStartingLives: Int
    public var numWaves: Int
    public let startedAt: Date
    public let endedAt: Date
    public let playableRect: CGRect
    public let mapImageName: String
    public let mapImageSize: CGSize
    /// Box the map renderer fits the tower slot sprite into, in map image
    /// pixels. `.zero` when the level has no slot-canvas tower art.
    public let slotSize: CGSize
    public var paths: [Path]
    public var towerSlots: [TowerSlot]
    public var waves: [Wave]

    public init(id: UUID,
                name: String,
                campaign: Campaign,
                startedAt: Date,
                endedAt: Date,
                startingMoney: Int,
                numStartingLives: Int,
                numWaves: Int = 0,
                playableRect: CGRect,
                mapImageName: String = "",
                mapImageSize: CGSize = .zero,
                slotSize: CGSize = .zero,
                paths: [Path],
                towerSlots: [TowerSlot],
                waves: [Wave]) {
        self.id = id
        self.name = name
        self.campaign = campaign
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startingMoney = startingMoney
        self.numStartingLives = numStartingLives
        self.numWaves = numWaves
        self.playableRect = playableRect
        self.mapImageName = mapImageName
        self.mapImageSize = mapImageSize
        self.slotSize = slotSize
        self.paths = paths
        self.towerSlots = towerSlots
        self.waves = waves
    }
}
