public enum Trait: Sendable, Equatable {

    case wavering

    case mercenary

    case steadyAdvance

    case rallyBeat(radius: Double, moralePerSecond: Double)

    case commandAura(radius: Double, disciplineBonus: Double, deathShock: Double)

    case skirmish
    case marksman
    case saboteur
    case disguised
    case tacticalWithdrawal
    case highlandCharge
    case rideDown
    case falter
    case bombard
    case crewed

    case tag(String)
}

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
