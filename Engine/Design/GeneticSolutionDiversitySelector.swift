import Foundation

/// Chooses different winning playstyles for players. Original fitness remains
/// evidence and a stable tie-break; it is not a score for creativity or fun.
/// Eligibility requires a different opening core and sustained observed combat
/// roles. Extra support, later spending and workload cannot offset a shared core.
/// Comparison reads saved evidence only and never executes a strategy.
public final class GeneticSolutionDiversitySelector {
    public typealias Placement = GeneticPlacementPlan.Placement
    public typealias Profile = GeneticPlacementPlan

    public init() {}

    public struct Comparison: Equatable, Sendable, CustomStringConvertible {
        public let initialSlots: Int
        public let differentInitialSlots: Int
        public let comparedSubsequentPlacements: Int
        public let differentSubsequentPlacements: Int
        /// Total variation between participating opening-family proportions.
        public let compositionDifference: Double
        /// Largest fraction in either opening belonging to families absent
        /// from the other participating opening. Unused towers cannot establish
        /// a new role. The denominator still includes all original placements.
        public let newFamilyShare: Double
        public let defense: GeneticDefenseComparison.Result
        public let investmentDifference: Double?
        public let mechanicsDifference: Double?
        public let developmentDifference: Double?
        public let spatialDifference: Double?
        public let workloadDifference: Double?
        public let riskDifference: Double?
        public var initialQualifies: Bool {
            initialSlots > 0 && differentInitialSlots * 4 >= initialSlots * 3
        }
        public var qualifies: Bool { defense.qualifies }
        public var novelty: Double { defense.novelty }
        public var rejectionReasons: [String] { defense.rejectionReasons }

        public var description: String {
            func percent(_ value: Double?) -> String {
                value.map { String(format: "%.1f%%", $0 * 100) } ?? "unknown"
            }
            return "\(qualifies ? "eligible" : "rejected: " + rejectionReasons.joined(separator: "; ")); "
                + "shared visible opening \(percent(defense.sharedOpeningLayout)), "
                + "shared opening core \(percent(defense.sharedOpeningCore)), "
                + "opening family turnover \(percent(defense.openingFamilyTurnover)), "
                + "early/middle damage turnover \(percent(defense.early?.damageTurnover))/\(percent(defense.middle?.damageTurnover)); "
                + "matched opening slots \(defense.matches.map { "\($0.leftSlot):\($0.rightSlot)" }.joined(separator: ","))"
        }

    }

    public struct Selection<Item> {
        public let item: Item
        public let profile: Profile
        public let fitnessRank: Int
        /// Same order as the preceding selections; every pair must qualify.
        public let comparisons: [Comparison]
    }

