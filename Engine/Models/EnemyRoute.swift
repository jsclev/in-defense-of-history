import Foundation

/// A directed march through the authored path area, distinct from its footprint.
/// Wave pathIndex values reference these contiguous route indices.
public struct EnemyRoute: Codable, Equatable, Sendable {
    public var index: Int
    public var name: String
    public var entranceID: String
    public var exitID: String
    public var points: [Point]

    public init(index: Int, name: String, entranceID: String, exitID: String, points: [Point]) {
        self.index = index; self.name = name; self.entranceID = entranceID
        self.exitID = exitID; self.points = points
    }

    public var path: Path { Path(points: points) }
}
