import Foundation

/// Breeding policy only. Protect the global champion and competitive champions
/// of distinct observed playstyles. Original battle fitness is never rewritten.
public enum GeneticBreedingDiversity {
    private struct Distance: Comparable {
        let opening: Double
        let following: Int
        let decisions: Int
        static func < (a: Self, b: Self) -> Bool {
            if a.opening != b.opening { return a.opening < b.opening }
            if a.following != b.following { return a.following < b.following }
            return a.decisions < b.decisions
        }
    }
    private struct Entry {
        let candidate: GeneticCandidate
        let fitness: GeneticFitness
        let opening: [Int: UUID]?
        let following: [GeneticPlacementPlan.Placement]?
        var nearestSelected: Distance?
        init(_ candidate: GeneticCandidate) {
            self.candidate = candidate; fitness = candidate.fitness
            let plan = candidate.placementPlan
            opening = plan.map { Dictionary($0.initial.map { ($0.slot, $0.towerID) }, uniquingKeysWith: { a, _ in a }) }
            following = plan?.subsequent
        }
        func distance(to other: Self) -> Distance {
            var openingDifference = 0.0, followingDifference = 0
            if let a = opening, let b = other.opening {
                let slots = Set(a.keys).union(b.keys)
                if !slots.isEmpty {
                    openingDifference = Double(slots.filter { a[$0] != b[$0] }.count) / Double(slots.count)
                }
            }
            if let a = following, let b = other.following {
                followingDifference = zip(a, b).filter { $0 != $1 }.count + abs(a.count - b.count)
            }
            let a = candidate.strategy.decisions, b = other.candidate.strategy.decisions
            return Distance(opening: openingDifference, following: followingDifference,
                decisions: zip(a, b).filter { $0 != $1 }.count + abs(a.count - b.count))
        }
    }

