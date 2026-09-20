import Foundation

/// Shared timing and rally geometry used by the battle engine.
public enum BattleGeometry {
    public static func rallyPoint(
        requested: Point, towerPosition: Point, flagRange: Double, paths: [Path]
    ) -> Point {
        var best = requested
        var bestDist = Double.infinity
        for path in paths {
            var d = 0.0
            while d <= path.totalLength {
                let p = path.point(atDistance: d)
                let dist = p.distance(to: requested)
                if dist < bestDist {
                    bestDist = dist
                    best = p
                }
                d += 12
            }
        }
        let reach = towerPosition.distance(to: best)
        guard reach > flagRange else { return best }
        return Point.lerp(towerPosition, best, flagRange / reach)
    }

    public static func defaultRallyPoint(
        towerPosition: Point, flagRange: Double, paths: [Path]
    ) -> Point {
        var best = towerPosition
        var bestDist = Double.infinity
        for path in paths {
            var d = 0.0
            while d <= path.totalLength {
                let p = path.point(atDistance: d)
                let dist = p.distance(to: towerPosition)
                if dist < bestDist {
                    bestDist = dist
                    best = p
                }
                d += 12
            }
        }
        guard bestDist > flagRange else { return best }
        return Point.lerp(towerPosition, best, flagRange / bestDist)
    }

    public static func fireTicks(_ fireInterval: Double) -> Int {
        max(1, Int((fireInterval * Double(SimClock.ticksPerSecond)).rounded()))
    }
}
