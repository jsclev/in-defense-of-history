// Traits.swift
// Binary traits, per the design rule: three resists is the stat ceiling —
// everything else an enemy does differently is a trait, not a number.
//
// Traits marked (active) are simulated by the engine today. The rest are
// carried through data and the encyclopedia so content can be authored now,
// and they light up as their systems come online (blockers, map cover,
// counterintelligence, sabotage...).

public enum Trait: Sendable, Equatable {
    // -- Active in the simulation --

    /// (active) On break, this unit's morale splash to neighbours is doubled.
    case wavering

    /// (active) When Broken, surrenders instead of routing: removed at once,
    /// pays the capture bounty. Hessians are the capture-economy engine.
    case mercenary

    /// (active) Cannot enter the Shaken state while HP is above the gate
    /// fraction (Tunables.steadyAdvanceHPGate). The grenadier doesn't flinch.
    case steadyAdvance

    /// (active) Aura: regenerates morale for allies within `radius`.
    /// The drum is the aura; kill the drummer, stop the healing.
    case rallyBeat(radius: Double, moralePerSecond: Double)

    /// (active) Aura: allies within `radius` gain `disciplineBonus` (capped at
    /// 1.0). On death, deals `deathShock` morale damage in the same radius.
    case commandAura(radius: Double, disciplineBonus: Double, deathShock: Double)

    // -- Data-only for now (systems arrive later) --

    case skirmish            // untargetable in map cover (needs cover regions)
    case marksman            // fires on tower crews (needs crew/blocker layer)
    case saboteur            // exit costs no life; steals gold / spikes a tower
    case disguised           // needs counterintelligence reveal
    case tacticalWithdrawal  // withdraws in good order; rallies and returns
    case highlandCharge      // terror damage to blockers on charge
    case rideDown            // shoves blockers; terrorizes low-discipline units
    case falter              // held 3s+ -> loses momentum, takes bonus damage
    case bombard             // halts to shell towers (needs tower-disable layer)
    case crewed              // gun is tough, crew is not

    /// Forward-compatible catch-all so old builds can load newer content.
    case tag(String)
}

// MARK: - Codable (stable, human-readable JSON for the DB `traits` column)

extension Trait: Codable {
    private enum K: String, CodingKey {
        case type, radius, moralePerSecond, disciplineBonus, deathShock, name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "wavering": self = .wavering
        case "mercenary": self = .mercenary
        case "steadyAdvance": self = .steadyAdvance
        case "rallyBeat":
            self = .rallyBeat(
                radius: try c.decode(Double.self, forKey: .radius),
                moralePerSecond: try c.decode(Double.self, forKey: .moralePerSecond)
            )
        case "commandAura":
            self = .commandAura(
                radius: try c.decode(Double.self, forKey: .radius),
                disciplineBonus: try c.decode(Double.self, forKey: .disciplineBonus),
                deathShock: try c.decodeIfPresent(Double.self, forKey: .deathShock)
                    ?? Tunables.commandDeathShockDefault
            )
        case "skirmish": self = .skirmish
        case "marksman": self = .marksman
        case "saboteur": self = .saboteur
        case "disguised": self = .disguised
        case "tacticalWithdrawal": self = .tacticalWithdrawal
        case "highlandCharge": self = .highlandCharge
        case "rideDown": self = .rideDown
        case "falter": self = .falter
        case "bombard": self = .bombard
        case "crewed": self = .crewed
        case "tag":
            self = .tag(try c.decode(String.self, forKey: .name))
        default:
            // Unknown trait from a newer content build: preserve, don't fail.
            self = .tag(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        switch self {
        case .wavering: try c.encode("wavering", forKey: .type)
        case .mercenary: try c.encode("mercenary", forKey: .type)
        case .steadyAdvance: try c.encode("steadyAdvance", forKey: .type)
        case let .rallyBeat(radius, rate):
            try c.encode("rallyBeat", forKey: .type)
            try c.encode(radius, forKey: .radius)
            try c.encode(rate, forKey: .moralePerSecond)
        case let .commandAura(radius, bonus, shock):
            try c.encode("commandAura", forKey: .type)
            try c.encode(radius, forKey: .radius)
            try c.encode(bonus, forKey: .disciplineBonus)
            try c.encode(shock, forKey: .deathShock)
        case .skirmish: try c.encode("skirmish", forKey: .type)
        case .marksman: try c.encode("marksman", forKey: .type)
        case .saboteur: try c.encode("saboteur", forKey: .type)
        case .disguised: try c.encode("disguised", forKey: .type)
        case .tacticalWithdrawal: try c.encode("tacticalWithdrawal", forKey: .type)
        case .highlandCharge: try c.encode("highlandCharge", forKey: .type)
        case .rideDown: try c.encode("rideDown", forKey: .type)
        case .falter: try c.encode("falter", forKey: .type)
        case .bombard: try c.encode("bombard", forKey: .type)
        case .crewed: try c.encode("crewed", forKey: .type)
        case let .tag(name):
            try c.encode("tag", forKey: .type)
            try c.encode(name, forKey: .name)
        }
    }
}