    public static func select(_ candidates: [GeneticCandidate], limit: Int,
                              distinctMetaSelections: Bool = false, creativeFinalists: Bool = false) -> [GeneticCandidate] {
        if candidates.contains(where: { $0.placementPlan?.playstyle != nil }) {
            return creative(candidates, limit: limit, distinctMetaSelections: distinctMetaSelections, finalists: creativeFinalists)
        }
        guard limit > 0 else { return [] }
        var remaining: [Entry] = candidates.map { Entry($0) }
        remaining.sort { (a: Entry, b: Entry) -> Bool in
            if a.fitness == b.fitness { return a.candidate.id < b.candidate.id }
            return a.fitness > b.fitness
        }
        var selected: [Entry] = []
        while !remaining.isEmpty, selected.count < limit {
            let bestFitness = remaining[0].fitness
            var choice = 0
            if !selected.isEmpty {
                // Only exact fitness ties participate. A more diverse loser
                // cannot displace a stronger candidate or reduce evaluation counts.
                var bestDistance = remaining[0].nearestSelected!
                for index in remaining.indices.dropFirst() {
                    guard remaining[index].fitness == bestFitness else { break }
                    let value = remaining[index].nearestSelected!
                    if value > bestDistance || (value == bestDistance && remaining[index].candidate.id > remaining[choice].candidate.id) {
                        choice = index; bestDistance = value
                    }
                }
            }
            let next = remaining.remove(at: choice)
            selected.append(next)
            if distinctMetaSelections {
                remaining.removeAll { $0.candidate.metaUpgrades == next.candidate.metaUpgrades }
            }
            // Each pair is measured once, including large fixed-meta pools.
            // Recomputing all distances after every choice grows cubically.
            for index in remaining.indices {
                let distance = remaining[index].distance(to: next)
                if let previous = remaining[index].nearestSelected {
                    remaining[index].nearestSelected = min(previous, distance)
                } else { remaining[index].nearestSelected = distance }
            }
        }
        return selected.map(\.candidate)
    }
    private static func creative(_ candidates: [GeneticCandidate], limit: Int,
                                 distinctMetaSelections: Bool, finalists: Bool) -> [GeneticCandidate] {
        guard limit > 0 else { return [] }
        let ranked = GeneticCandidate.ranked(candidates)
        guard let champion = ranked.first else { return [] }
        // Opening-role champions need room to learn even before they win. A
        // global win-rate floor previously erased them as soon as another role
        // won. Three training seeds cannot justify discarding every 2/3 style:
        // reserve up to a quarter of validation for other demonstrated winners.
        // Publication still requires the full independent reliability panel.
        let floor = finalists && champion.fitness.winRate > 0 ? 1.0 / Double(champion.evaluations.count) : 0
        let strongestBandSeats = max(1, limit - limit / 4)
        var seen: Set<String> = []
        var observed: [(candidate: GeneticCandidate, descriptor: GeneticPlaystyle.Descriptor)] = []
        var representatives: [(candidate: GeneticCandidate, descriptor: GeneticPlaystyle.Descriptor)] = []
        for c in ranked where c.fitness.winRate >= floor {
            guard let d = c.behaviorDescriptor else { continue }
            observed.append((c,d))
            if seen.insert(d.niche).inserted { representatives.append((c,d)) }
        }
        var selected = [champion], usedMeta: Set<MetaUpgradeProgression> = [champion.metaUpgrades]
        var selectedDescriptors = champion.behaviorDescriptor.map { [$0] } ?? []
        representatives.removeAll { $0.candidate.id == champion.id }
        if finalists && distinctMetaSelections {
            // Reserve one third of the panel for different successful upgrade
            // selections, then allow multiple creative plans from a selection.
            let coverage = max(1, limit / 3)
            for entry in observed where selected.count < coverage && entry.candidate.fitness.winRate == champion.fitness.winRate {
                guard !selectedDescriptors.contains(where: { $0.niche == entry.descriptor.niche }) else { continue }
                guard usedMeta.insert(entry.candidate.metaUpgrades).inserted else { continue }
                selected.append(entry.candidate); selectedDescriptors.append(entry.descriptor)
            }
            let niches = Set(selectedDescriptors.map(\.niche))
            // Coverage can select another meta selection's representative of
            // a niche. Do not select that niche's globally strongest copy too.
            representatives.removeAll { niches.contains($0.descriptor.niche) }
        }
        if !finalists {
            // A 64-plan population split among eight meta selections has only
            // eight parent seats per selection. Reserve actual seats for the
            // best material opening of each family, not eight minor variants
            // of a high-fitness artillery/ranged opening.
            var covered = Set(selectedDescriptors.flatMap(\.materialOpeningFamilies))
            let families = Set(observed.flatMap { $0.descriptor.materialOpeningFamilies }).sorted()
            for family in families where selected.count < limit && !covered.contains(family) {
                // Thresholds and coarse niche bins have different boundaries.
                // A material role must not disappear behind a slightly fitter
                // non-material candidate in the same rounded niche.
                guard let next = observed.first(where: { $0.descriptor.materialOpeningFamilies.contains(family) }) else { continue }
                representatives.removeAll { $0.candidate.id == next.candidate.id }
                selected.append(next.candidate); selectedDescriptors.append(next.descriptor)
                usedMeta.insert(next.candidate.metaUpgrades)
                covered.formUnion(next.descriptor.materialOpeningFamilies)
            }
        }
        while selected.count < limit, !representatives.isEmpty {
            var choice: Int?, best = -Double.infinity
            let requireStrongest = finalists && selected.count < strongestBandSeats
                && representatives.contains { $0.candidate.fitness.winRate == champion.fitness.winRate }
            let explorationFull = finalists && selected.filter { $0.fitness.winRate < champion.fitness.winRate }.count >= limit / 4
            for i in representatives.indices {
                let c = representatives[i]
                if explorationFull && c.candidate.fitness.winRate < champion.fitness.winRate { continue }
                if requireStrongest && c.candidate.fitness.winRate != champion.fitness.winRate { continue }
                // Modern creative finalists may share campaign upgrades. A
                // distinct-upgrade veto had excluded winning militia openings.
                if !finalists && distinctMetaSelections && usedMeta.contains(c.candidate.metaUpgrades) { continue }
                let novelty = selectedDescriptors.map { d in
                    let investment = GeneticPlaystyle.distance(d.investment, c.descriptor.investment)
                    let mechanics = GeneticPlaystyle.distance(d.mechanics, c.descriptor.mechanics)
                    let development = GeneticPlaystyle.distance(d.development, c.descriptor.development)
                    let spatial = GeneticPlaystyle.distance(d.spatial, c.descriptor.spatial)
                    let opening = GeneticPlaystyle.distance(d.opening, c.descriptor.opening)
                    return 0.5 * opening + 0.25 * investment + 0.15 * mechanics + 0.05 * development + 0.05 * spatial
                }.min() ?? 0
                if novelty > best { best = novelty; choice = i }
            }
            guard let choice else { break }
            let next = representatives.remove(at: choice)
            selected.append(next.candidate); selectedDescriptors.append(next.descriptor)
            usedMeta.insert(next.candidate.metaUpgrades)
        }
        // A finalist count is a cap, not an obligation to validate more copies
        // of the same observed behavior. Every original candidate remains saved.
        if finalists { return selected }
        // Fill working parent capacity with strongest evidence, never duplicate IDs.
        var used = Set(selected.map(\.id))
        for c in ranked where selected.count < limit {
            guard !used.contains(c.id), finalists || !distinctMetaSelections || !usedMeta.contains(c.metaUpgrades) else { continue }
            selected.append(c); used.insert(c.id); usedMeta.insert(c.metaUpgrades)
        }
        return selected
    }

    /// Schedule against the actual offspring count, not the total population:
    /// index 7 is never reached in the usual six-offspring meta subpopulation.
    public static func introducesFreshPlan(index: Int, offspringCount: Int, generation: Int) -> Bool {
        offspringCount > 0 && index == offspringCount - 1 && generation % 8 == 0
    }

    /// Let a new role improve through its own descendants instead of crossing
    /// it immediately back into the global champion's opening.
    public static func matingPool(for primary: GeneticCandidate, parents: [GeneticCandidate]) -> [GeneticCandidate] {
        guard let descriptor = primary.behaviorDescriptor else { return parents }
        // Local mating applies to every niche, even when the global champion
        // happens to contain all of its tower families.
        let matching = parents.filter {
            guard let other = $0.behaviorDescriptor else { return false }
            return GeneticPlaystyle.distance(descriptor.opening, other.opening) <= 0.25
                && GeneticPlaystyle.distance(descriptor.investment, other.investment) <= 0.25
        }
        return matching.isEmpty ? [primary] : matching
    }

}
