// Offline authoring: follow the editor's road centerlines, repairing erased
// sections with the production area router. Only verified LineStrings are output.
import Foundation
import CoreGraphics
import LevelEditorFormats

@main struct GenerateCharlestonRoutes {
    static func main() throws {
        let args = CommandLine.arguments
        let native = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1]))) as! [String: Any]
        let draft = native["draft"] as! [String: Any]
        let roadValues = draft["roads"] as! [[String: Any]]
        let roads = roadValues.map { road in
            LevelEditorFormats.Path(points: (road["points"] as! [[String: Double]]).map { Point($0["x"]!, $0["y"]!) })
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let features = root["features"] as! [[String: Any]]
        let area = try HeroMovementArea(geoJSON: data, defaultPathWidth: 140)
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
        let upperJoin = roads[3].points.last!
        let centralTop = roads[4].points.last!, centralBottom = roads[4].points.first!
        let guides: [(String, Int, Int, [Point])] = [
            ("Western column via lower road", 0, 1, section(roads[0], from: left, to: bottom)),
            ("Northern column via upper road", 1, 0, section(roads[2], from: top, to: right)),
            ("Western flank via upper road", 0, 0, section(roads[3], from: left, to: upperJoin)
                + section(roads[2], from: upperJoin, to: right)),
            ("Northern flank via central road", 1, 1, section(roads[2], from: top, to: centralTop)
                + section(roads[4], from: centralTop, to: centralBottom)
                + section(roads[0], from: centralBottom, to: bottom))
        ]
        func simplify(_ points: [Point]) -> [Point] {
            guard points.count > 2 else { return points }
            let a = points[0], b = points.last!
            let middle = (1..<(points.count - 1)).max { points[$0].distance(toSegment: a, b) < points[$1].distance(toSegment: a, b) }!
            if points[middle].distance(toSegment: a, b) <= 1,
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
                    if distance > 140 { break }
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
        for route in routes { print("Route \(route.index): \(route.points.count) points, \(Int(route.path.totalLength)) map units — \(route.name)") }
    }
}
