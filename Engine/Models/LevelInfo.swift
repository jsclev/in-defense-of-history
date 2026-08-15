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
    public let playArea: CGRect
    public let mapImageName: String
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
                playArea: CGRect,
                mapImageName: String = "",
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
        self.playArea = playArea
        self.mapImageName = mapImageName
        self.paths = paths
        self.towerSlots = towerSlots
        self.waves = waves
    }
}