    /// Exact slot/count and lifetime descriptors remain diagnostics. Eligibility
    /// uses visible opening, shared defense and sustained combat-role changes;
    /// moving the same artillery/ranged mix is not a new style.
    /// Profiles contain DAO-authored level-one identities, never future branches.
    public func compare(_ a: Profile, _ b: Profile) throws -> Comparison {
        guard a.initial.allSatisfy({ $0.slot >= 0 }), b.initial.allSatisfy({ $0.slot >= 0 }),
              Set(a.initial.map(\.slot)).count == a.initial.count,
              Set(b.initial.map(\.slot)).count == b.initial.count else {
            throw DbError.Db(message: "genetic diversity: invalid or duplicate initial tower slot")
        }
        let left = Dictionary(uniqueKeysWithValues: a.initial.map { ($0.slot, $0.towerID) })
        let right = Dictionary(uniqueKeysWithValues: b.initial.map { ($0.slot, $0.towerID) })
        let slots = Set(left.keys).union(right.keys)
        let pairs = Array(zip(a.subsequent.prefix(5), b.subsequent.prefix(5)))
        let leftActive = a.playstyle.map { $0.participatingSlots }
        let rightActive = b.playstyle.map { $0.participatingSlots }
        let leftOpening = a.initial.filter { leftActive?.contains($0.slot) ?? true }
        let rightOpening = b.initial.filter { rightActive?.contains($0.slot) ?? true }
        let leftMix = Dictionary(grouping: leftOpening, by: \.towerID).mapValues(\.count)
        let rightMix = Dictionary(grouping: rightOpening, by: \.towerID).mapValues(\.count)
        var distance = 0.0, newShare = 0.0
        if !leftOpening.isEmpty, !rightOpening.isEmpty {
            let families = Set(leftMix.keys).union(rightMix.keys)
            distance = families.sorted { $0.uuidString < $1.uuidString }.reduce(0.0) { sum, family in
                sum + abs(Double(leftMix[family, default: 0]) / Double(leftOpening.count)
                        - Double(rightMix[family, default: 0]) / Double(rightOpening.count))
            } / 2
            let leftNew = leftMix.filter { rightMix[$0.key] == nil }.values.reduce(0, +)
            let rightNew = rightMix.filter { leftMix[$0.key] == nil }.values.reduce(0, +)
            newShare = max(Double(leftNew) / Double(a.initial.count), Double(rightNew) / Double(b.initial.count))
        }
        let x = a.playstyle?.descriptor, y = b.playstyle?.descriptor
        let investment = x.flatMap { x in y.map { GeneticPlaystyle.distance(x.investment, $0.investment) } }
        let mechanics = x.flatMap { x in y.map { GeneticPlaystyle.distance(x.mechanics, $0.mechanics) } }
        let development = x.flatMap { x in y.map { max(GeneticPlaystyle.distance(x.development, $0.development),
            abs(x.concentration - $0.concentration), abs(x.earlySpending - $0.earlySpending)) } }
        let spatial = x.flatMap { x in y.map { GeneticPlaystyle.distance(x.spatial, $0.spatial) } }
        let workload = x.flatMap { x in y.map { abs(x.actionsPerMinute - $0.actionsPerMinute) / max(1, x.actionsPerMinute, $0.actionsPerMinute) } }
        let risk = x.flatMap { x in y.map { abs(x.recoveryMargin - $0.recoveryMargin) } }
        return Comparison(initialSlots: slots.count,
            differentInitialSlots: slots.filter { left[$0] != right[$0] }.count,
            comparedSubsequentPlacements: pairs.count,
            differentSubsequentPlacements: pairs.filter { $0.0 != $0.1 }.count,
            compositionDifference: distance, newFamilyShare: newShare,
            defense: GeneticDefenseComparison.compare(a,b), investmentDifference: investment,
            mechanicsDifference: mechanics, developmentDifference: development, spatialDifference: spatial,
            workloadDifference: workload, riskDifference: risk)
    }

    /// Require the advertised difference on at least 90% of matching held-out
    /// seeds, not just the best-looking representative. No battles are executed.
    public func consistentlyDifferent(_ a: GeneticCandidate, _ b: GeneticCandidate) throws -> Bool {
        let left = Dictionary(a.evaluations.map { ($0.seed, $0) }, uniquingKeysWith: { x, _ in x })
        let right = Dictionary(b.evaluations.map { ($0.seed, $0) }, uniquingKeysWith: { x, _ in x })
        guard !left.isEmpty, left.count == a.evaluations.count, right.count == b.evaluations.count,
              Set(left.keys) == Set(right.keys) else { return false }
        var qualifying = 0
        for seed in left.keys.sorted() {
            guard let x = left[seed]?.placementPlan, let y = right[seed]?.placementPlan,
                  x.playstyle != nil, y.playstyle != nil else { return false }
            if try compare(x,y).qualifies { qualifying += 1 }
        }
        return qualifying * 10 >= left.count * 9
    }

