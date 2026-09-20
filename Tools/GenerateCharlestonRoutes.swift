// Offline authoring: follow the editor's road centerlines, repairing erased
// sections with the production area router. Only verified LineStrings are output.
import Foundation
import CoreGraphics
@testable import LevelEditorFormats

@main struct GenerateCharlestonRoutes {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4 else {
            throw LevelGeoJSONError(message: "Usage: GenerateCharlestonRoutes native.tdmap fresh.geojson routes.json")
        }
        let native = try NativeMapFile.read(Data(contentsOf: URL(fileURLWithPath: args[1])))
        var draft = native.draft
        // Rebuild every route from the current editable roads and placements.
        // A previous GeoJSON must never supply stale geometry or markers.
        draft.enemyRoutes = []
        draft.waves = []
        for i in draft.callWaveButtons.indices { draft.callWaveButtons[i].pathIndices = nil }
        let roads = draft.roads.map { LevelEditorFormats.Path(points: $0.points) }
        guard roads.count == 5, draft.entrances.count == 2, draft.exits.count == 2 else {
            throw LevelGeoJSONError(message: "Charleston authoring requires five roads, two entrances and two exits.")
        }
        let data = try GeoJSONExport(virtualCanvas: native.canvas).data(for: draft)
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let features = root["features"] as! [[String: Any]]
        let area = try HeroMovementArea(geoJSON: data, defaultPathWidth: native.canvas.pathWidth)
        func marker(_ id: String) -> Point {
            let feature = features.first { $0["id"] as? String == id }!
            let xy = (feature["geometry"] as! [String: Any])["coordinates"] as! [Double]
            return Point(xy[0], xy[1])
        }
        let left = marker("gameplay.entry.0"), top = marker("gameplay.entry.1")
        let right = marker("gameplay.exit.0"), bottom = marker("gameplay.exit.1")
        func section(_ road: LevelEditorFormats.Path, from a: Point, to b: Point) -> [Point] {
            let start = road.nearestDistance(to: a), end = road.nearestDistance(to: b)
            let length = abs(end - start), direction = end >= start ? 1.0 : -1.0
            var points = stride(from: 0.0, to: length, by: 8).map { road.point(atDistance: start + direction * $0) }
            points.append(road.point(atDistance: end))
            return points
        }
        let leftJoin = roads[1].points.first!, topJoin = roads[2].points.last!
        let centralTop = roads[3].points.last!, centralBottom = roads[3].points.first!
        let rightJoin = roads[4].points.last!
        let topApproach = section(roads[1], from: top, to: topJoin)
        let guides: [(String, Int, Int, [Point])] = [
            ("Entrance 0 to Exit 1 — lower road", 0, 1, section(roads[0], from: left, to: bottom)),
            ("Entrance 1 to Exit 0 — upper road", 1, 0, topApproach
                + section(roads[2], from: topJoin, to: right)),
            ("Entrance 0 to Exit 0 — upper road", 0, 0, section(roads[0], from: left, to: leftJoin)
                + section(roads[1], from: leftJoin, to: topJoin)
                + section(roads[2], from: topJoin, to: right)),
            ("Entrance 1 to Exit 1 — central road", 1, 1, topApproach
                + section(roads[2], from: topJoin, to: centralTop)
                + section(roads[3], from: centralTop, to: centralBottom)
                + section(roads[0], from: centralBottom, to: bottom)),
            ("Entrance 0 to Exit 0 — central road", 0, 0, section(roads[0], from: left, to: centralBottom)
                + section(roads[3], from: centralBottom, to: centralTop)
                + section(roads[2], from: centralTop, to: right)),
            ("Entrance 1 to Exit 1 — right road", 1, 1, topApproach
                + section(roads[2], from: topJoin, to: rightJoin)
                + section(roads[4], from: rightJoin, to: bottom))
        ]
        func simplify(_ points: [Point]) -> [Point] {
            guard points.count > 2 else { return points }
            let a = points[0], b = points.last!
            let middle = (1..<(points.count - 1)).max { points[$0].distance(toSegment: a, b) < points[$1].distance(toSegment: a, b) }!
            if points[middle].distance(toSegment: a, b) <= 4,
               area.containsSegment(from: a, to: b) { return [a, b] }
            return Array(simplify(Array(points[...middle])).dropLast()) + simplify(Array(points[middle...]))
        }
        var routes: [EnemyRoute] = []
        for (index, guide) in guides.enumerated() {
            let entranceID = "gameplay.entry.\(guide.1)", exitID = "gameplay.exit.\(guide.2)"
            let start = marker(entranceID), end = marker(exitID)
            guard area.contains(start), area.contains(end) else { throw NSError(domain: "RouteAuthoring", code: 1) }
            var points = [start]
            for authored in guide.3 + [end] {
                guard let target = area.nearestPoint(to: authored),
                      let segment = area.route(from: points.last!, to: target) else {
                    throw NSError(domain: "RouteAuthoring", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Disconnected centerline in route \(index)"])
                }
                points += segment.filter { $0 != points.last! }
            }
            // Joining separately drawn centerlines can briefly double back.
            // Replace short local detours only when the full chord is legal.
            var joined: [Point] = []
            var i = 0
            while i < points.count {
                joined.append(points[i])
                var distance = 0.0, skip = i + 1, j = i + 1
                var reverses = false
                while j < points.count {
                    if j >= i + 2 {
                        let a = points[j - 2], b = points[j - 1], c = points[j]
                        if (b.x - a.x) * (c.x - b.x) + (b.y - a.y) * (c.y - b.y) < 0 { reverses = true }
                    }
                    distance += points[j - 1].distance(to: points[j])
                    if distance > native.canvas.pathWidth * 2 { break }
                    if reverses, distance - points[i].distance(to: points[j]) > 12,
                       area.containsSegment(from: points[i], to: points[j]) { skip = j }
                    j += 1
                }
                i = skip
            }
            points = simplify(joined)
            // Round the joins between authored roads without crossing a border.
            for _ in 0..<2 {
                var rounded = [points[0]]
                for i in 1..<(points.count - 1) {
                    let a = Point.lerp(points[i], points[i - 1], 0.25)
                    let b = Point.lerp(points[i], points[i + 1], 0.25)
                    if area.containsSegment(from: a, to: b) { rounded += [a, b] }
                    else { rounded.append(points[i]) }
                }
                rounded.append(points.last!); points = rounded
            }
            precondition(points.first == start && points.last == end)
            precondition(zip(points, points.dropFirst()).allSatisfy { area.containsSegment(from: $0.0, to: $0.1) })
            routes.append(EnemyRoute(index: index, name: guide.0, entranceID: entranceID, exitID: exitID, points: points))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(routes).write(to: URL(fileURLWithPath: args[3]))
        try data.write(to: URL(fileURLWithPath: args[2]))
        for route in routes { print("Route \(route.index): \(route.points.count) points, \(Int(route.path.totalLength)) map units — \(route.name)") }
    }
}
