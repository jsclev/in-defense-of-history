import Foundation

public enum UnitFacing: Int, CaseIterable, Sendable {
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
    case northWest

    public init(dx: Double, dy: Double) {
        let sector = Int((atan2(dx, dy) / (.pi / 4)).rounded())
        let count = Self.allCases.count
        self = UnitFacing(rawValue: (sector % count + count) % count) ?? .south
    }

    public var assetSuffix: String {
        switch self {
        case .north: return "n"
        case .northEast: return "ne"
        case .east: return "e"
        case .southEast: return "se"
        case .south: return "s"
        case .southWest: return "sw"
        case .west: return "w"
        case .northWest: return "nw"
        }
    }
}

public enum MeleeWalkCycle {
    public static let frameCount = 4
    public static let cycleDistance: Double = 48
    public static let standingFrame = 1
    public static let walkingThreshold: Double = 0.5

    public static func assetName(facing: UnitFacing,
                                 walkPhase: Double,
                                 isWalking: Bool) -> String {
        let pitch = cycleDistance / Double(frameCount)
        let frame = isWalking ? Int(walkPhase / pitch) % frameCount : standingFrame
        return "militia_soldier_walk_\(facing.assetSuffix)_\(frame)"
    }
}
