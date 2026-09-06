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
    public static let frameCount = 64
    public static let cycleDistance: Double = 48
    public static let standingFrame = 16
    public static let walkingThreshold: Double = 0.5

    public static func interpolatedPhase(currentPhase: Double,
                                         stepDistance: Double,
                                         alpha: Double,
                                         cycleDistance: Double) -> Double {
        let clampedAlpha = min(max(alpha, 0), 1)
        let phase = currentPhase - stepDistance * (1 - clampedAlpha)
        return (phase.truncatingRemainder(dividingBy: cycleDistance)
                + cycleDistance)
            .truncatingRemainder(dividingBy: cycleDistance)
    }

    public static func assetName(facing: UnitFacing,
                                 walkPhase: Double,
                                 isWalking: Bool) -> String {
        let pitch = cycleDistance / Double(frameCount)
        let frame = isWalking ? Int(walkPhase / pitch) % frameCount : standingFrame
        return "militia_soldier_walk_\(facing.assetSuffix)_\(frame)"
    }
}

public enum HeroWalkCycle {
    public static let cycleDistance: Double = 75.6
    public static let henryKnoxAssetName = "hero_unit_henry_knox"
    public static let georgeWashingtonAssetName = "hero_unit_george_washington"
    public static let georgeWashingtonFrameCount = 16
    public static let danielMorganAssetName = "hero_unit_daniel_morgan"
    public static let danielMorganFrameCount = 16
    public static let salemPoorAssetName = "hero_unit_salem_poor"
    public static let salemPoorFrameCount = 16
    public static let johnGloverAssetName = "hero_unit_john_glover"
    public static let johnGloverFrameCount = 16

    private static let animatedAssetNames: Set<String> = [
        henryKnoxAssetName,
        georgeWashingtonAssetName,
        danielMorganAssetName,
        salemPoorAssetName,
        johnGloverAssetName,
    ]

    private static let directionalFrameCounts: [String: Int] = [
        georgeWashingtonAssetName: georgeWashingtonFrameCount,
        danielMorganAssetName: danielMorganFrameCount,
        salemPoorAssetName: salemPoorFrameCount,
        johnGloverAssetName: johnGloverFrameCount,
    ]

    public static func assetName(baseAssetName: String,
                                 facing: UnitFacing,
                                 walkPhase: Double,
                                 isWalking: Bool) -> String {
        guard animatedAssetNames.contains(baseAssetName) else { return baseAssetName }
        if let frameCount = directionalFrameCounts[baseAssetName] {
            guard isWalking else { return "\(baseAssetName)_idle_\(facing.assetSuffix)" }
            let pitch = cycleDistance / Double(frameCount)
            let frame = Int(walkPhase / pitch) % frameCount
            return "\(baseAssetName)_walk_\(facing.assetSuffix)_\(frame)"
        }
        let pitch = cycleDistance / Double(MeleeWalkCycle.frameCount)
        let frame = isWalking
            ? Int(walkPhase / pitch) % MeleeWalkCycle.frameCount
            : MeleeWalkCycle.standingFrame
        return "\(baseAssetName)_walk_\(facing.assetSuffix)_\(frame)"
    }
}
