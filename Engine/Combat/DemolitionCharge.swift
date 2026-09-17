import Foundation
import CoreGraphics

/// A charge begins ready at the tower, awaiting the player's first placement.
/// Elapsed preparation never places or detonates a charge.
/// The caller advances only simulation time, so pausing and game speed apply.
public struct DemolitionCharge: Equatable, Sendable {
    public private(set) var position: CGPoint?
    public let preparationSeconds: Double
    public private(set) var remainingSeconds: Double

    public init(preparationSeconds: Double) {
        precondition(preparationSeconds.isFinite && preparationSeconds > 0)
        self.position = nil
        self.preparationSeconds = preparationSeconds
        self.remainingSeconds = 0
    }

    public var isReady: Bool { remainingSeconds == 0 }
    public var isReadyForPlacement: Bool { isReady && position == nil }
    public var progress: Double { 1 - remainingSeconds / preparationSeconds }

    /// Trigger immediately before a forward-moving enemy leaves the occupied
    /// part of the blast area. Follow its actual route, including bends and
    /// re-entries, rather than comparing screen-left/right or distance to goal.
    /// The target offset must match the point used to apply blast damage.
    public func willEnemyExitBlast(on path: Path, from distance: Double,
                                  advancingBy travel: Double, radius: Double,
                                  targetOffset: CGPoint = .zero) -> Bool {
        guard isReady, let position, radius.isFinite, radius > 0,
              distance.isFinite, travel.isFinite, travel > 0,
              distance >= 0, distance < path.totalLength else { return false }
        func isOutside(_ point: Point) -> Bool {
            hypot(point.x + targetOffset.x - position.x,
                  point.y + targetOffset.y - position.y) > radius
        }
        guard !isOutside(path.point(atDistance: distance)) else { return false }
        let end = min(path.totalLength, distance + travel)
        // A line segment between two points inside a circle stays inside it.
        // Check each intervening vertex so a bend that exits and re-enters
        // within this movement step cannot hide the first outgoing boundary.
        for index in 1..<path.points.count where path.cumulative[index] > distance {
            let next = min(end, path.cumulative[index])
            if isOutside(path.point(atDistance: next)) { return true }
            if next >= end { break }
        }
        // If the route ends inside the blast, fire before the enemy escapes.
        return end == path.totalLength
    }

    public mutating func advance(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        remainingSeconds = max(0, remainingSeconds - seconds)
    }

    /// Consumes the ready charge exactly once, then starts preparing the next.
    @discardableResult public mutating func detonate() -> Bool {
        guard isReady, position != nil else { return false }
        remainingSeconds = preparationSeconds
        return true
    }

    /// The first placement is immediately armed. Moving an existing site still
    /// restarts preparation so an armed bomb cannot be teleported.
    public mutating func place(at position: CGPoint) {
        guard position != self.position else { return }
        let isFirstPlacement = self.position == nil
        self.position = position
        if !isFirstPlacement { remainingSeconds = preparationSeconds }
    }
}
