import SwiftUI

/// The editor's path renderer: three plain lines. A dark border, the light
/// dirt fill, a dark border - drawn as two strokes of the same splined
/// spine, the dark one full width and the light one inset by the border on
/// each side. Nothing else: the sprite-strip and vector-rim experiments are
/// gone; final path art is a later, hand-made pass.
///
/// Colors and the border width come from Images/PathEdges/palette.json in
/// the repo root (version controlled; written by in-defense-of-history-data/
/// Tools/generate_path_edge_images.py, fill sampled from the shipped Battle
/// Road art). The editor declares no road style of its own.
enum PathArtist {
    struct EdgePalette: Decodable {
        let fill: [Double]
        let edge: [Double]
        let borderUnits: Double?
    }

    static let palette: EdgePalette? = {
        guard let url = EditorResources.url("Images/PathEdges/palette.json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(EdgePalette.self, from: data)
    }()

    /// Deliberately signal-gray when the palette is missing: a wrong-looking
    /// road says "palette absent" louder than an invented brown would.
    static let fillColor: Color = color(palette?.fill, fallback: .gray)
    static let borderColor: Color = color(palette?.edge, fallback: Color(white: 0.3))

    private static func color(_ rgb: [Double]?, fallback: Color) -> Color {
        guard let rgb, rgb.count == 3 else { return fallback }
        return Color(red: rgb[0] / 255, green: rgb[1] / 255, blue: rgb[2] / 255)
    }

    /// Centripetal Catmull-Rom (alpha 0.5) through the waypoints — the same
    /// interpolation the level 1 generator uses, so the editor renders the
    /// curve the waypoints describe rather than the chords between them.
    static func splined(_ points: [Point]) -> [Point] {
        guard points.count >= 3 else { return points }
        let control = [points[0]] + points + [points[points.count - 1]]

        func lerp(_ a: Point, _ b: Point, _ ta: Double, _ tb: Double, _ time: Double) -> Point {
            guard tb - ta != 0 else { return a }
            let w = (time - ta) / (tb - ta)
            return Point(a.x + (b.x - a.x) * w, a.y + (b.y - a.y) * w)
        }

        var out: [Point] = []
        for i in 1..<(control.count - 2) {
            let p0 = control[i - 1], p1 = control[i], p2 = control[i + 1], p3 = control[i + 2]
            let t0 = 0.0
            let t1 = t0 + max(p0.distance(to: p1).squareRoot(), 1e-6)
            let t2 = t1 + max(p1.distance(to: p2).squareRoot(), 1e-6)
            let t3 = t2 + max(p2.distance(to: p3).squareRoot(), 1e-6)
            let samples = max(2, min(8, Int(p1.distance(to: p2) / 2)))
            for s in 0..<samples {
                let time = t1 + (t2 - t1) * Double(s) / Double(samples)
                let a1 = lerp(p0, p1, t0, t1, time)
                let a2 = lerp(p1, p2, t1, t2, time)
                let a3 = lerp(p2, p3, t2, t3, time)
                let b1 = lerp(a1, a2, t0, t2, time)
                let b2 = lerp(a2, a3, t1, t3, time)
                out.append(lerp(b1, b2, t1, t2, time))
            }
        }
        out.append(points[points.count - 1])
        return out
    }

    private static func spine(_ points: [Point], _ t: DesignTransform) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        // Smooth before splining: thin the dense waypoints to a 24-unit
        // shape, round the corners with four corner-cutting passes, then
        // interpolate the spline through the result. At this strength the
        // drawn curve relaxes toward long sweeping arcs; a deliberately
        // tight bend will round off by several units, traded away for a
        // line with no visible hand wander at all.
        let base = points.count >= 4
            ? BrushGeometry.smooth(BrushGeometry.resample(points: points, every: 24), passes: 4)
            : points
        let curve = splined(base)
        guard let first = curve.first else { return path }
        path.move(to: t.view(first))
        for p in curve.dropFirst() { path.addLine(to: t.view(p)) }
        return path
    }

    static func drawArea(_ ctx: inout GraphicsContext, _ area: SwiftUI.Path, _ t: DesignTransform) {
        ctx.fill(area, with: .color(fillColor))
        ctx.stroke(area, with: .color(borderColor),
                   style: StrokeStyle(lineWidth: max(1.5, (palette?.borderUnits ?? 3) * t.scale),
                                      lineCap: .round, lineJoin: .round))
    }

    /// The path's full-width outline, for selection highlights and hit areas.
    static func bodyPath(points: [Point], _ t: DesignTransform,
                         halfWidth: Double) -> SwiftUI.Path {
        guard points.count >= 2 else { return SwiftUI.Path() }
        let stroked = spine(points, t).cgPath.copy(
            strokingWithWidth: 2 * halfWidth * t.scale,
            lineCap: .butt,
            lineJoin: .round,
            miterLimit: 2)
        return SwiftUI.Path(stroked.normalized(using: .winding))
    }

    static func draw(_ ctx: inout GraphicsContext,
                     points: [Point],
                     _ t: DesignTransform,
                     halfWidth: Double,
                     wet: Bool = false) {
        guard points.count >= 2 else { return }

        // The whole road: the light band, outlined by one thin dark line
        // that runs along its edge. Nothing else.
        let body = bodyPath(points: points, t, halfWidth: halfWidth)
        ctx.fill(body, with: .color(fillColor))
        ctx.stroke(body, with: .color(borderColor),
                   style: StrokeStyle(lineWidth: max(1.5, (palette?.borderUnits ?? 3) * t.scale),
                                      lineCap: .round, lineJoin: .round))

        if wet {
            let line = spine(points, t)
            ctx.stroke(line, with: .color(.white.opacity(0.55)),
                       style: StrokeStyle(lineWidth: max(1.5, 2 * t.scale),
                                          lineCap: .round, dash: [6, 6]))
        }
    }
}
