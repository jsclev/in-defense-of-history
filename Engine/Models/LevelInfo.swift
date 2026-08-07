import Foundation
import CoreGraphics

public struct LevelInfo: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let campaign: Campaign
    public let startingMoney: Int
    public var numStartingLives: Int
    /// Designer-fixed wave count. `waves` may hold authored compositions, but
    /// simulators generating their own compositions must honor this count.
    /// 0 means the level predates the column; fall back to waves.count.
    public var numWaves: Int
    public let startedAt: Date
    public let endedAt: Date
    /// The internal, exactly-16:9 region of the level art (in the art's own
    /// pixel coordinates) that is always fully on screen — no map panning,
    /// ever. All gameplay content sits inside it; the renderer scales and
    /// centres the map so this rect exactly fits the running device's screen.
    public let playableRect: CGRect
    /// The map artwork this level draws, and its pixel dimensions. The
    /// playable rect above is expressed in these same pixels, so the two are
    /// only meaningful together.
    public let mapImageName: String
    public let mapImageSize: CGSize
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
        self.paths = paths
        self.towerSlots = towerSlots
        self.waves = waves
    }
}
