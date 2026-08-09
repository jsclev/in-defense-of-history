import Foundation
import CoreGraphics

struct BrushSample: Equatable {
    var point: Point
    var halfWidth: Double
}

struct BrushStroke: Equatable {
    var samples: [BrushSample] = []

    var isEmpty: Bool { samples.isEmpty }

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

    static func offsetEdge(points: [Point], halfWidths: [Double], side: Double) -> [Point] {
        guard !points.isEmpty else { return [] }
        let ns = normals(points)
        return points.indices.map { i in
            let hw = halfWidths.indices.contains(i) ? halfWidths[i] : (halfWidths.last ?? 0)
            return Point(points[i].x + ns[i].x * hw * side,
                         points[i].y + ns[i].y * hw * side)
        }
    }

    static func outerEdge(points: [Point], halfWidths: [Double]) -> [Point] {
        guard points.count >= 2 else { return [] }
        let left = offsetEdge(points: points, halfWidths: halfWidths, side: 1)
        let right = offsetEdge(points: points, halfWidths: halfWidths, side: -1)
        return left + right.reversed()
    }

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
