import CoreGraphics
import Foundation

/// Shared machinery for the map's wandering animals and ships.
///
/// A route is a closed Catmull-Rom loop through random waypoints, so a
/// traveller curves rather than turning on a sixpence and the circuit
/// repeats seamlessly. Candidate loops are rejected unless the *whole
/// sampled curve* lies in allowed terrain — a spline bulges outside its
/// control points, so checking only the waypoints lets a traveller cut a
/// corner across a coastline. Courses are seeded deterministically, so a
/// given seed always yields the same route.
enum CampaignRoute {
    /// SplitMix64 — deterministic and independent of the platform RNG.
    struct Seeded {
        var state: UInt64

        init(seed: Int) {
            state = UInt64(bitPattern: Int64(seed)) &* 0x2545F4914F6CDD1D &+ 0x9E3779B9
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
        mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + unit() * (hi - lo) }
    }

    struct Course {
        var points: [CGPoint]
        var lengths: [CGFloat]
        /// Cumulative *travel time* rather than distance. A traveller eases
        /// off through a bend and picks up again on the straights, which is
        /// what stops a constant-speed loop looking mechanical.
        var times: [CGFloat]
    }

    /// A coarse terrain mask over the map image: rows of "#" (allowed) and
    /// "." (not), sampled at the cell containing a point.
    struct Mask {
        var rows: [String]
        var width: Int
        var height: Int

        func allows(_ p: CGPoint, imageSize: CGSize) -> Bool {
            let gx = Int(p.x / imageSize.width * CGFloat(width))
            let gy = Int(p.y / imageSize.height * CGFloat(height))
            guard gy >= 0, gy < rows.count, gx >= 0, gx < width else { return false }
            let row = Array(rows[gy])
            return gx < row.count && row[gx] == "#"
        }
    }

    private static func spline(_ waypoints: [CGPoint], samplesPerLeg: Int = 40) -> [CGPoint] {
        var out: [CGPoint] = []
        let n = waypoints.count
        guard n >= 3 else { return waypoints }
        for i in 0..<n {
            let p0 = waypoints[(i - 1 + n) % n], p1 = waypoints[i]
            let p2 = waypoints[(i + 1) % n], p3 = waypoints[(i + 2) % n]
            for s in 0..<samplesPerLeg {
                let t = CGFloat(s) / CGFloat(samplesPerLeg)
                let t2 = t * t, t3 = t2 * t
                out.append(CGPoint(
                    x: 0.5 * ((2*p1.x) + (-p0.x + p2.x)*t
                        + (2*p0.x - 5*p1.x + 4*p2.x - p3.x)*t2
                        + (-p0.x + 3*p1.x - 3*p2.x + p3.x)*t3),
                    y: 0.5 * ((2*p1.y) + (-p0.y + p2.y)*t
                        + (2*p0.y - 5*p1.y + 4*p2.y - p3.y)*t2
                        + (-p0.y + 3*p1.y - 3*p2.y + p3.y)*t3)))
            }
        }
        return out
    }

