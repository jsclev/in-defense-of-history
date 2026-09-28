public struct Path: Sendable, Equatable {
    public let points: [Point]
    public let cumulative: [Double]
    public let totalLength: Double
    private struct Segment: Sendable, Equatable {
        let dx: Double
        let dy: Double
        let lengthSquared: Double
        let lengthAlong: Double
    }
    // These exact subtractions/products were previously repeated for every
    // projection. Keep division, square roots and comparisons in their original
    // order: reciprocal multiplication or squared-gap ties can change results.
    private let segments: [Segment]

    public init(points: [Point]) {
        precondition(points.count >= 2, "A path needs at least two points")
        self.points = points
        var cum: [Double] = [0]
        cum.reserveCapacity(points.count)
        var total = 0.0
        for i in 1..<points.count {
            total += points[i - 1].distance(to: points[i])
            cum.append(total)
        }
        self.cumulative = cum
        self.totalLength = total
        self.segments = (1..<points.count).map { i in
            let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
            return Segment(dx: dx, dy: dy, lengthSquared: dx * dx + dy * dy,
                           lengthAlong: cum[i] - cum[i - 1])
        }
    }

    public func point(atDistance d: Double) -> Point {
        if d <= 0 { return points[0] }
        if d >= totalLength { return points[points.count - 1] }
        var lo = 0
        var hi = cumulative.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if cumulative[mid] <= d { lo = mid } else { hi = mid }
        }
        let segStart = cumulative[lo]
        let segment = segments[lo]
        let segLen = segment.lengthAlong
        let t = segLen > 0 ? (d - segStart) / segLen : 0
        return Point(points[lo].x + segment.dx * t, points[lo].y + segment.dy * t)
    }

    public func nearestDistance(to target: Point) -> Double {
        var bestDistanceAlong = 0.0
        var bestGap = Double.infinity
        for i in 1..<points.count {
            let a = points[i - 1]
            let segment = segments[i - 1]
            let dx = segment.dx
            let dy = segment.dy
            let segmentLengthSquared = segment.lengthSquared
            var t = 0.0
            if segmentLengthSquared > 0 {
                t = ((target.x - a.x) * dx + (target.y - a.y) * dy) / segmentLengthSquared
                t = min(max(t, 0), 1)
            }
            let gap = Point(a.x + dx * t, a.y + dy * t).distance(to: target)
            if gap < bestGap {
                bestGap = gap
                bestDistanceAlong = cumulative[i - 1] + segment.lengthAlong * t
            }
        }
        return bestDistanceAlong
    }
}

extension Path: Codable {
    private enum K: String, CodingKey { case points }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        self.init(points: try c.decode([Point].self, forKey: .points))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(points, forKey: .points)
    }
}
