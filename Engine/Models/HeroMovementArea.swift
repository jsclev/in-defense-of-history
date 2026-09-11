import Foundation
import CoreGraphics

/// The walkable ground authored in a level's GeoJSON, in canonical map units.
/// This model has no screen, sprite, HUD, database-waypoint or view dependency.
public final class HeroMovementArea {
    public enum InvalidArea: Error { case missingPath, malformedGeometry }

    public let bounds: CGRect
    private let shape: CGPath
    private let edges: [(Point, Point)]
    private let vertices: [Point]
    private let edgeRows: [Int: [Int]]
    private let components: [CGPath]
    private let rowHeight = 32.0
    private let spacing = 16.0
    private var neighborCache: [Cell: [Cell]] = [:]

    /// Polygon holes are preserved. Legacy centerlines are expanded by their
    /// authored widthPx (or the virtual canvas width when it is absent).
    public convenience init(geoJSON data: Data, defaultPathWidth: Double) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else {
            throw InvalidArea.malformedGeometry
        }
        var area: CGPath?
        func points(_ raw: Any?) throws -> [Point] {
            guard let coordinates = raw as? [[Double]], coordinates.count >= 2,
                  coordinates.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }) else {
                throw InvalidArea.malformedGeometry
            }
            return coordinates.map { Point($0[0], $0[1]) }
        }
        func polygon(_ raw: Any?) throws -> CGPath {
            guard let rings = raw as? [Any], !rings.isEmpty else { throw InvalidArea.malformedGeometry }
            let path = CGMutablePath()
            for rawRing in rings {
                let ring = try points(rawRing)
                guard ring.count >= 4, ring.first == ring.last,
                      abs(zip(ring, ring.dropFirst()).reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y }) > 0 else {
                    throw InvalidArea.malformedGeometry
                }
                path.move(to: CGPoint(x: ring[0].x, y: ring[0].y))
                for p in ring.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
                path.closeSubpath()
            }
            return path.normalized(using: .evenOdd)
        }
        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  properties["category"] as? String == "gameplay",
                  ["enemy_path", "path", "road"].contains(properties["kind"] as? String ?? "") else { continue }
            guard let geometry = feature["geometry"] as? [String: Any] else { throw InvalidArea.malformedGeometry }
            let path: CGPath
            switch geometry["type"] as? String {
            case "Polygon": path = try polygon(geometry["coordinates"])
            case "MultiPolygon":
                guard let polygons = geometry["coordinates"] as? [Any], !polygons.isEmpty else {
                    throw InvalidArea.malformedGeometry
                }
                var combined = try polygon(polygons[0])
                for raw in polygons.dropFirst() { combined = combined.union(try polygon(raw)) }
                path = combined
            case "LineString":
                let line = try points(geometry["coordinates"])
                let width: Double
                if let raw = properties["widthPx"] {
                    guard let number = raw as? Double else { throw InvalidArea.malformedGeometry }
                    width = number
                } else { width = defaultPathWidth }
                guard width.isFinite, width > 0,
                      line.dropFirst().contains(where: { $0 != line[0] }) else { throw InvalidArea.malformedGeometry }
                let centerline = CGMutablePath()
                centerline.move(to: CGPoint(x: line[0].x, y: line[0].y))
                for p in line.dropFirst() { centerline.addLine(to: CGPoint(x: p.x, y: p.y)) }
                path = centerline.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1)
                    .normalized(using: .winding)
            default: throw InvalidArea.malformedGeometry
            }
            area = area.map { $0.union(path) } ?? path
        }
        guard let area, !area.isEmpty else { throw InvalidArea.missingPath }
        self.init(shape: area)
    }

    private init(shape: CGPath) {
        // Straight boundaries let us check the entire segment, including tiny
        // holes that would be missed by sampling every few map units.
        self.shape = shape.flattened(threshold: 0.1)
        bounds = self.shape.boundingBoxOfPath
        var edges: [(Point, Point)] = []
        var rings: [CGPath] = []
        var ring = CGMutablePath()
        var first = Point.zero
        var previous = Point.zero
        self.shape.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                first = Point(e.points[0].x, e.points[0].y); previous = first
                ring = CGMutablePath(); ring.move(to: e.points[0])
            case .addLineToPoint:
                let next = Point(e.points[0].x, e.points[0].y)
                if previous != next { edges.append((previous, next)) }
                previous = next
                ring.addLine(to: e.points[0])
            case .closeSubpath:
                if previous != first { edges.append((previous, first)) }
                ring.closeSubpath(); rings.append(ring)
            default: break
            }
        }
        // The normalized rings are nested exteriors/holes. Each even-depth
        // exterior is a connected component, including islands inside holes.
        components = rings.enumerated().filter { index, candidate in
            var firstPoint = CGPoint.zero
            var found = false
            candidate.applyWithBlock { e in
                if !found, e.pointee.type == .moveToPoint { firstPoint = e.pointee.points[0]; found = true }
            }
            let depth = rings.enumerated().filter { $0.offset != index && $0.element.contains(firstPoint) }.count
            return depth.isMultiple(of: 2)
        }.map(\.element).sorted { $0.boundingBoxOfPath.width * $0.boundingBoxOfPath.height < $1.boundingBoxOfPath.width * $1.boundingBoxOfPath.height }
        self.edges = edges
        vertices = Array(Set(edges.map(\.0))).sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        var rows: [Int: [Int]] = [:]
        for (index, edge) in edges.enumerated() {
            for row in Int(floor(min(edge.0.y, edge.1.y) / rowHeight))...Int(floor(max(edge.0.y, edge.1.y) / rowHeight)) {
                rows[row, default: []].append(index)
            }
        }
        edgeRows = rows
    }

    /// Boundaries are allowed; no tolerance beyond floating-point roundoff is
    /// added to the authored region. Holes and disconnected components remain excluded.
    public func contains(_ point: Point) -> Bool {
        guard point.x.isFinite, point.y.isFinite,
              point.x >= bounds.minX - 1e-7, point.x <= bounds.maxX + 1e-7,
              point.y >= bounds.minY - 1e-7, point.y <= bounds.maxY + 1e-7 else { return false }
        var inside = false
        for index in edgeRows[Int(floor(point.y / rowHeight))] ?? [] {
            let (a, b) = edges[index]
            if point.distance(toSegment: a, b) <= 1e-7 { return true }
            if (a.y > point.y) != (b.y > point.y),
               point.x < a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y) { inside.toggle() }
        }
        return inside
    }

    public func containsSegment(from start: Point, to end: Point) -> Bool {
        guard contains(start), contains(end) else { return false }
        if start == end { return true }
        let dx = end.x - start.x, dy = end.y - start.y
        var cuts = [0.0, 1.0]
        var checked = Set<Int>()
        for row in Int(floor(min(start.y, end.y) / rowHeight))...Int(floor(max(start.y, end.y) / rowHeight)) {
            for index in edgeRows[row] ?? [] where checked.insert(index).inserted {
                let (a, b) = edges[index]
                guard max(a.x, b.x) >= min(start.x, end.x), min(a.x, b.x) <= max(start.x, end.x) else { continue }
                let ex = b.x - a.x, ey = b.y - a.y
                let denominator = dx * ey - dy * ex
                if abs(denominator) > 1e-12 {
                    let t = ((a.x - start.x) * ey - (a.y - start.y) * ex) / denominator
                    let u = ((a.x - start.x) * dy - (a.y - start.y) * dx) / denominator
                    if t > 0, t < 1, u >= 0, u <= 1 { cuts.append(t) }
                } else {
                    // Collinear boundary vertices also split the segment.
                    for p in [a, b] where p.distance(toSegment: start, end) <= 1e-7 {
                        cuts.append(((p.x - start.x) * dx + (p.y - start.y) * dy) / (dx * dx + dy * dy))
                    }
                }
            }
        }
        cuts.sort()
        return zip(cuts, cuts.dropFirst()).allSatisfy { a, b in
            b - a <= 1e-12 || contains(Point.lerp(start, end, (a + b) / 2))
        }
    }

    public func nearestPoint(to point: Point) -> Point? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        if contains(point) { return point }
        return edges.map { point.closestPoint(onSegment: $0.0, $0.1) }
            .min { $0.squaredDistance(to: point) < $1.squaredDistance(to: point) }
    }

    /// Returns exact destination coordinates, excluding the starting point.
    /// A nil route rejects the command without changing the hero's current order.
    public func route(from start: Point, to end: Point) -> [Point]? {
        guard contains(start), contains(end) else { return nil }
        guard component(containing: start) == component(containing: end) else { return nil }
        if start == end { return [] }
        if containsSegment(from: start, to: end) { return [end] }
        if let route = gridRoute(from: start, to: end) { return simplify(route, from: start) }
        // Very narrow authored passages may contain no grid cell. Boundary
        // visibility is the exact fallback; grid spacing never decides reachability.
        return boundaryRoute(from: start, to: end)
    }

    private func component(containing point: Point) -> Int? {
        components.firstIndex { path in
            path.contains(CGPoint(x: point.x, y: point.y)) ||
                path.copy(strokingWithWidth: 0.000001, lineCap: .butt, lineJoin: .miter, miterLimit: 1)
                    .contains(CGPoint(x: point.x, y: point.y))
        }
    }

    private struct Cell: Hashable { let x: Int; let y: Int }
    private func point(_ cell: Cell) -> Point { Point(Double(cell.x) * spacing, Double(cell.y) * spacing) }
    private func connections(at p: Point) -> [Cell] {
        let x = Int((p.x / spacing).rounded()), y = Int((p.y / spacing).rounded())
        var result: [Cell] = []
        for dx in -2...2 { for dy in -2...2 {
            let cell = Cell(x: x + dx, y: y + dy)
            if containsSegment(from: p, to: point(cell)) { result.append(cell) }
        } }
        return result
    }
    private func neighbors(of cell: Cell) -> [Cell] {
        if let cached = neighborCache[cell] { return cached }
        var result: [Cell] = []
        for dx in -1...1 { for dy in -1...1 where dx != 0 || dy != 0 {
            let next = Cell(x: cell.x + dx, y: cell.y + dy)
            if containsSegment(from: point(cell), to: point(next)) { result.append(next) }
        } }
        neighborCache[cell] = result
        return result
    }
    private func gridRoute(from start: Point, to end: Point) -> [Point]? {
        let goals = Set(connections(at: end))
        guard !goals.isEmpty else { return nil }
        var open = MinHeap<Cell>()
        var distances: [Cell: Double] = [:]
        var previous: [Cell: Cell] = [:]
        var settled = Set<Cell>()
        for cell in connections(at: start) {
            let d = start.distance(to: point(cell))
            distances[cell] = d
            open.push(cell, priority: d + point(cell).distance(to: end))
        }
        while let cell = open.pop() {
            guard settled.insert(cell).inserted else { continue }
            if goals.contains(cell) {
                var route = [end, point(cell)]
                var current = cell
                while let parent = previous[current] { route.append(point(parent)); current = parent }
                return route.reversed()
            }
            for next in neighbors(of: cell) where !settled.contains(next) {
                let d = distances[cell]! + point(cell).distance(to: point(next))
                if d < distances[next, default: .infinity] {
                    distances[next] = d; previous[next] = cell
                    open.push(next, priority: d + point(next).distance(to: end))
                }
            }
        }
        return nil
    }
    private func boundaryRoute(from start: Point, to end: Point) -> [Point]? {
        let nodes = [start, end] + vertices
        var open = MinHeap<Int>()
        var distances = [Double](repeating: .infinity, count: nodes.count)
        var previous = [Int](repeating: -1, count: nodes.count)
        var settled = Set<Int>()
        distances[0] = 0; open.push(0, priority: start.distance(to: end))
        while let current = open.pop() {
            guard settled.insert(current).inserted else { continue }
            if current == 1 {
                var route: [Point] = []; var i = 1
                while i != 0 { route.append(nodes[i]); i = previous[i] }
                return route.reversed()
            }
            for next in 1..<nodes.count where !settled.contains(next) {
                let d = distances[current] + nodes[current].distance(to: nodes[next])
                if d < distances[next], containsSegment(from: nodes[current], to: nodes[next]) {
                    distances[next] = d; previous[next] = current
                    open.push(next, priority: d + nodes[next].distance(to: end))
                }
            }
        }
        return nil
    }
    private func simplify(_ route: [Point], from start: Point) -> [Point] {
        var result: [Point] = []; var current = start; var index = 0
        while index < route.count {
            var next = route.count - 1
            while next > index && !containsSegment(from: current, to: route[next]) { next -= 1 }
            result.append(route[next]); current = route[next]; index = next + 1
        }
        return result
    }
}

private struct MinHeap<Value> {
    private var entries: [(value: Value, priority: Double)] = []
    mutating func push(_ value: Value, priority: Double) {
        entries.append((value, priority))
        var i = entries.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard entries[i].priority < entries[parent].priority else { break }
            entries.swapAt(i, parent); i = parent
        }
    }
    mutating func pop() -> Value? {
        guard !entries.isEmpty else { return nil }
        entries.swapAt(0, entries.count - 1)
        let result = entries.removeLast().value
        var i = 0
        while 2 * i + 1 < entries.count {
            var child = 2 * i + 1
            if child + 1 < entries.count, entries[child + 1].priority < entries[child].priority { child += 1 }
            guard entries[child].priority < entries[i].priority else { break }
            entries.swapAt(child, i); i = child
        }
        return result
    }
}
