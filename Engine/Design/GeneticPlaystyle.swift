import Foundation

/// Observed purchases and four phase samples, not playback or speculative DNA.
/// All identities and capabilities are captured from the authored content.
public struct GeneticPlaystyle: Codable, Equatable, Sendable {
    public struct Purchase: Codable, Equatable, Sendable {
        public let seconds: Double
        public let wave: Int
        public let slot: Int
        public let familyID: UUID
        public let tierID: UUID
        public let action: String
        public let pathID: String?
        public let cost: Int
    }
    public struct Tower: Codable, Equatable, Sendable {
        public struct Route: Codable, Equatable, Sendable {
            public let index: Int
            public let progress: Double
        }
        public let phase: Int
        public let seconds: Double
        public let slot: Int
        public let familyID: UUID
        public let tierID: UUID
        public let level: Int
        public let branch: Int
        public let attackMode: String
        public let spent: Int
        public let damage: Double
        public let shots: Int
        public let blockingSeconds: Double
        public let income: Int
        public let detonations: Int
        public let routes: [Route]
        /// Unknown for evaluations made before control attribution was captured.
        public var slowingSeconds: Double? = nil
    }
    public let duration: Double
    public let purchases: [Purchase]
    public let towers: [Tower]
    public let reinforcementActions: Int
    public let earlyWaveActions: Int
    public let demolitionActions: Int
    public let startingLives: Int
    public let minimumLives: Int

    /// A tower must have done something in the original battle before its
    /// presence can establish a different player-facing opening role.
    public var participatingSlots: Set<Int> {
        Set(towers.filter { $0.damage > 0 || $0.shots > 0 || $0.blockingSeconds > 0
            || ($0.slowingSeconds ?? 0) > 0 || $0.income > 0 || $0.detonations > 0 }.map(\.slot))
    }

