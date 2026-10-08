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

/// Deployment identity, independent of combat stats and tower upgrades.
/// Tower slots are nonnegative; summoned garrisons have stable negative slots
/// and keep that sign in the soldier IDs written to historical recordings.
public enum MeleeUnitFamily: String, Codable, CaseIterable, Sendable {
    case towerMilitia = "militia_soldier"
    case reinforcement = "reinforcement_soldier"

    public init(garrisonSlot: Int) {
        self = garrisonSlot < 0 ? .reinforcement : .towerMilitia
    }

    public init(recordedSoldierID: Int) {
        self = recordedSoldierID < 0 ? .reinforcement : .towerMilitia
    }
}

public enum MeleeWalkCycle {
    public static let frameCount = 6
    public static let cycleDistance: Double = 48
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

    public static func assetName(family: MeleeUnitFamily, facing: UnitFacing,
                                 walkPhase: Double,
                                 isWalking: Bool) -> String {
        guard isWalking else { return MeleeAttackCycle.assetName(family: family, facing: facing, frame: 0) }
        let phase = (walkPhase.truncatingRemainder(dividingBy: cycleDistance) + cycleDistance)
            .truncatingRemainder(dividingBy: cycleDistance)
        let pitch = cycleDistance / Double(frameCount)
        let frame = min(frameCount - 1, Int(phase / pitch))
        return "\(family.rawValue)_walk_\(facing.assetSuffix)_\(frame)"
    }
}

/// Presentation only. The engine's authored swing countdown remains the sole
/// clock for damage. Contact is shown on that tick, followed by recovery, a
/// quiet guard, and anticipation of the next real swing.
public enum MeleeAttackCycle {
    public static let frameCount = 6

    public static func assetName(family: MeleeUnitFamily, facing: UnitFacing, frame: Int) -> String {
        precondition((0..<frameCount).contains(frame))
        return "\(family.rawValue)_attack_\(facing.assetSuffix)_\(frame)"
    }

    public static func assetName(family: MeleeUnitFamily, facing: UnitFacing, walkPhase: Double,
                                 isWalking: Bool, isFighting: Bool,
                                 swingTicksLeft: Int, attackInterval: Double,
                                 alpha: Double = 1) -> String {
        // Travelling and spacing use actual steps rather than playing attacks
        // while the soldier slides between positions.
        if isWalking {
            return MeleeWalkCycle.assetName(family: family, facing: facing, walkPhase: walkPhase, isWalking: true)
        }
        let intervalTicks = BattleGeometry.fireTicks(attackInterval)
        let elapsed = max(0, Double(intervalTicks - swingTicksLeft)
                          - (1 - min(max(alpha, 0), 1))) * SimClock.dt
        let poseSeconds = min(0.09, Double(intervalTicks) * SimClock.dt / 8)
        // Recovery survives a killing blow or disengagement; anticipation
        // requires an opponent so a waiting soldier never attacks empty air.
        if swingTicksLeft > 0, elapsed < poseSeconds * 3 {
            return assetName(family: family, facing: facing, frame: 3 + min(2, Int(elapsed / poseSeconds)))
        }
        if isFighting {
            let remaining = (Double(swingTicksLeft) + (1 - min(max(alpha, 0), 1))) * SimClock.dt
            if remaining <= poseSeconds { return assetName(family: family, facing: facing, frame: 2) }
            if remaining <= poseSeconds * 2 { return assetName(family: family, facing: facing, frame: 1) }
        }
        return assetName(family: family, facing: facing, frame: 0)
    }
}

