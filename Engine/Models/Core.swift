// Core.swift
// Foundation-free core: geometry, deterministic RNG, clock, and tunables.
// Everything in the hot loop is a value type; nothing here touches I/O.

// MARK: - Geometry

/// A point in the level's virtual coordinate space. This is the same space
/// your artwork will be authored in, so tower slots and path polylines line
/// up 1:1 with the art once a renderer exists.
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

// MARK: - Deterministic RNG

/// SplitMix64: used to expand a single seed into stream seeds.
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

/// Xoshiro256** — fast, high quality, and (unlike SystemRandomNumberGenerator)
/// seedable, so every simulation is exactly reproducible from its seed.
///
/// Use `fork(stream:)` to derive independent sub-streams (combat rolls, morale
/// variance, contagion...). Keeping systems on separate streams means adding a
/// new random draw to one system does not reshuffle the outcomes of another —
/// which keeps old regression seeds meaningful as the engine grows.
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

    /// Derives an independent, deterministic sub-stream.
    public func fork(stream: UInt64) -> SeededRNG {
        var sm = SplitMix64(state: s0 ^ (0xD1B5_4A32_D192_ED03 &* (stream &+ 1)))
        return SeededRNG(seed: sm.next())
    }

    /// Uniform double in a closed range. 53-bit precision.
    public mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    /// Bernoulli trial.
    public mutating func chance(_ p: Double) -> Bool {
        if p <= 0 { return false }
        if p >= 1 { return true }
        return double(in: 0...1) < p
    }
}

// MARK: - Clock

/// Fixed-timestep clock. The renderer will later interpolate between ticks;
/// the simulation itself only ever advances in these quanta, which is what
/// makes headless runs and on-device runs produce identical outcomes.
public enum SimClock {
    public static let ticksPerSecond: Int = 30
    public static let dt: Double = 1.0 / Double(ticksPerSecond)
}

// MARK: - Tunables

/// Global balance knobs. Deliberately one flat namespace for now so that a
/// future pass can lift these into per-level or per-difficulty data without
/// hunting through the engine. Values follow the working design document.
public enum Tunables {
    // Bounty economy: kills pay face value, routs pay less, captures pay more.
    public static let killBountyMultiplier: Double = 1.0
    public static let routBountyMultiplier: Double = 0.6
    public static let captureBountyMultiplier: Double = 1.3

    // Morale.
    public static let moraleMax: Double = 100
    public static let baseMoraleRegenPerSecond: Double = 0.5
    public static let breakMoraleSplash: Double = 15        // splash dealt to neighbours when a unit breaks
    public static let breakSplashRadius: Double = 70
    public static let waveringSplashMultiplier: Double = 2  // Wavering trait doubles the splash it emits
    public static let commandDeathShockDefault: Double = 25 // fallback if a commandAura trait omits it

    // Movement.
    public static let shakenSpeedMultiplier: Double = 0.9
    public static let routSpeedMultiplier: Double = 1.15

    // SteadyAdvance: cannot enter the Shaken state while HP is above this fraction.
    public static let steadyAdvanceHPGate: Double = 0.25

    // Contagion (camp fever). Disease never kills: it drains HP down to a floor,
    // then converts into morale pressure — softening columns for terror towers
    // instead of competing with kill towers.
    public static let contagionTickInterval: Double = 0.5
    public static let diseaseHPPerSecond: Double = 2.5
    public static let diseaseHPFloorFraction: Double = 0.15
    public static let diseaseMoralePerSecond: Double = 4.0
    public static let contagionSpreadRadius: Double = 60
    public static let contagionSpreadChance: Double = 0.35  // per tick-interval, scaled by target hardiness
}
