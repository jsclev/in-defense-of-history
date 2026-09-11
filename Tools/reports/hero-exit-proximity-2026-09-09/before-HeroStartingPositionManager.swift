import Foundation
import CoreGraphics

/// The full image canvas, including transparent padding and shadow. The renderer
/// and starting-position manager use the same dimensions and ground anchor.
public struct HeroSpriteFootprint: Equatable {
    public let size: CGSize
    public let groundInset: CGFloat

    public init(baseAssetName: String, aspectRatio: CGFloat, playableHeight: CGFloat) {
        let height = MapSpriteSizing.hero(baseAssetName: baseAssetName)
            .resolved(playableHeightOnScreen: playableHeight)
        size = CGSize(width: height * aspectRatio, height: height)
        groundInset = MapSpriteSizing.heroGroundInset(baseAssetName: baseAssetName, spriteHeight: height)
    }

    /// Screen coordinates (+Y down), anchored at the hero's feet.
    public func frame(at foot: CGPoint) -> CGRect {
        CGRect(x: foot.x - size.width / 2, y: foot.y - size.height + groundInset,
               width: size.width, height: size.height)
    }
}

public struct HeroStartingPlacement: Equatable {
    public let heroID: UUID
    public let exit: HeroExitSpawn
    public let position: Point
    public let spriteFrame: CGRect
}

/// Resolves authored hero/exit associations into visible starting positions.
/// All clearance decisions use screen points; only the resulting foot position
/// is converted back to canonical map coordinates for movement and respawning.
public final class HeroStartingPositionManager {
    public let edgeMargin: CGFloat
    public let exitClearance: CGFloat
    private let canvas: RuntimeCanvas
    private let paths: [Path]
    private let exits: [CGPoint]
    private let exclusions: [CGRect]

    public init(runtimeCanvas: RuntimeCanvas, paths: [Path], exits: [Point],
                obstacles: [CGRect] = []) {
        canvas = runtimeCanvas
        self.paths = paths
        edgeMargin = max(6, runtimeCanvas.playAreaRect.height * 0.015)
        exitClearance = max(8, runtimeCanvas.virtualCanvas.pathWidth * runtimeCanvas.scaleFactor / 2)
            + edgeMargin
        func project(_ point: Point) -> CGPoint {
            CGPoint(x: runtimeCanvas.playAreaRect.minX
                    + (point.x - runtimeCanvas.virtualCanvas.playAreaRect.minX) * runtimeCanvas.scaleFactor,
                    y: runtimeCanvas.playAreaRect.maxY
                    - (point.y - runtimeCanvas.virtualCanvas.playAreaRect.minY) * runtimeCanvas.scaleFactor)
        }
        self.exits = exits.map(project)
        exclusions = runtimeCanvas.occlusionAreas.filter { !$0.isEmpty } + obstacles
    }

