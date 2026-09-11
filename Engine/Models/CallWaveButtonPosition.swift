public struct CallWaveButtonPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Nil is a level-wide control. Otherwise show only when the next wave
    /// uses one of these gameplay route indices.
    public var pathIndices: [Int]?

    public init(position: Point, pathIndices: [Int]? = nil) {
        x = position.x
        y = position.y
        self.pathIndices = pathIndices
    }

    public var position: Point {
        get { Point(x, y) }
        set { x = newValue.x; y = newValue.y }
    }

    public static func visiblePositions(_ buttons: [Self], forPathIndices active: Set<Int>) -> [Point] {
        var seen = Set<Point>()
        return buttons.compactMap { button in
            guard button.pathIndices.map({ !active.isDisjoint(with: $0) }) ?? true,
                  seen.insert(button.position).inserted else { return nil }
            return button.position
        }
    }
}
