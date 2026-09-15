import Foundation

/// The last two simulation positions and their distance-driven animation phase.
/// Advance once per simulation tick, even when a display frame catches up on
/// several ticks. Rendering then interpolates exactly one tick of both values.
public struct HeroWalkPose {
    public let baseAssetName: String
    public private(set) var position: Point
    public private(set) var previousPosition: Point
    public private(set) var facing: UnitFacing = .south
    public private(set) var walkPhase: Double = 0
    public private(set) var isWalking = false

    public init(baseAssetName: String, position: Point) {
        self.baseAssetName = baseAssetName
        self.position = position
        previousPosition = position
    }

    public mutating func advance(to position: Point) {
        previousPosition = self.position
        self.position = position
        let moved = previousPosition.distance(to: position)
        isWalking = moved > MeleeWalkCycle.walkingThreshold
        if isWalking {
            facing = UnitFacing(dx: position.x - previousPosition.x,
                                dy: position.y - previousPosition.y)
            walkPhase = (walkPhase + moved)
                .truncatingRemainder(dividingBy: HeroWalkCycle.cycleDistance(for: baseAssetName))
        }
    }

    public struct Sample {
        public let position: Point
        public let walkPhase: Double
        public let assetName: String
    }

    public func sample(alpha: Double) -> Sample {
        let alpha = min(max(alpha, 0), 1)
        let phase = MeleeWalkCycle.interpolatedPhase(
            currentPhase: walkPhase,
            stepDistance: isWalking ? previousPosition.distance(to: position) : 0,
            alpha: alpha, cycleDistance: HeroWalkCycle.cycleDistance(for: baseAssetName))
        return Sample(position: Point.lerp(previousPosition, position, alpha), walkPhase: phase,
                      assetName: HeroWalkCycle.assetName(baseAssetName: baseAssetName,
                          facing: facing, walkPhase: phase, isWalking: isWalking))
    }
}