    public func placement(for deployment: HeroDeployment, imageAspectRatio: CGFloat,
                          avoiding occupied: [HeroStartingPlacement] = []) throws -> HeroStartingPlacement {
        guard let asset = deployment.hero.unitImageName,
              imageAspectRatio.isFinite, imageAspectRatio > 0,
              canvas.scaleFactor.isFinite, canvas.scaleFactor > 0 else {
            throw DbError.Db(message: "Hero placement needs a sprite size and a valid runtime play area")
        }
        let footprint = HeroSpriteFootprint(baseAssetName: asset, aspectRatio: imageAspectRatio,
                                            playableHeight: canvas.playAreaRect.height)
        let bounds = canvas.playAreaRect
        // Asymmetric vertical insets protect both the head and the shadow below the feet.
        let feet = CGRect(x: bounds.minX + edgeMargin + footprint.size.width / 2,
                          y: bounds.minY + edgeMargin + footprint.size.height - footprint.groundInset,
                          width: bounds.width - 2 * edgeMargin - footprint.size.width,
                          height: bounds.height - 2 * edgeMargin - footprint.size.height)
        guard feet.width > 0, feet.height > 0 else {
            throw DbError.Db(message: "The runtime play area is too small for \(deployment.hero.shortName)")
        }
        let exit = deployment.spawn.position
        let exitPoint = viewPoint(exit)
        // Associate by actual geometry, including exits partway along a route.
        let routes = paths.filter { $0.totalLength > 0 && $0.totalLength.isFinite }
        guard let path = routes.min(by: {
            $0.point(atDistance: $0.nearestDistance(to: exit)).distance(to: exit)
                < $1.point(atDistance: $1.nearestDistance(to: exit)).distance(to: exit)
        }) else {
            throw DbError.Db(message: "Hero exit \(deployment.spawn.exitID) needs a nearby path")
        }
        func clamped(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, feet.minX), feet.maxX),
                    y: min(max(point.y, feet.minY), feet.maxY))
        }
        let closestVisible = clamped(exitPoint)
        let reach = max(footprint.size.height * 4, exitClearance * 3)
            + hypot(closestVisible.x - exitPoint.x, closestVisible.y - exitPoint.y)
        let step = max(4, min(footprint.size.width, footprint.size.height) / 4)
        let distanceAtExit = path.nearestDistance(to: exit)
        var candidates: [CGPoint] = []
        // Prefer the local route and its shoulders, looking both ways when an
        // exit is on an interior path point rather than assuming the last point.
        for delta in stride(from: -reach, through: reach, by: step) {
            let distance = distanceAtExit + delta / canvas.scaleFactor
            let point = viewPoint(path.point(atDistance: distance))
            let before = viewPoint(path.point(atDistance: distance - step / canvas.scaleFactor))
            let after = viewPoint(path.point(atDistance: distance + step / canvas.scaleFactor))
            let length = hypot(after.x - before.x, after.y - before.y)
            let shoulder = exitClearance + footprint.size.width / 2
            for offset in [-shoulder, CGFloat.zero, shoulder] {
                let normal = length > 0 ? CGPoint(x: -(after.y - before.y) / length,
                                                  y: (after.x - before.x) / length) : .zero
                candidates.append(clamped(CGPoint(x: point.x + normal.x * offset,
                                                   y: point.y + normal.y * offset)))
            }
        }
        // Also search nearby visible ground. This handles corners, offscreen
        // exits and two heroes sharing an exit without stacking their sprites.
        let search = CGRect(x: exitPoint.x - reach, y: exitPoint.y - reach,
                            width: reach * 2, height: reach * 2).intersection(feet)
        if !search.isNull {
            for y in stride(from: search.minY, through: search.maxY, by: step) {
                for x in stride(from: search.minX, through: search.maxX, by: step) {
                    candidates.append(CGPoint(x: x, y: y))
                }
            }
        }
        var best: (score: CGFloat, point: CGPoint, frame: CGRect)?
        for point in candidates {
            let frame = footprint.frame(at: point)
            let padded = frame.insetBy(dx: -edgeMargin, dy: -edgeMargin)
            guard bounds.contains(padded),
                  !exclusions.contains(where: { $0.intersects(padded) }),
                  !occupied.contains(where: { $0.spriteFrame.intersects(padded) }) else { continue }
            // Keep the whole image clear of every exit mouth, not just its foot anchor.
            let exitPoints = exits + [exitPoint]
            guard exitPoints.allSatisfy({ exit in
                let dx = max(frame.minX - exit.x, 0, exit.x - frame.maxX)
                let dy = max(frame.minY - exit.y, 0, exit.y - frame.maxY)
                return hypot(dx, dy) >= exitClearance
            }) else { continue }
            let map = mapPoint(point)
            let routeGap = CGFloat(path.point(atDistance: path.nearestDistance(to: map)).distance(to: map))
                * canvas.scaleFactor
            let score = hypot(point.x - exitPoint.x, point.y - exitPoint.y) + routeGap * 0.6
            if best == nil || score < best!.score { best = (score, point, frame) }
        }
        guard let best else {
            throw DbError.Db(message: "No visible starting position near hero exit \(deployment.spawn.exitID)")
        }
        return HeroStartingPlacement(heroID: deployment.hero.id, exit: deployment.spawn,
                                     position: mapPoint(best.point), spriteFrame: best.frame)
    }

    private func viewPoint(_ point: Point) -> CGPoint {
        CGPoint(x: canvas.playAreaRect.minX
                + (point.x - canvas.virtualCanvas.playAreaRect.minX) * canvas.scaleFactor,
                y: canvas.playAreaRect.maxY
                - (point.y - canvas.virtualCanvas.playAreaRect.minY) * canvas.scaleFactor)
    }

    private func mapPoint(_ point: CGPoint) -> Point {
        Point(canvas.virtualCanvas.playAreaRect.minX + (point.x - canvas.playAreaRect.minX) / canvas.scaleFactor,
              canvas.virtualCanvas.playAreaRect.minY + (canvas.playAreaRect.maxY - point.y) / canvas.scaleFactor)
    }
}
