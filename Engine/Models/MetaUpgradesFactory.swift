import Foundation

/// Immutable upgrade DNA. Bit positions identify upgrades; spentStars is derived
/// from the DAO catalog when the factory validates the selection.
public struct MetaUpgradeProgression: Hashable, Sendable, Codable {
    public static let bitOrder: [MetaUpgrade] = [
        .rangeEstimation, .cartridgeDrill, .crossfire, .twoGoodVolleys,
        .campaignVeterans, .reliefCompanies, .fieldDressings, .bayonetCounterstroke,
        .gunCarriages, .thunderousReport, .ammunitionWagons, .batteryDoctrine,
        .forwardWorks, .preparedFireLanes, .workingParties, .powderWorks,
        .localSuppliers, .supplyConvoys, .forwardMagazines, .fieldHospitals,
        .artificerCorps, .modelCompany, .frenchContracts
    ]

    public let rawValue: UInt64
    public let spentStars: Int
    public var selected: Set<MetaUpgrade> {
        Set(Self.bitOrder.enumerated().compactMap { index, upgrade in
            rawValue & (UInt64(1) << index) == 0 ? nil : upgrade
        })
    }
    public var upgrades: [MetaUpgrade] { selected.sorted { $0.rawValue < $1.rawValue } }
    public var key: String { String(rawValue) }

    fileprivate init(loadout: MetaUpgradeLoadout) {
        rawValue = Self.bitOrder.enumerated().reduce(0) { bits, entry in
            loadout.selected.contains(entry.element) ? bits | (UInt64(1) << entry.offset) : bits
        }
        spentStars = loadout.spentStars
    }

    /// Wire records keep stable named IDs. Import requires the caller's DAO
    /// catalog; neither bit masks nor reported star totals bypass validation.
    public init(from decoder: Decoder) throws {
        guard let catalog = decoder.userInfo[MetaUpgradesFactory.catalogKey] as? MetaUpgradeCatalog else {
            throw DbError.Db(message: "meta upgrade progression: decoding requires a DAO catalog")
        }
        let upgrades = try decoder.singleValueContainer().decode([MetaUpgrade].self)
        self = try MetaUpgradesFactory.restore(upgrades, catalog: catalog)
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        try value.encode(upgrades)
    }
}

/// Configure once with the authored catalog, then make(stars:) produces a valid
/// chosen progression at that exact spend. The factory has no player profile or
/// earned-star ledger. Battle entry separately enforces the player's budget.
public final class MetaUpgradesFactory: Sendable {
    fileprivate static let catalogKey = CodingUserInfoKey(rawValue: "metaUpgradeCatalog")!
    public let catalog: MetaUpgradeCatalog
    public let progressions: [MetaUpgradeProgression]
    public let progressionsBySpentStars: [Int: [MetaUpgradeProgression]]

    public init(catalog: MetaUpgradeCatalog) throws {
        try Self.validateBitOrder()
        self.catalog = catalog
        let empty = try MetaUpgradeLoadout(catalog: catalog, starBudget: catalog.upgrades.reduce(0) { $0 + $1.cost })
        let upgrades = catalog.upgrades.map(\.id)
        var choices: [MetaUpgradeProgression] = []
        var groups: [Int: [MetaUpgradeProgression]] = [:]
        func visit(_ index: Int, _ loadout: MetaUpgradeLoadout) {
            guard index < upgrades.count else {
                let progression = MetaUpgradeProgression(loadout: loadout)
                choices.append(progression)
                groups[progression.spentStars, default: []].append(progression)
                return
            }
            visit(index + 1, loadout)
            var purchased = loadout
            if purchased.purchase(upgrades[index]) { visit(index + 1, purchased) }
        }
        // DAO validates and orders prerequisites before dependents; bit storage
        // order remains independent of SQL display order. No rules are duplicated.
        visit(0, empty)
        progressions = choices
        progressionsBySpentStars = groups
    }

    private static func validateBitOrder() throws {
        let order = MetaUpgradeProgression.bitOrder
        guard order.count <= UInt64.bitWidth, Set(order).count == order.count,
              Set(order) == Set(MetaUpgrade.allCases) else {
            throw DbError.Db(message: "meta upgrade progression: bitOrder must assign one stable bit to every upgrade within UInt64 capacity")
        }
    }

    fileprivate static func restore(_ upgrades: [MetaUpgrade], catalog: MetaUpgradeCatalog) throws -> MetaUpgradeProgression {
        try validateBitOrder()
        guard Set(upgrades).count == upgrades.count else {
            throw DbError.Db(message: "meta upgrade progression: duplicate upgrade ID")
        }
        let loadout = try MetaUpgradeLoadout(catalog: catalog,
            starBudget: catalog.upgrades.reduce(0) { $0 + $1.cost }, selected: Set(upgrades))
        return MetaUpgradeProgression(loadout: loadout)
    }

