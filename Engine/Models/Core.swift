public struct Point: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(0, 0)

    public func distance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public func squaredDistance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }

    public static func lerp(_ a: Point, _ b: Point, _ t: Double) -> Point {
        Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
}

struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@inline(__always)
private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
    (x << k) | (x >> (64 - k))
}

public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    public init(seed: UInt64) {
        var sm = SplitMix64(state: seed)
        s0 = sm.next()
        s1 = sm.next()
        s2 = sm.next()
        s3 = sm.next()
        if (s0 | s1 | s2 | s3) == 0 {
            s3 = 0x9E37_79B9_7F4A_7C15
        }
    }

    public mutating func next() -> UInt64 {
        let result = rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 45)
        return result
    }

    public func fork(stream: UInt64) -> SeededRNG {
        var sm = SplitMix64(state: s0 ^ (0xD1B5_4A32_D192_ED03 &* (stream &+ 1)))
        return SeededRNG(seed: sm.next())
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    public mutating func chance(_ p: Double) -> Bool {
        if p <= 0 { return false }
        if p >= 1 { return true }
        return double(in: 0...1) < p
    }
}

public enum SimClock {
    public static let ticksPerSecond: Int = 30
    public static let dt: Double = 1.0 / Double(ticksPerSecond)
}

public enum Tunables {
    public static let killBountyMultiplier: Double = 1.0
    public static let routBountyMultiplier: Double = 0.6
    public static let captureBountyMultiplier: Double = 1.3

    public static let moraleMax: Double = 100
    public static let baseMoraleRegenPerSecond: Double = 0.5
    public static let breakMoraleSplash: Double = 15
    public static let breakSplashRadius: Double = 70
    public static let waveringSplashMultiplier: Double = 2
    public static let commandDeathShockDefault: Double = 25

    public static let shakenSpeedMultiplier: Double = 0.9
    public static let routSpeedMultiplier: Double = 1.15

    public static let steadyAdvanceHPGate: Double = 0.25

    public static let contagionTickInterval: Double = 0.5
    public static let diseaseHPPerSecond: Double = 2.5
    public static let diseaseHPFloorFraction: Double = 0.15
    public static let diseaseMoralePerSecond: Double = 4.0
    public static let contagionSpreadRadius: Double = 60
    public static let contagionSpreadChance: Double = 0.35
}