public enum HeroWalkCycle {
    public static let cycleDistance: Double = 75.6
    /// A full left/right cycle, not a single footfall. At the shipped 180 map
    /// units/second, Washington takes 0.84 seconds per cycle (2.38 steps/second).
    /// Keep the same phase when changing between his 16- and 32-frame facings.
    public static func cycleDistance(for baseAssetName: String) -> Double {
        _ = HeroSpriteProfile.require(baseAssetName: baseAssetName)
        return baseAssetName == georgeWashingtonAssetName ? 151.2 : cycleDistance
    }
    public static let henryKnoxAssetName = "hero_unit_henry_knox"
    // The other catalog frames are optical-flow blends of these four drawings.
    // They contain doubled limbs, so playback must use the source poses only.
    public static let henryKnoxFrameIndices = [0, 16, 32, 48]
    public static let georgeWashingtonAssetName = "hero_unit_george_washington"
    public static let georgeWashingtonFrameCount = 16
    // The east cycle is exported from the offline artwork rig.
    public static let georgeWashingtonEastFrameCount = 32
    public static let danielMorganAssetName = "hero_unit_daniel_morgan"
    public static let danielMorganFrameCount = 16
    public static let salemPoorAssetName = "hero_unit_salem_poor"
    public static let salemPoorFrameCount = 16
    public static let johnGloverAssetName = "hero_unit_john_glover"
    public static let johnGloverFrameCount = 16
    public static let francisMarionAssetName = "hero_unit_francis_marion"
    public static let francisMarionFrameCount = 16
    public static let oldPutAssetName = "hero_unit_old_put"
    public static let oldPutFrameCount = 16
    public static let baronVonSteubenAssetName = "hero_unit_baron_von_steuben"
    public static let baronVonSteubenFrameCount = 16

    private static let animatedAssetNames: Set<String> = [
        henryKnoxAssetName,
        georgeWashingtonAssetName,
        danielMorganAssetName,
        salemPoorAssetName,
        johnGloverAssetName,
        francisMarionAssetName,
        oldPutAssetName,
        baronVonSteubenAssetName,
    ]

    private static let directionalFrameCounts: [String: Int] = [
        georgeWashingtonAssetName: georgeWashingtonFrameCount,
        danielMorganAssetName: danielMorganFrameCount,
        salemPoorAssetName: salemPoorFrameCount,
        johnGloverAssetName: johnGloverFrameCount,
        francisMarionAssetName: francisMarionFrameCount,
        oldPutAssetName: oldPutFrameCount,
        baronVonSteubenAssetName: baronVonSteubenFrameCount,
    ]

    /// Settle rear-facing arrivals into a profile so the hero's face stays visible.
    /// A straight north arrival turns right; diagonals retain their left/right side.
    private static func idleFacing(from facing: UnitFacing) -> UnitFacing {
        switch facing {
        case .north, .northEast: return .east
        case .northWest: return .west
        default: return facing
        }
    }

    public static func assetName(baseAssetName: String,
                                 facing: UnitFacing,
                                 walkPhase: Double,
                                 isWalking: Bool) -> String {
        _ = HeroSpriteProfile.require(baseAssetName: baseAssetName)
        guard animatedAssetNames.contains(baseAssetName) else { return baseAssetName }
        let cycleDistance = cycleDistance(for: baseAssetName)
        let facing = isWalking ? facing : idleFacing(from: facing)
        if baseAssetName == henryKnoxAssetName {
            let pitch = cycleDistance / Double(henryKnoxFrameIndices.count)
            let frame = isWalking
                ? henryKnoxFrameIndices[Int(walkPhase / pitch) % henryKnoxFrameIndices.count]
                : 16
            return "\(baseAssetName)_walk_\(facing.assetSuffix)_\(frame)"
        }
        if let frameCount = directionalFrameCounts[baseAssetName] {
            guard isWalking else { return "\(baseAssetName)_idle_\(facing.assetSuffix)" }
            let frameCount = baseAssetName == georgeWashingtonAssetName && facing == .east
                ? georgeWashingtonEastFrameCount : frameCount
            let pitch = cycleDistance / Double(frameCount)
            let frame = Int(walkPhase / pitch) % frameCount
            return "\(baseAssetName)_walk_\(facing.assetSuffix)_\(frame)"
        }
        fatalError("Missing hero animation metadata for '\(baseAssetName)'")
    }
}
