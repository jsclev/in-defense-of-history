import Foundation
import CoreGraphics

/// A solid cannonball travels along its original bearing, hitting each enemy
/// at most once. Swept segments preserve penetration even across a long frame.
public struct SolidShotFlight: Sendable, Codable {
    public let hitRadius: CGFloat
    public private(set) var remainingDistance: CGFloat
    public private(set) var hitIDs: Set<Int> = []

    public init(range: CGFloat, hitRadius: CGFloat) {
        precondition(range.isFinite && range >= 0 && hitRadius.isFinite && hitRadius > 0)
        remainingDistance = range
        self.hitRadius = hitRadius
    }

    public mutating func advance(from start: CGPoint, heading: CGFloat,
                                 speed: CGFloat, seconds: Double) -> CGPoint {
        guard heading.isFinite, speed.isFinite, speed > 0,
              seconds.isFinite, seconds > 0 else { return start }
        let distance = min(remainingDistance, speed * CGFloat(seconds))
        remainingDistance -= distance
        return CGPoint(x: start.x + cos(heading) * distance,
                       y: start.y + sin(heading) * distance)
    }

    /// Return all new contacts in travel order; the first enemy does not stop the ball.
    public mutating func contacts(from start: CGPoint, to end: CGPoint,
                                   targets: [(id: Int, position: CGPoint)]) -> [Int] {
        let hits = targets.compactMap { target -> (id: Int, fraction: CGFloat)? in
            guard !hitIDs.contains(target.id),
                  let fraction = GrapeshotFlight.hitFraction(from: start, to: end,
                    target: target.position, radius: hitRadius) else { return nil }
            return (target.id, fraction)
        }.sorted { $0.fraction == $1.fraction ? $0.id < $1.id : $0.fraction < $1.fraction }
        var result: [Int] = []
        for hit in hits where hitIDs.insert(hit.id).inserted { result.append(hit.id) }
        return result
    }
}
