
import Foundation
import LevelEditorFormats
// The runner's internal error type is not exported by the Engine module.
enum DbError: Error { case Db(message: String) }
final class Roads {
    let virtualCanvas: VirtualCanvas
    let playArea: CGRect
    let paths: [LevelEditorFormats.Path]
    private static let heroRoadSpacing = 20.0
    private var heroRoads = HeroRoads(points: [], neighbors: [])
    init(canvas: VirtualCanvas, play: CGRect, paths: [LevelEditorFormats.Path]) {
        virtualCanvas = canvas; playArea = play; self.paths = paths
        heroRoads = buildHeroRoads()
    }
    func check() throws -> [[String: Any]] {
        var rows: [[String: Any]] = []
        for (index, path) in paths.enumerated() {
            let exit = path.points.last!
            let spawn = try addHeroSpawnNode(at: exit)
            for fraction in [0.1, 0.25, 0.5, 0.75, 0.9] {
                let target = heroNearestNode(to: path.point(atDistance: path.totalLength * fraction))
                let route = heroRoute(from: spawn, to: target)
                // A destination on this very road must be reachable from its exit,
                // even when a connecting bend is outside the sprite-safe rectangle.
                let reachable = spawn == target || (!route.isEmpty && route.last == target)
                let validEdges = zip([spawn] + route, route).allSatisfy {
                    heroRoads.neighbors[$0].contains($1)
                }
                rows.append(["path": index, "fraction": fraction,
                             "reachable": reachable, "validEdges": validEdges,
                             "routeNodes": route.count])
            }
        }
        return rows
    }
    private struct HeroRoads {
        let points: [Point]
        let neighbors: [[Int]]
    }
private func buildHeroRoads() -> HeroRoads {
        let rect = heroStandRect
        var points: [Point] = []
        var neighbors: [[Int]] = []
        for path in paths {
            var previous: Int? = nil
            var travelled = 0.0
            while travelled <= path.totalLength {
                let p = path.point(atDistance: travelled)
                if rect.contains(CGPoint(x: p.x, y: p.y)) {
                    points.append(p)
                    neighbors.append([])
                    let index = points.count - 1
                    if let previous {
                        neighbors[previous].append(index)
                        neighbors[index].append(previous)
                    }
                    previous = index
                } else {
                    previous = nil
                }
                travelled += Self.heroRoadSpacing
            }
        }
        let junction = virtualCanvas.pathWidth / 2
        for i in 0..<points.count {
            for j in (i + 1)..<points.count where !neighbors[i].contains(j) {
                if points[i].distance(to: points[j]) <= junction {
                    neighbors[i].append(j)
                    neighbors[j].append(i)
                }
            }
        }
        return HeroRoads(points: points, neighbors: neighbors)
    }
private func addHeroSpawnNode(at position: Point) throws -> Int {
        let nearest = heroNearestNode(to: position)
        guard nearest >= 0 else {
            throw DbError.Db(message: "Hero exit has no navigable road to connect to")
        }
        if heroRoads.points[nearest] == position { return nearest }
        var points = heroRoads.points
        var neighbors = heroRoads.neighbors
        let index = points.count
        points.append(position)
        neighbors.append([nearest])
        neighbors[nearest].append(index)
        heroRoads = HeroRoads(points: points, neighbors: neighbors)
        return index
    }
private func heroNearestNode(to p: Point) -> Int {
        var best = -1
        var bestGap = Double.infinity
        for (i, q) in heroRoads.points.enumerated() {
            let gap = q.distance(to: p)
            if gap < bestGap {
                bestGap = gap
                best = i
            }
        }
        return best
    }
private func heroRoute(from: Int, to: Int) -> [Int] {
        guard from != to, heroRoads.points.indices.contains(from),
              heroRoads.points.indices.contains(to) else { return [] }
        let count = heroRoads.points.count
        var distances = [Double](repeating: .infinity, count: count)
        var previous = [Int](repeating: -1, count: count)
        var settled = [Bool](repeating: false, count: count)
        distances[from] = 0
        while true {
            var best = -1
            var bestDistance = Double.infinity
            for i in 0..<count where !settled[i] && distances[i] < bestDistance {
                bestDistance = distances[i]
                best = i
            }
            if best < 0 || best == to { break }
            settled[best] = true
            for n in heroRoads.neighbors[best] {
                let d = distances[best]
                    + heroRoads.points[best].distance(to: heroRoads.points[n])
                if d < distances[n] {
                    distances[n] = d
                    previous[n] = best
                }
            }
        }
        guard distances[to].isFinite else { return [] }
        var route: [Int] = []
        var current = to
        while current != from && current >= 0 {
            route.append(current)
            current = previous[current]
        }
        return current == from ? route.reversed() : []
    }
private var heroStandRect: CGRect {
        let height = MapSpriteSizing.heroMapHeight
        return CGRect(x: playArea.minX + height / 2,
                      y: playArea.minY,
                      width: max(0, playArea.width - height),
                      height: max(0, playArea.height - height))
    }
}
@main struct Probe {
    static func main() throws {
        let db = Db(dbPath: CommandLine.arguments[1], fullRefresh: false)
        let canvas = try db.virtualCanvasDao.get()
        var rows: [[String: Any]] = []
        for row in try db.levelInfoDao.getCampaignLevels(campaignName: "Main") {
            let level = try db.levelInfoDao.getBy(id: row.id)
            let graph = Roads(canvas: canvas, play: level.playArea, paths: level.paths)
            for var check in try graph.check() {
                check["level"] = level.name
                rows.append(check)
            }
        }
        let passed = !rows.isEmpty && rows.allSatisfy {
            ($0["reachable"] as! Bool) && ($0["validEdges"] as! Bool)
        }
        let data = try JSONSerialization.data(withJSONObject: ["passed": passed, "checks": rows],
                                              options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
