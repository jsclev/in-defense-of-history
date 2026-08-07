// Stats.swift
// The three-resist triangle from the design doc:
//   shot      -> resisted by cover       (formation looseness / concealment)
//   terror    -> resisted by discipline  (1.0 == Unbreakable, immune to rout)
//   contagion -> resisted by hardiness   (inoculation / seasoning)

public enum DamageType: String, Codable, Sendable, CaseIterable {
    case shot
    case terror
    case contagion
    case trueDamage = "true"
}

/// Live morale state, rendered in-game through posture, flag, and glyph —
/// never a second bar. The engine only needs the three-way state machine.
public enum MoraleState: String, Codable, Sendable {
    case steady
    case shaken
    case broken
}

/// The printed stat block for an enemy type — what the encyclopedia shows.
/// `discipline`, `cover`, and `hardiness` are 0...1 resist fractions.
public struct EnemyStats: Codable, Sendable, Equatable {
    public var maxHP: Double
    /// Movement speed in virtual-coordinate units per second.
    public var speed: Double
    /// Resists shot damage. 0.45 == takes 55% of rolled shot damage.
    public var cover: Double
    /// Resists terror damage. 1.0 == Unbreakable (rout-immune).
    public var discipline: Double
    /// Resists contagion application and spread.
    public var hardiness: Double
    /// Damage dealt to blocking troops (blockers are a future system; the
    /// numbers ride along now so the data model doesn't churn later).
    public var damageMin: Double
    public var damageMax: Double
    /// Kill bounty at face value. Routs pay 60%, captures 130% (Tunables).
    public var gold: Int
    /// Lives lost if this unit reaches the exit.
    public var livesCost: Int
    /// Hidden per-unit variance: the Shaken threshold is sampled uniformly in
    /// this band (as a fraction of max morale) at spawn. Uniform thresholds
    /// make squads flip in lockstep; a band makes cascades ripple — the
    /// shakiest men bolt first and drag the rest.
    public var breakBand: ClosedRange<Double>

    public init(
        maxHP: Double,
        speed: Double,
        cover: Double,
        discipline: Double,
        hardiness: Double,
        damageMin: Double,
        damageMax: Double,
        gold: Int,
        livesCost: Int,
        breakBand: ClosedRange<Double>
    ) {
        self.maxHP = maxHP
        self.speed = speed
        self.cover = cover
        self.discipline = discipline
        self.hardiness = hardiness
        self.damageMin = damageMin
        self.damageMax = damageMax
        self.gold = gold
        self.livesCost = livesCost
        self.breakBand = breakBand
    }
}
