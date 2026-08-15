import Foundation
import CoreGraphics

/// A pencil stroke in progress: just the points. Path width is fixed by
/// canvas_spec.path_width and is not an authoring choice, so the stroke
/// carries no per-sample width.
struct BrushStroke: Equatable {
    var points: [Point] = []

    var isEmpty: Bool { points.isEmpty }

    mutating func add(_ point: Point, minSpacing: Double) {
        guard let last = points.last else {
            points.append(point)
            return
        }
        if last.distance(to: point) >= minSpacing {
            points.append(point)
        }
    }
}

enum BrushGeometry {
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

    static func resample(points: [Point], every step: Double) -> [Point] {
        guard points.count > 1, step > 0 else { return points }
        var out: [Point] = [points[0]]
        var carry = 0.0
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let segLen = a.distance(to: b)
            guard segLen > 0 else { continue }
            var travelled = step - carry
            while travelled <= segLen {
                out.append(Point.lerp(a, b, travelled / segLen))
                travelled += step
            }
            carry = segLen - (travelled - step)
        }
        if out.count < 2 || out[out.count - 1].distance(to: points[points.count - 1]) > step / 2 {
            out.append(points[points.count - 1])
        }
        return out
    }

    static func normals(_ points: [Point]) -> [Point] {
        points.indices.map { i in
            let prev = points[max(i - 1, 0)]
            let next = points[min(i + 1, points.count - 1)]
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
            return Point(-dy, dx)
        }
    }

    static func offsetEdge(points: [Point], side: Double) -> [Point] {
        guard !points.isEmpty else { return [] }
        let ns = normals(points)
        let hw = MapGeometry.roadHalfWidth
        return points.indices.map { i in
            Point(points[i].x + ns[i].x * hw * side,
                  points[i].y + ns[i].y * hw * side)
        }
    }

    static func outerEdge(points: [Point]) -> [Point] {
        guard points.count >= 2 else { return [] }
        let left = offsetEdge(points: points, side: 1)
        let right = offsetEdge(points: points, side: -1)
        return left + right.reversed()
    }

    static func commit(_ stroke: BrushStroke, spacing: Double) -> [Point]? {
        let raw = stroke.points
        guard raw.count >= 2 else { return nil }
        // Kill hand tremor BEFORE densifying: on samples only a unit or two
        // apart, corner-cutting smoothing barely changes the shape, so the
        // jitter would survive straight into the waypoints. Resampling to a
        // coarse 8-unit polyline first drops every wavelength shorter than a
        // pencil wobble, the smoothing rounds what remains, and only then are
        // the final dense waypoints laid out along that clean shape.
        let coarse = resample(points: raw, every: 8)
        let smoothed = smooth(coarse)
        let out = resample(points: smoothed, every: spacing)
        return out.count >= 2 ? out : nil
    }
}
