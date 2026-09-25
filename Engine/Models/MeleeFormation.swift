import Foundation

public struct MeleeFormation: Sendable {
    public let postSpread: Double
    public let spawnSpread: Double

    public init(rules: CombatRules) {
        let postSpread = rules.meleePostSpread
        let spawnSpread = rules.meleeSpawnSpread
        self.postSpread = postSpread
        self.spawnSpread = spawnSpread
    }

    public func spawnPoint(index: Int, of count: Int, building: Point) -> Point {
        ringPoint(index: index, of: count, around: building, radius: spawnSpread)
    }

    public func postPoint(index: Int, of count: Int, rallyPoint: Point) -> Point {
        ringPoint(index: index, of: count, around: rallyPoint, radius: postSpread)
    }

    /// Squads sent to the same flag occupy one formation. Otherwise every
    /// garrison puts its soldiers on top of the preceding squad's posts.
    public func sharedPosts(squads: [(slot: Int, rallyPoint: Point, count: Int)]) -> [Int: [Point]] {
        let ordered = squads.sorted { $0.slot < $1.slot }
        let totals = Dictionary(grouping: ordered, by: \.rallyPoint)
            .mapValues { $0.reduce(0) { $0 + $1.count } }
        var used: [Point: Int] = [:]
        var posts: [Int: [Point]] = [:]
        for squad in ordered {
            let first = used[squad.rallyPoint, default: 0]
            posts[squad.slot] = (0..<squad.count).map {
                postPoint(index: first + $0, of: totals[squad.rallyPoint]!, rallyPoint: squad.rallyPoint)
            }
            used[squad.rallyPoint] = first + squad.count
        }
        return posts
    }

    private func ringPoint(index: Int, of count: Int,
                           around center: Point, radius: Double) -> Point {
        guard count > 1, radius > 0 else { return center }
        let angle = 2.0 * Double.pi * Double(index) / Double(count)
        return Point(center.x + radius * cos(angle),
                     center.y + radius * sin(angle))
    }
}
