import Foundation

public struct MeleeFormation: Sendable {
    public let postSpread: Double
    public let spawnSpread: Double

    public init(postSpread: Double = 45.36, spawnSpread: Double = 0) {
        self.postSpread = postSpread
        self.spawnSpread = spawnSpread
    }

    public func spawnPoint(index: Int, of count: Int, building: Point) -> Point {
        ringPoint(index: index, of: count, around: building, radius: spawnSpread)
    }

    public func postPoint(index: Int, of count: Int, rallyPoint: Point) -> Point {
        ringPoint(index: index, of: count, around: rallyPoint, radius: postSpread)
    }

    private func ringPoint(index: Int, of count: Int,
                           around center: Point, radius: Double) -> Point {
        guard count > 1, radius > 0 else { return center }
        let angle = 2.0 * Double.pi * Double(index) / Double(count)
        return Point(center.x + radius * cos(angle),
                     center.y + radius * sin(angle))
    }
}
