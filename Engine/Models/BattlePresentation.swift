import CoreGraphics

/// Immutable presentation state for one production-engine tick. Live play and
/// recorded demonstrations use this exact interpolation, including at bends.
/// Interpolating path distance (rather than x/y) keeps enemies on their road.
struct BattlePresentation: Codable {
    let walkers: [BattleEngine.Walker]
    let projectiles: [BattleEngine.Projectile]
    let paths: [Path]
    let previousWalkerDistances: [Int: Double]
    let previousProjectilePositions: [Int: CGPoint]

    func displayedWalkers(alpha: Double) -> [BattleEngine.Walker] {
        let alpha = min(1, max(0, alpha))
        return walkers.map { walker in
            // A newly spawned enemy has no prior tick to interpolate from.
            guard let previous = previousWalkerDistances[walker.id] else { return walker }
            var displayed = walker
            let distance = previous + (walker.pathDistance - previous) * alpha
            let point = paths[walker.pathIndex].point(atDistance: distance)
            displayed.position = CGPoint(x: point.x, y: point.y)
            return displayed
        }
    }

    func displayedPosition(of projectile: BattleEngine.Projectile, alpha: Double) -> CGPoint {
        guard let previous = previousProjectilePositions[projectile.id] else { return projectile.position }
        let alpha = min(1, max(0, alpha))
        return CGPoint(x: previous.x + (projectile.position.x - previous.x) * alpha,
                       y: previous.y + (projectile.position.y - previous.y) * alpha)
    }
}
