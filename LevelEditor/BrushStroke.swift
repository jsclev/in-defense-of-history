import Foundation
import CoreGraphics

/// A single raw sample taken while the brush is down.
struct BrushSample: Equatable {
    var point: Point
    /// Half-width in canvas units at this sample, already scaled by pressure.
    var halfWidth: Double
}

/// Live state for an in-progress brush stroke. Samples come in at whatever rate
/// the input device delivers; `commit` turns them into a road centreline plus
/// per-point half-widths.
struct BrushStroke: Equatable {
    var samples: [BrushSample] = []

    var isEmpty: Bool { samples.isEmpty }

    /// Drops samples closer than `minSpacing` so a slow hand doesn't pile up
    /// hundreds of points in one spot.
    mutating func add(_ sample: BrushSample, minSpacing: Double) {
        guard let last = samples.last else {
            samples.append(sample)
            return
        }
        if last.point.distance(to: sample.point) >= minSpacing {
            samples.append(sample)
        } else if sample.halfWidth > last.halfWidth {
            samples[samples.count - 1].halfWidth = sample.halfWidth
        }
    }
}

enum BrushGeometry {
    /// Chaikin corner-cutting: two passes turn a jittery freehand stroke into
    /// something that reads as a drawn road without collapsing its shape.
    static func smooth(_ pts: [Point], passes: Int = 2) -> [Point] {
        guard pts.count > 2 else { return pts }
        var out = pts
        for _ in 0..<passes {
            guard out.count > 2 else { break }
            var next: [Point] = [out[0]]
            for i in 0..<(out.count - 1) {
                let a = out[i], b = out[i + 1]
                next.append(Point(a.x * 0.75 + b.x * 0.25, a.y * 0.75 + b.y * 0.25))
                next.append(Point(a.x * 0.25 + b.x * 0.75, a.y * 0.25 + b.y * 0.75))
            }
            next.append(out[out.count - 1])
            out = next
        }
        return out
    }

    /// Same smoothing applied to the scalar width track, so widths stay aligned
    /// with the smoothed centreline.
    static func smooth(widths: [Double], passes: Int = 2) -> [Double] {
        guard widths.count > 2 else { return widths }
        var out = widths
        for _ in 0..<passes {
            guard out.count > 2 else { break }
            var next: [Double] = [out[0]]
            for i in 0..<(out.count - 1) {
                let a = out[i], b = out[i + 1]
                next.append(a * 0.75 + b * 0.25)
                next.append(a * 0.25 + b * 0.75)
            }
            next.append(out[out.count - 1])
            out = next
        }
        return out
    }

    /// Walks the polyline at a fixed arc-length step, carrying the width track
    /// along with it. Keeps waypoint spacing even, which is what the path
    /// follower and the exported geojson both want.
    static func resample(points: [Point], widths: [Double], every step: Double)
        -> (points: [Point], widths: [Double]) {
        guard points.count > 1, step > 0 else { return (points, widths) }
        func width(at i: Int) -> Double { widths.indices.contains(i) ? widths[i] : (widths.last ?? 0) }

        var outPts: [Point] = [points[0]]
        var outWs: [Double] = [width(at: 0)]
        var carry = 0.0

        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let segLen = a.distance(to: b)
            guard segLen > 0 else { continue }
            let wa = width(at: i), wb = width(at: i + 1)
            var travelled = step - carry
            while travelled <= segLen {
                let t = travelled / segLen
                outPts.append(Point.lerp(a, b, t))
                outWs.append(wa + (wb - wa) * t)
                travelled += step
            }
            carry = segLen - (travelled - step)
        }

        if let last = points.last, outPts.last?.distance(to: last) ?? .infinity > step * 0.25 {
            outPts.append(last)
            outWs.append(width(at: points.count - 1))
        }
        return (outPts, outWs)
    }

    /// Unit normals (left of travel) for each point on a polyline.
    static func normals(_ pts: [Point]) -> [Point] {
        guard pts.count > 1 else { return pts.map { _ in Point(0, -1) } }
        var out: [Point] = []
        for i in pts.indices {
            let prev = pts[max(0, i - 1)]
            let next = pts[min(pts.count - 1, i + 1)]
            var dx = next.x - prev.x
            var dy = next.y - prev.y
            let len = (dx * dx + dy * dy).squareRoot()
            if len > 0 {
                dx /= len
                dy /= len
            } else {
                dx = 1
                dy = 0
            }
            out.append(Point(-dy, dx))
        }
        return out
    }

    /// One side of the outer edge. `side` is +1 for the left offset, -1 for the right.
    static func offsetEdge(points: [Point], halfWidths: [Double], side: Double) -> [Point] {
        guard !points.isEmpty else { return [] }
        let ns = normals(points)
        return points.indices.map { i in
            let hw = halfWidths.indices.contains(i) ? halfWidths[i] : (halfWidths.last ?? 0)
            return Point(points[i].x + ns[i].x * hw * side,
                         points[i].y + ns[i].y * hw * side)
        }
    }

    /// The closed outer edge of a painted road: left side out, right side back.
    /// This is what "waypoints for the outer edge of the path" means — a ring
    /// you can export as a polygon.
    static func outerEdge(points: [Point], halfWidths: [Double]) -> [Point] {
        guard points.count >= 2 else { return [] }
        let left = offsetEdge(points: points, halfWidths: halfWidths, side: 1)
        let right = offsetEdge(points: points, halfWidths: halfWidths, side: -1)
        return left + right.reversed()
    }

    /// Turns a finished stroke into an evenly-spaced centreline + width track.
    static func commit(_ stroke: BrushStroke, spacing: Double)
        -> (points: [Point], halfWidths: [Double])? {
        let raw = stroke.samples
        guard raw.count >= 2 else { return nil }
        let smoothPts = smooth(raw.map(\.point))
        let smoothWs = smooth(widths: raw.map(\.halfWidth))
        let r = resample(points: smoothPts, widths: smoothWs, every: spacing)
        guard r.points.count >= 2 else { return nil }
        return (r.points, r.widths)
    }
}