    public static func decoder(catalog: MetaUpgradeCatalog) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[catalogKey] = catalog
        return decoder
    }

    public func make(selected: Set<MetaUpgrade>) throws -> MetaUpgradeProgression {
        try Self.restore(Array(selected), catalog: catalog)
    }

    public func make(selected: [MetaUpgrade]) throws -> MetaUpgradeProgression {
        try Self.restore(selected, catalog: catalog)
    }

    /// Unknown bits fail rather than being silently discarded.
    public func make(rawValue: UInt64) throws -> MetaUpgradeProgression {
        let knownBits = MetaUpgradeProgression.bitOrder.indices.reduce(UInt64(0)) { $0 | (UInt64(1) << $1) }
        guard rawValue & ~knownBits == 0 else {
            throw DbError.Db(message: "meta upgrade progression: rawValue contains unknown upgrade bits")
        }
        let selected = MetaUpgradeProgression.bitOrder.enumerated().compactMap { index, upgrade in
            rawValue & (UInt64(1) << index) == 0 ? nil : upgrade
        }
        return try Self.restore(selected, catalog: catalog)
    }

    public func loadout(for progression: MetaUpgradeProgression, starBudget: Int? = nil) throws -> MetaUpgradeLoadout {
        let loadout = try MetaUpgradeLoadout(catalog: catalog,
            starBudget: starBudget ?? catalog.upgrades.reduce(0) { $0 + $1.cost }, selected: progression.selected)
        guard loadout.spentStars == progression.spentStars else {
            throw DbError.Db(message: "meta upgrade progression: spentStars differs from the DAO catalog")
        }
        return loadout
    }

    public func make(stars: Int) throws -> MetaUpgradeProgression {
        var rng = SystemRandomNumberGenerator()
        return try make(stars: stars, using: &rng)
    }

    /// Uniform over distinct legal choices at this spend. Exclusions let the GA
    /// seed diverse subpopulations without repeatedly drawing the same DNA.
    public func make<R: RandomNumberGenerator>(stars: Int, excluding: Set<MetaUpgradeProgression> = [],
        using rng: inout R) throws -> MetaUpgradeProgression {
        let choices = (progressionsBySpentStars[stars] ?? []).filter { !excluding.contains($0) }
        guard let choice = choices.randomElement(using: &rng) else {
            throw DbError.Db(message: "meta upgrade progression: no remaining legal selection spends \(stars) stars")
        }
        return choice
    }

    public static func nearest(to source: MetaUpgradeProgression, among choices: [MetaUpgradeProgression]) -> [MetaUpgradeProgression] {
        var nearest: [MetaUpgradeProgression] = [], minimum = Int.max
        for choice in choices {
            let distance = (choice.rawValue ^ source.rawValue).nonzeroBitCount
            guard distance > 0, distance <= minimum else { continue }
            if distance < minimum { minimum = distance; nearest.removeAll(keepingCapacity: true) }
            nearest.append(choice)
        }
        return nearest
    }

    /// Exchange explicit upgrades while preserving their total authored cost.
    /// With no alternative (including zero stars), keep the original selection.
    public func mutate<R: RandomNumberGenerator>(_ progression: MetaUpgradeProgression,
        excluding: Set<MetaUpgradeProgression> = [], using rng: inout R) throws -> MetaUpgradeProgression {
        _ = try loadout(for: progression)
        let choices = (progressionsBySpentStars[progression.spentStars] ?? []).filter { !excluding.contains($0) }
        if let result = Self.nearest(to: progression, among: choices).randomElement(using: &rng) { return result }
        guard !excluding.contains(progression) else {
            throw DbError.Db(message: "meta upgrade progression: no unvisited mutation at \(progression.spentStars) stars")
        }
        return progression
    }

    /// Mix parental bits, then choose a nearest legal selection at their exact
    /// cost using only upgrades present in the parents. Both parents are valid
    /// witnesses that at least one such selection exists.
    public func crossover<R: RandomNumberGenerator>(_ a: MetaUpgradeProgression, _ b: MetaUpgradeProgression,
        using rng: inout R) throws -> MetaUpgradeProgression {
        _ = try loadout(for: a); _ = try loadout(for: b)
        guard a.spentStars == b.spentStars else {
            throw DbError.Db(message: "meta upgrade progression: crossover parents must have the same star spend")
        }
        if a == b { return a }
        var desired: UInt64 = 0
        for index in MetaUpgradeProgression.bitOrder.indices {
            desired |= (Bool.random(using: &rng) ? a.rawValue : b.rawValue) & (UInt64(1) << index)
        }
        let union = a.rawValue | b.rawValue
        let choices = (progressionsBySpentStars[a.spentStars] ?? []).filter { $0.rawValue & ~union == 0 }
        var nearest: [MetaUpgradeProgression] = [], minimum = Int.max
        for choice in choices {
            let distance = (choice.rawValue ^ desired).nonzeroBitCount
            guard distance <= minimum else { continue }
            if distance < minimum { minimum = distance; nearest.removeAll(keepingCapacity: true) }
            nearest.append(choice)
        }
        guard let child = nearest.randomElement(using: &rng) else {
            throw DbError.Db(message: "meta upgrade progression: no legal crossover")
        }
        return child
    }
}