    /// Publication chooses a complete set of compatible validated winners.
    /// Prefer the strongest baseline that permits that set; a slightly stronger
    /// plan must not crowd out an entire playstyle. Within each baseline, try
    /// alternatives in max-min novelty order, backtracking around dead ends.
    /// Pair checks are cached, and use saved evidence only. Intended for the
    /// validated finalist pool; `select` below is a fast greedy archive diagnostic.
    public func selectCompleteSet<Item>(ranked: [Item], count: Int = 3,
        plan: (Item) throws -> Profile,
        pairEligible: ((Item, Item) throws -> Bool)? = nil) throws -> [Selection<Item>] {
        guard count > 0 else { throw DbError.Db(message: "genetic diversity: selection count must be positive") }
        let profiles = try ranked.map { item in
            let profile = try plan(item)
            _ = try compare(profile, profile)
            return profile
        }
        var comparisons: [Int: [Int: Comparison]] = [:]
        var eligibility: [Int: [Int: Bool]] = [:]
        func pair(_ a: Int, _ b: Int) throws -> (Comparison, Bool) {
            let low = min(a,b), high = max(a,b)
            if let comparison = comparisons[low]?[high], let eligible = eligibility[low]?[high] {
                return (comparison,eligible)
            }
            let comparison = try compare(profiles[low],profiles[high])
            let eligible = try comparison.qualifies && (pairEligible?(ranked[low],ranked[high]) ?? true)
            comparisons[low,default:[:]][high] = comparison
            eligibility[low,default:[:]][high] = eligible
            return (comparison,eligible)
        }
        var bestPartial: [Int] = []
        var exhausted: Set<[Int]> = []
        func extend(_ selected: [Int], remaining: [Int]) throws -> [Int]? {
            if selected.count > bestPartial.count { bestPartial = selected }
            if selected.count == count { return selected }
            let key = selected.sorted()
            guard !exhausted.contains(key) else { return nil }
            var options: [(index: Int, novelty: Double)] = []
            for index in remaining {
                let pairs = try selected.map { try pair($0,index) }
                if pairs.allSatisfy({ $0.1 }), let novelty = pairs.map({ $0.0.novelty }).min() {
                    options.append((index,novelty))
                }
            }
            options.sort { $0.novelty == $1.novelty ? $0.index < $1.index : $0.novelty > $1.novelty }
            for option in options {
                if let complete = try extend(selected + [option.index],
                    remaining: options.map(\.index).filter { $0 != option.index }) { return complete }
            }
            exhausted.insert(key)
            return nil
        }
        var chosen: [Int]?
        for first in ranked.indices {
            if let complete = try extend([first],remaining:Array(ranked.indices.dropFirst(first + 1))) {
                chosen = complete
                break
            }
        }
        let indices = chosen ?? bestPartial
        return try indices.enumerated().map { offset,index in
            Selection(item:ranked[index],profile:profiles[index],fitnessRank:index + 1,
                comparisons:try indices.prefix(offset).map { try pair($0,index).0 })
        }
    }

    /// Caller supplies eligible winners and their original fitness order.
    /// Keep the strongest as one reliable reference. For each alternative,
    /// maximize its minimum composition distance to ALL selected plans.
    /// Fitness order breaks novelty ties; original scores are never changed.
    /// Fewer results means a shortfall, not permission to add near-duplicates.
    public func select<Item>(ranked: [Item], count: Int = 3,
        plan: (Item) throws -> Profile,
        pairEligible: ((Item, Item) throws -> Bool)? = nil) throws -> [Selection<Item>] {
        guard count > 0 else { throw DbError.Db(message: "genetic diversity: selection count must be positive") }
        var remaining: [(item: Item, profile: Profile, rank: Int)] = try ranked.enumerated().map { index, item in
            let profile = try plan(item)
            _ = try compare(profile, profile)
            return (item, profile, index + 1)
        }
        guard !remaining.isEmpty else { return [] }
        let first = remaining.removeFirst()
        var selected = [Selection(item: first.item, profile: first.profile, fitnessRank: first.rank, comparisons: [])]
        while selected.count < count, !remaining.isEmpty {
            var choice: Int?, bestDistance = -Double.infinity
            var chosenComparisons: [Comparison] = []
            for index in remaining.indices {
                let comparisons = try selected.map { try compare($0.profile, remaining[index].profile) }
                guard comparisons.allSatisfy(\.qualifies), let minimum = comparisons.map(\.novelty).min() else { continue }
                if let pairEligible, try !selected.allSatisfy({ try pairEligible($0.item, remaining[index].item) }) { continue }
                if minimum > bestDistance {
                    choice = index; bestDistance = minimum; chosenComparisons = comparisons
                }
            }
            guard let choice else { break }
            let next = remaining.remove(at: choice)
            selected.append(Selection(item: next.item, profile: next.profile,
                fitnessRank: next.rank, comparisons: chosenComparisons))
        }
        return selected
    }
}