    /// Persist raw evidence; derive interpretable comparison dimensions from it.
    /// Time-weighted investment prevents a last-second purchase becoming a style.
    public struct Descriptor: Sendable {
        public let opening: [String: Double]
        public let materialOpeningFamilies: Set<String>
        public let investment: [String: Double]
        public let mechanics: [String: Double]
        public let spatial: [String: Double]
        public let development: [String: Double]
        public let actionsPerMinute: Double
        public let concentration: Double
        public let earlySpending: Double
        public let recoveryMargin: Double
        public let niche: String
    }
    public var descriptor: Descriptor {
        var investment: [String: Double] = [:], mechanics: [String: Double] = [:]
        var spatial: [String: Double] = [:], development: [String: Double] = [:]
        let lifetime = max(duration, 0.001)
        var bySlot: [Int: Double] = [:], total = 0.0, early = 0.0
        for p in purchases {
            let weight = Double(p.cost) * max(0, 1 - p.seconds / lifetime)
            investment[p.familyID.uuidString, default: 0] += weight
            bySlot[p.slot, default: 0] += weight
            total += Double(p.cost)
            if p.seconds <= lifetime / 3 { early += Double(p.cost) }
            development["phase-\(min(2, Int(p.seconds / lifetime * 3)))", default: 0] += Double(p.cost)
        }
        let grouped = Dictionary(grouping: towers, by: \.slot)
        for slot in grouped.keys.sorted() {
            let observations = grouped[slot]!
            var previousDamage = 0.0, previousBlock = 0.0, previousSlow = 0.0, previousIncome = 0
            var previousShots = 0, previousDetonations = 0
            var previous: Tower?
            for t in observations.sorted(by: { $0.phase < $1.phase }) {
                // Use demonstrated activity, not possession of a future branch.
                let blocking = t.blockingSeconds > previousBlock
                let slowing = t.slowingSeconds.map { $0 > previousSlow } == true
                let earning = t.income > previousIncome
                let active = t.damage > previousDamage || blocking || earning
                    || t.shots > previousShots || t.detonations > previousDetonations || slowing
                previousDamage = t.damage; previousBlock = t.blockingSeconds; previousIncome = t.income
                previousShots = t.shots; previousDetonations = t.detonations
                if let slowing = t.slowingSeconds { previousSlow = slowing }
                let prior = previous
                previous = t
                // Cumulative damage before a tier change cannot be attributed to
                // the new branch. Wait for a stable observation interval; a new
                // unupgraded build has a known zero baseline at construction.
                let lastTierPurchase = purchases.last { $0.slot == t.slot && $0.seconds <= t.seconds
                    && ($0.action == "build" || $0.action == "upgrade") }
                let stableTier = prior?.tierID == t.tierID || lastTierPurchase?.action == "build"
                guard t.phase > 0, active, stableTier else { continue }
                let committed = purchases.filter { $0.slot == t.slot && $0.seconds <= t.seconds }.reduce(0.0) {
                    $0 + Double($1.cost) * max(0, 1 - $1.seconds / lifetime)
                }
                let weight = committed * (t.phase == 3 ? 0.5 : 1)
                mechanics["mode:\(t.attackMode)", default: 0] += weight
                mechanics["tier:\(t.tierID)", default: 0] += weight
                if blocking { mechanics["blocking", default: 0] += weight }
                if slowing { mechanics["slowing", default: 0] += weight }
                if earning { mechanics["economy", default: 0] += weight }
                for r in t.routes {
                    spatial["route:\(r.index)/third:\(min(2, Int(r.progress * 3)))", default: 0] += weight / Double(max(1, t.routes.count))
                }
                development[t.level >= 3 ? "developed" : "basic", default: 0] += weight
                // Purchased abilities count only when their tower participated.
                let activityStart = prior?.seconds ?? lastTierPurchase?.seconds ?? 0
                for p in purchases where p.slot == t.slot && p.seconds <= activityStart {
                    if let path = p.pathID {
                        mechanics["ability:\(path)", default: 0] += Double(p.cost) * max(0, 1 - p.seconds / lifetime)
                    }
                }
            }
        }
        let mix = Self.normalized(investment)
        var openingCounts: [String: Double] = [:]
        for p in purchases where p.wave == 0 && p.action == "build" {
            openingCounts[p.familyID.uuidString, default: 0] += 1
        }
        let opening = Self.normalized(openingCounts)
        let roles = Set(opening.keys.filter { opening[$0]! >= 0.25 && mix[$0, default: 0] >= 0.15 })
        let invested = bySlot.keys.sorted().reduce(0.0) { $0 + bySlot[$1]! }
        let concentration = bySlot.values.max().map { $0 / max(0.001, invested) } ?? 0
        let earlyShare = early / max(1, total)
        let actions = purchases.count + reinforcementActions + earlyWaveActions + demolitionActions
        let rate = Double(actions) / max(1, duration / 60)
        // Coarse bins define breeding niches only, not an invented fitness score.
        let familyKey = mix.keys.sorted().map { "\($0):\(Int((mix[$0]! * 4).rounded()))" }.joined(separator: ",")
        let mechanicKey = mechanics.filter { $0.key.hasPrefix("mode:") && $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(2).map(\.key).joined(separator: ",")
        let openingKey = opening.keys.sorted().map { "\($0):\(Int((opening[$0]! * 4).rounded()))" }.joined(separator: ",")
        return Descriptor(opening: opening, materialOpeningFamilies: roles,
            investment: mix, mechanics: Self.normalized(mechanics), spatial: Self.normalized(spatial),
            development: Self.normalized(development), actionsPerMinute: rate, concentration: concentration,
            earlySpending: earlyShare, recoveryMargin: Double(minimumLives) / Double(max(1, startingLives)),
            niche: "\(openingKey)|\(familyKey)|\(mechanicKey)|\(concentration >= 0.3)|\(rate >= 4)")
    }
    static func normalized(_ values: [String: Double]) -> [String: Double] {
        let total = values.keys.sorted().reduce(0.0) { $0 + values[$1]! }
        return total > 0 ? values.mapValues { $0 / total } : [:]
    }
    static func distance(_ a: [String: Double], _ b: [String: Double]) -> Double {
        Set(a.keys).union(b.keys).sorted().reduce(0) { $0 + abs(a[$1, default: 0] - b[$1, default: 0]) } / 2
    }
}