    /// Builds a closed course whose every sampled point satisfies `allows`.
    /// `centreX`/`centreY` bound where the loop may be centred; `radius`
    /// bounds its size, shrinking on each retry.
    static func closedCourse(
        seed: Int,
        centreX: ClosedRange<CGFloat>,
        centreY: ClosedRange<CGFloat>,
        radius: ClosedRange<CGFloat>,
        aspect: CGFloat = 1.25,
        attempts: Int = 80,
        minimumLength: CGFloat = 0,
        allows: (CGPoint) -> Bool
    ) -> Course {
        var rng = Seeded(seed: seed)
        var points: [CGPoint] = []
        // Best valid loop seen so far, in case none reaches minimumLength —
        // a short legal course still beats an unvalidated fallback.
        var bestValid: [CGPoint] = []
        var bestValidLength: CGFloat = 0

        func perimeter(_ p: [CGPoint]) -> CGFloat {
            var len: CGFloat = 0
            for i in 1...p.count { len += hypot(p[i % p.count].x - p[i-1].x,
                                                p[i % p.count].y - p[i-1].y) }
            return len
        }

        for attempt in 0..<attempts {
            let count = 5 + Int(rng.next() % 3)                    // 5...7 waypoints
            let cx = rng.range(centreX.lowerBound, centreX.upperBound)
            let cy = rng.range(centreY.lowerBound, centreY.upperBound)
            let shrink = 1 - CGFloat(attempt) / CGFloat(attempts + 20)
            let baseR = rng.range(radius.lowerBound, radius.upperBound) * shrink
            let spin = rng.range(0, .pi * 2)
            var candidate: [CGPoint] = []
            for i in 0..<count {
                let a = spin + CGFloat(i) / CGFloat(count) * .pi * 2
                let r = baseR * rng.range(0.7, 1.3)                // irregular, not a circle
                candidate.append(CGPoint(x: cx + cos(a) * r * aspect, y: cy + sin(a) * r))
            }
            let sampled = spline(candidate)
            guard sampled.allSatisfy(allows) else { continue }
            // A valid but tiny loop reads as spinning on the spot, so hold
            // out for a circuit worth travelling — but remember the best
            // legal one in case nothing longer turns up.
            let length = perimeter(sampled)
            if length > bestValidLength { bestValidLength = length; bestValid = sampled }
            if length >= minimumLength { points = sampled; break }
        }

        if points.isEmpty { points = bestValid }
        if points.isEmpty {
            let cx = (centreX.lowerBound + centreX.upperBound) / 2
            let cy = (centreY.lowerBound + centreY.upperBound) / 2
            let r = radius.lowerBound * 0.5
            points = spline((0..<6).map { i in
                let a = CGFloat(i) / 6 * .pi * 2
                return CGPoint(x: cx + cos(a) * r * aspect, y: cy + sin(a) * r)
            })
        }

        var lengths: [CGFloat] = [0]
        for i in 1...points.count {
            let a = points[i - 1], b = points[i % points.count]
            lengths.append(lengths[i - 1] + hypot(b.x - a.x, b.y - a.y))
        }

        // Travel time per segment: the sharper the turn, the slower the leg.
        func heading(_ i: Int) -> CGFloat {
            let a = points[i % points.count], b = points[(i + 1) % points.count]
            return atan2(b.y - a.y, b.x - a.x)
        }
        var times: [CGFloat] = [0]
        for i in 1...points.count {
            let step = lengths[i] - lengths[i - 1]
            var turn = abs(heading(i % points.count) - heading(i - 1))
            if turn > .pi { turn = 2 * .pi - turn }
            // 0 rad -> full speed, ~0.25 rad of turn per sample -> about half
            let speed = max(0.45, 1 - turn * 2.2)
            times.append(times[i - 1] + step / speed)
        }
        return Course(points: points, lengths: lengths, times: times)
    }

    /// Position and direction of travel at a fraction around the course.
    /// The heading is returned as a unit vector; callers convert it to their
    /// own sheet's angle convention.
    static func sample(_ progress: Double, on course: Course)
        -> (point: CGPoint, dx: CGFloat, dy: CGFloat) {
        let points = course.points, times = course.times
        guard points.count > 2, let total = times.last, total > 0 else {
            return (.zero, 1, 0)
        }
        let target = CGFloat(progress - progress.rounded(.down)) * total
        var lo = 0, hi = times.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if times[mid] <= target { lo = mid } else { hi = mid }
        }
        let segment = max(times[lo + 1] - times[lo], 0.0001)
        let t = (target - times[lo]) / segment
        let a = points[lo % points.count], b = points[(lo + 1) % points.count]
        let here = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)

        // Look a little further along so the heading reads the curve, not one segment.
        let ahead = points[(lo + 6) % points.count]
        let dx = ahead.x - here.x, dy = ahead.y - here.y
        let d = max(hypot(dx, dy), 0.0001)
        return (here, dx / d, dy / d)
    }
}
