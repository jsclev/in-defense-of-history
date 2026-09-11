import CoreGraphics

/// Converts the actual union drawn by the editor into one GeoJSON geometry.
/// Disconnected islands become MultiPolygon members; holes stay holes.
enum PathFlattening {
    static func geometry(from area: CGPath) throws -> LevelGeoJSON.Geometry {
        // Round joins and tight brush turns can overlap themselves. Resolve
        // those overlaps before converting to GeoJSON's exterior/hole rings.
        let flat = area.normalized(using: .winding).flattened(threshold: 0.25)
        var rings: [LevelGeoJSON.Geometry.Ring] = []
        var ring: LevelGeoJSON.Geometry.Ring = []
        func finish() {
            defer { ring = [] }
            guard ring.count >= 3 else { return }
            if ring.last != ring.first { ring.append(ring[0]) }
            if abs(LevelGeoJSON.Geometry.signedArea(ring)) > 0 { rings.append(ring) }
        }
        flat.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                finish()
                ring = [[e.points[0].x, e.points[0].y]]
            case .addLineToPoint:
                let p: [Double] = [e.points[0].x, e.points[0].y]
                if ring.last != p { ring.append(p) }
            case .closeSubpath: finish()
            default: break // flattened(threshold:) has removed all curves.
            }
        }
        finish()
        rings.sort { abs(LevelGeoJSON.Geometry.signedArea($0)) > abs(LevelGeoJSON.Geometry.signedArea($1)) }
        var parents: [Int?] = []
        var depths: [Int] = []
        let paths = rings.map(path(for:))
        for i in rings.indices {
            let p = CGPoint(x: rings[i][0][0], y: rings[i][0][1])
            let parent = (0..<i).reversed().first { paths[$0].contains(p, using: .evenOdd) }
            parents.append(parent)
            depths.append(parent.map { depths[$0] + 1 } ?? 0)
        }
        func oriented(_ ring: LevelGeoJSON.Geometry.Ring, exterior: Bool) -> LevelGeoJSON.Geometry.Ring {
            let oriented = (LevelGeoJSON.Geometry.signedArea(ring) > 0) == exterior
                ? ring : Array(ring.reversed())
            let open = Array(oriented.dropLast())
            // CoreGraphics may choose a different starting vertex on reload.
            // Canonicalize it so repeated exports do not churn the file.
            let start = open.indices.min { a, b in
                open[a][0] == open[b][0] ? open[a][1] < open[b][1] : open[a][0] < open[b][0]
            }!
            let rotated = Array(open[start...]) + Array(open[..<start])
            return rotated + [rotated[0]]
        }
        var polygons: [LevelGeoJSON.Geometry.Polygon] = []
        for i in rings.indices where depths[i].isMultiple(of: 2) {
            var polygon = [oriented(rings[i], exterior: true)]
            for j in rings.indices where parents[j] == i {
                polygon.append(oriented(rings[j], exterior: false))
            }
            polygons.append(polygon)
        }
        let geometry: LevelGeoJSON.Geometry = polygons.count == 1
            ? .polygon(polygons[0]) : .multiPolygon(polygons)
        try geometry.validate()
        return geometry
    }

    static func path(for ring: LevelGeoJSON.Geometry.Ring) -> CGPath {
        let p = CGMutablePath()
        guard let first = ring.first else { return p }
        p.move(to: CGPoint(x: first[0], y: first[1]))
        for c in ring.dropFirst() { p.addLine(to: CGPoint(x: c[0], y: c[1])) }
        p.closeSubpath()
        return p
    }

    static func area(for geometry: LevelGeoJSON.Geometry) -> CGPath {
        let area = CGMutablePath()
        for polygon in geometry.polygons {
            for ring in polygon { area.addPath(path(for: ring)) }
        }
        return area.normalized(using: .evenOdd)
    }
}
