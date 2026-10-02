import Foundation

/// Compares the defense the player actually sees, using saved phase samples.
/// No battle is executed. Prices, identities and activity come from the record.
public enum GeneticDefenseComparison {
    /// Explicit recommendation policy, not combat tuning or a measurement of fun.
    public static let sharedCoreLimit = 0.60
    public static let minimumOpeningTurnover = 0.40
    public static let minimumDamageTurnover = 0.40
    public static let minimumControlTurnover = 0.50
    /// Enemy-seconds per elapsed second, kept separate from damage and money.
    public static let minimumChangedControlRate = 0.50
    public static let nearbyRouteProgress = 0.08

    public struct Match: Equatable, Sendable {
        public let leftSlot: Int
        public let rightSlot: Int
        public let familyID: UUID
        public let sharedCost: Double
    }
    public struct Phase: Equatable, Sendable {
        public let damageTurnover: Double
        public let blockingTurnover: Double
        public let slowingTurnover: Double
        public let changedBlockingRate: Double
        public let changedSlowingRate: Double
        public var difference: Double {
            max(damageTurnover,
                changedBlockingRate >= minimumChangedControlRate ? blockingTurnover : 0,
                changedSlowingRate >= minimumChangedControlRate ? slowingTurnover : 0)
        }
        public var qualifies: Bool {
            damageTurnover >= minimumDamageTurnover
                || (blockingTurnover >= minimumControlTurnover && changedBlockingRate >= minimumChangedControlRate)
                || (slowingTurnover >= minimumControlTurnover && changedSlowingRate >= minimumChangedControlRate)
        }
    }
    public struct Result: Equatable, Sendable {
        public let unknownReason: String?
        public let sharedOpeningLayout: Double?
        /// Shared paid opening defense / the smaller paid opening defense.
        /// Containment is deliberate: adding extras cannot hide the old core.
        public let sharedOpeningCore: Double?
        public let openingFamilyTurnover: Double?
        public let matches: [Match]
        public let early: Phase?
        public let middle: Phase?
        public var rejectionReasons: [String] {
            if let unknownReason { return ["unknown evidence: \(unknownReason)"] }
            var reasons: [String] = []
            if (sharedOpeningLayout ?? 1) >= sharedCoreLimit { reasons.append("same visible opening") }
            if (sharedOpeningCore ?? 1) >= sharedCoreLimit { reasons.append("shared dominant opening defense") }
            if (openingFamilyTurnover ?? 0) < minimumOpeningTurnover { reasons.append("same main opening army") }
            if early?.qualifies != true { reasons.append("same early damage/control roles") }
            if middle?.qualifies != true { reasons.append("defenses converge by the middle waves") }
            return reasons
        }
        public var qualifies: Bool { rejectionReasons.isEmpty }
        /// The weakest meaningful dimension governs novelty. Later investment,
        /// workload and risk cannot compensate for a repetitive opening.
        public var novelty: Double {
            guard unknownReason == nil, let sharedOpeningLayout, let sharedOpeningCore, let openingFamilyTurnover,
                  let early, let middle else { return 0 }
            return min(1 - sharedOpeningLayout, 1 - sharedOpeningCore, openingFamilyTurnover, early.difference, middle.difference)
        }
    }
    private struct Evidence {
        let phases: [[Int: GeneticPlaystyle.Tower]]
        let duration: [Double]
        let opening: [GeneticPlaystyle.Tower]
    }
    private static func evidence(_ plan: GeneticPlacementPlan) -> Evidence? {
        guard let style = plan.playstyle else { return nil }
        var phases: [[Int: GeneticPlaystyle.Tower]] = []
        var times: [Double] = []
        for phase in 0...2 {
            let towers = style.towers.filter { $0.phase == phase }
            guard !towers.isEmpty, Set(towers.map(\.slot)).count == towers.count,
                  let time = towers.first?.seconds, time.isFinite,
                  towers.allSatisfy({ t in
                      t.seconds == time && t.spent >= 0 && t.damage.isFinite && t.damage >= 0
                          && t.blockingSeconds.isFinite && t.blockingSeconds >= 0
                          && t.slowingSeconds.map { $0.isFinite && $0 >= 0 } == true
                          && Set(t.routes.map(\.index)).count == t.routes.count
                          && t.routes.allSatisfy { $0.progress.isFinite && (0...1).contains($0.progress) }
                  }) else { return nil }
            phases.append(Dictionary(uniqueKeysWithValues: towers.map { ($0.slot,$0) }))
            times.append(time)
        }
        guard times[0] < times[1], times[1] < times[2],
              phases[0].count == plan.initial.count,
              plan.initial.allSatisfy({ phases[0][$0.slot]?.familyID == $0.towerID }) else { return nil }
        // A family cannot change at a slot, nor can cumulative activity go back.
        for phase in 1...2 {
            for (slot, old) in phases[phase - 1] {
                guard let new = phases[phase][slot], new.familyID == old.familyID,
                      new.damage >= old.damage, new.blockingSeconds >= old.blockingSeconds,
                      new.slowingSeconds! >= old.slowingSeconds! else { return nil }
            }
        }
        let opening = phases[0].values.filter { t in
            guard let early = phases[1][t.slot] else { return false }
            // Economy and idle purchases do not dilute the defensive denominator.
            return t.spent > 0 && (early.damage > t.damage || early.blockingSeconds > t.blockingSeconds
                || early.slowingSeconds! > t.slowingSeconds! || early.shots > t.shots || early.detonations > t.detonations)
        }.sorted { $0.slot < $1.slot }
        guard !opening.isEmpty else { return nil }
        return Evidence(phases: phases, duration: [times[1] - times[0],times[2] - times[1]], opening: opening)
    }
    public static func compare(_ left: GeneticPlacementPlan, _ right: GeneticPlacementPlan) -> Result {
        guard let a = evidence(left), let b = evidence(right) else {
            return Result(unknownReason: "complete opening, one-third and two-thirds activity samples required",
                sharedOpeningLayout: nil, sharedOpeningCore: nil, openingFamilyTurnover: nil, matches: [], early: nil, middle: nil)
        }
        func match(_ left: [GeneticPlaystyle.Tower], _ right: [GeneticPlaystyle.Tower]) -> (Double,[Match]) {
            let weights = left.map { x in right.map { y in
                x.familyID == y.familyID && equivalentLocation(x,y) ? Double(min(x.spent,y.spent)) : 0
            } }
            let matches = maximumMatching(weights).map { i,j in
                Match(leftSlot:left[i].slot,rightSlot:right[j].slot,
                    familyID:left[i].familyID,sharedCost:weights[i][j])
            }
            let leftCost = left.reduce(0.0) { $0 + Double($1.spent) }
            let rightCost = right.reduce(0.0) { $0 + Double($1.spent) }
            return (matches.reduce(0) { $0 + $1.sharedCost } / min(leftCost,rightCost), matches)
        }
        let (core, matches) = match(a.opening,b.opening)
        // Check the visible layout too: the very same initial movie cannot
        // qualify merely because different subsets eventually participate.
        let (layout, _) = match(a.phases[0].values.sorted { $0.slot < $1.slot },
                                b.phases[0].values.sorted { $0.slot < $1.slot })
        func mix(_ towers: [GeneticPlaystyle.Tower]) -> [String:Double] {
            towers.reduce(into: [:]) { $0[$1.familyID.uuidString,default:0] += Double($1.spent) }
        }
        return Result(unknownReason:nil,
            sharedOpeningLayout:layout,sharedOpeningCore:core,
            openingFamilyTurnover:turnover(mix(a.opening),mix(b.opening)),matches:matches,
            early:phase(a,b,index:1),middle:phase(a,b,index:2))
    }
    /// Route fingerprints describe coverage, not observed enemy interceptions.
    /// Nearby positions need substantially the same covered paths and progress;
    /// changing a slot number alone is not a different defense.
    private static func equivalentLocation(_ a: GeneticPlaystyle.Tower, _ b: GeneticPlaystyle.Tower) -> Bool {
        if a.slot == b.slot { return true }
        let x = Dictionary(uniqueKeysWithValues:a.routes.map { ($0.index,$0.progress) })
        let y = Dictionary(uniqueKeysWithValues:b.routes.map { ($0.index,$0.progress) })
        let common = Set(x.keys).intersection(y.keys), union = Set(x.keys).union(y.keys)
        return !union.isEmpty && Double(common.count) / Double(union.count) >= 0.8
            && common.allSatisfy { abs(x[$0]! - y[$0]!) <= nearbyRouteProgress }
    }
    private static func turnover(_ a: [String:Double], _ b: [String:Double]) -> Double {
        let x = GeneticPlaystyle.normalized(a), y = GeneticPlaystyle.normalized(b)
        if x.isEmpty && y.isEmpty { return 0 }
        if x.isEmpty || y.isEmpty { return 1 }
        return GeneticPlaystyle.distance(x,y)
    }
    private static func phase(_ a: Evidence, _ b: Evidence, index: Int) -> Phase {
        func values(_ evidence: Evidence, _ value: (GeneticPlaystyle.Tower) -> Double) -> [String:Double] {
            var result: [String:Double] = [:]
            for slot in evidence.phases[index].keys.sorted() {
                let t = evidence.phases[index][slot]!
                let previous = evidence.phases[index - 1][t.slot].map(value) ?? 0
                // Family, not current tier: cumulative activity cannot establish
                // which branch caused damage before a tier change.
                result[t.familyID.uuidString,default:0] += max(0,value(t) - previous) / evidence.duration[index - 1]
            }
            return result
        }
        let damageA = values(a, { $0.damage }), damageB = values(b, { $0.damage })
        let blockA = values(a, { $0.blockingSeconds }), blockB = values(b, { $0.blockingSeconds })
        let slowA = values(a, { $0.slowingSeconds! }), slowB = values(b, { $0.slowingSeconds! })
        // Only genuinely different families' control counts here. More or less
        // activity from an unchanged controller is not a new role.
        func changedRate(_ x: [String:Double], _ y: [String:Double]) -> Double {
            let left = x.keys.filter { y[$0,default:0] == 0 }.sorted().reduce(0) { $0 + x[$1]! }
            let right = y.keys.filter { x[$0,default:0] == 0 }.sorted().reduce(0) { $0 + y[$1]! }
            return max(left,right)
        }
        return Phase(damageTurnover:turnover(damageA,damageB),
            blockingTurnover:turnover(blockA,blockB),slowingTurnover:turnover(slowA,slowB),
            changedBlockingRate:changedRate(blockA,blockB),changedSlowingRate:changedRate(slowA,slowB))
    }
    /// Maximum-weight one-to-one assignment (Hungarian algorithm), O(n^3).
    /// Greedy matching can double-count or miss a common core when neighboring
    /// coverage areas overlap. Dummy zero edges leave towers unmatched.
    static func maximumMatching(_ weights: [[Double]]) -> [(Int,Int)] {
        guard let columns = weights.first?.count, columns > 0 else { return [] }
        let rows = weights.count, n = max(rows,columns)
        var u = Array(repeating:0.0,count:n+1), v = u
        var p = Array(repeating:0,count:n+1), way = p
        for i in 1...n {
            p[0] = i
            var j0 = 0, distance = Array(repeating:Double.infinity,count:n+1)
            var used = Array(repeating:false,count:n+1)
            repeat {
                used[j0] = true
                let i0 = p[j0]
                var delta = Double.infinity, j1 = 0
                for j in 1...n where !used[j] {
                    let weight = i0 <= rows && j <= columns ? weights[i0-1][j-1] : 0
                    let cost = -weight - u[i0] - v[j]
                    if cost < distance[j] { distance[j] = cost; way[j] = j0 }
                    if distance[j] < delta { delta = distance[j]; j1 = j }
                }
                for j in 0...n {
                    if used[j] { u[p[j]] += delta; v[j] -= delta } else { distance[j] -= delta }
                }
                j0 = j1
            } while p[j0] != 0
            repeat {
                let j1 = way[j0]; p[j0] = p[j1]; j0 = j1
            } while j0 != 0
        }
        return (1...n).compactMap { j in
            let i = p[j]
            return i <= rows && j <= columns && weights[i-1][j-1] > 0 ? (i-1,j-1) : nil
        }.sorted { $0.0 < $1.0 }
    }
}
