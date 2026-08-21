import Foundation
import CoreGraphics

/// A pencil stroke in progress: just the points. Path width is fixed by
/// virtual_canvas.path_width and is not an authoring choice, so the stroke
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

    static func strokeArea(points: [Point], width: Double) -> CGPath {
        let line = CGMutablePath()
        guard let first = points.first else { return line }
        line.move(to: CGPoint(x: first.x, y: first.y))
        if points.count == 1 {
            line.addLine(to: CGPoint(x: first.x, y: first.y))
        } else {
            for p in points.dropFirst() { line.addLine(to: CGPoint(x: p.x, y: p.y)) }
        }
        return line.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }

    /// Cuts one width-carrying polyline with an eraser stroke, returning the
    /// pieces that survive. A cut through the middle returns two.
    ///
    /// The cut lands where the line CROSSES the eraser band, not merely where a
    /// point of it lands inside: a road whose waypoints sit further apart than
    /// the brush is wide would otherwise be uncuttable, and a run left holding a
    /// single waypoint would have no length to trim. Every piece end the eraser
    /// created is then pulled back by `halfWidth`, because the piece is drawn
    /// with a round cap of that radius — without the pull-back the cap fills the
    /// hole straight back in and a 60-wide erase across a 140-wide road would
    /// leave no visible gap at all.
    static func erase(polyline: [Point], halfWidth: Double,
                      with eraser: MapDraft.PaintStroke) -> [[Point]] {
        guard !polyline.isEmpty else { return [] }
        guard !eraser.points.isEmpty else { return [polyline] }
        let reach = eraser.width / 2
        func covers(_ p: Point) -> Bool {
            let d = eraser.points.count == 1
                ? p.distance(to: eraser.points[0])
                : p.distance(toPolyline: eraser.points)
            return d <= reach
        }
        guard polyline.count > 1 else { return covers(polyline[0]) ? [] : [polyline] }

        return survivingRuns(polyline, step: max(0.5, reach / 2), covers: covers)
            .compactMap { run in
                var piece = run.points
                if run.cutAtStart { piece = trimmingFront(piece, by: halfWidth) }
                if run.cutAtEnd { piece = trimmingBack(piece, by: halfWidth) }
                return piece.count >= 2 ? piece : nil
            }
    }

    private struct SurvivingRun {
        var points: [Point] = []
        var cutAtStart = false
        var cutAtEnd = false
    }

    /// The stretches of the polyline outside the covered region, each ending on
    /// the boundary itself. Segments are walked in `step` increments and each
    /// crossing is bisected onto the boundary, so the original points are kept
    /// and only the crossings are added.
    private static func survivingRuns(_ polyline: [Point], step: Double,
                                      covers: (Point) -> Bool) -> [SurvivingRun] {
        var runs: [SurvivingRun] = []
        var run: SurvivingRun?
        var state = covers(polyline[0])
        if !state { run = SurvivingRun(points: [polyline[0]]) }

        for i in 0..<(polyline.count - 1) {
            let a = polyline[i], b = polyline[i + 1]
            let length = a.distance(to: b)
            let steps = length > step ? Int((length / step).rounded(.up)) : 1
            var previousT = 0.0
            for s in 1...steps {
                let t = Double(s) / Double(steps)
                let covered = covers(Point.lerp(a, b, t))
                if covered != state {
                    var old = previousT, new = t
                    while (new - old) * length > 0.05 {
                        let mid = (old + new) / 2
                        if covers(Point.lerp(a, b, mid)) == state { old = mid } else { new = mid }
                    }
                    // The boundary point belongs to the surviving side.
                    let boundary = Point.lerp(a, b, covered ? old : new)
                    if covered {
                        run?.points.append(boundary)
                        run?.cutAtEnd = true
                        if let run { runs.append(run) }
                        run = nil
                    } else {
                        run = SurvivingRun(points: [boundary], cutAtStart: true)
                    }
                    state = covered
                }
                if s == steps, !state { run?.points.append(b) }
                previousT = t
            }
        }
        if let run { runs.append(run) }
        return runs
    }

    private static func trimmingFront(_ input: some Sequence<Point>,
                                      by distance: Double) -> [Point] {
        let pts = Array(input)
        guard distance > 0, pts.count > 1 else { return [] }
        var remaining = distance
        for i in 0..<(pts.count - 1) {
            let seg = pts[i].distance(to: pts[i + 1])
            if seg >= remaining {
                let cut = Point.lerp(pts[i], pts[i + 1], seg > 0 ? remaining / seg : 1)
                return [cut] + pts[(i + 1)...]
            }
            remaining -= seg
        }
        return []
    }

    private static func trimmingBack(_ pts: [Point], by distance: Double) -> [Point] {
        Array(trimmingFront(pts.reversed(), by: distance).reversed())
    }

    static func roadArea(roads: [MapDraft.Road], paint: [MapDraft.PaintStroke]) -> CGPath {
        var area = CGMutablePath() as CGPath
        for road in roads where road.points.count >= 2 {
            area = area.union(strokeArea(points: road.points, width: MapGeometry.roadHalfWidth * 2))
        }
        for stroke in paint where !stroke.points.isEmpty {
            area = area.union(strokeArea(points: stroke.points, width: stroke.width))
        }
        return area
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
