import Foundation

/// Stable behavior identifiers only. SQLite owns presentation, progression and tuning.
public enum MetaUpgradeTrack: String, CaseIterable, Identifiable, Sendable {
    case marksmanship, infantry, artillery, engineering, supply, command
    public var id: String { rawValue }
}
public enum MetaUpgrade: String, Codable, CaseIterable, Identifiable, Sendable {
    case rangeEstimation, cartridgeDrill, crossfire, twoGoodVolleys
    case campaignVeterans, reliefCompanies, fieldDressings, bayonetCounterstroke
    case gunCarriages, thunderousReport, ammunitionWagons, batteryDoctrine
    case forwardWorks, preparedFireLanes, workingParties, powderWorks
    case localSuppliers, supplyConvoys, forwardMagazines, fieldHospitals
    case artificerCorps, modelCompany, frenchContracts
    public var id: String { rawValue }
    var requiredParameters: Set<MetaUpgradeParameter> {
        switch self {
        case .rangeEstimation: return [.rangeMultiplier]
        case .cartridgeDrill, .ammunitionWagons: return [.reloadMultiplier]
        case .crossfire, .preparedFireLanes: return [.damageMultiplier]
        case .twoGoodVolleys: return [.damageMultiplier, .shotCount, .preparationSeconds]
        case .campaignVeterans: return [.healthMultiplier]
        case .reliefCompanies: return [.respawnMultiplier]
        case .fieldDressings: return [.healingMultiplier]
        case .bayonetCounterstroke: return [.damageMultiplier, .moraleThreshold]
        case .gunCarriages: return [.turnMultiplier]
        case .thunderousReport: return [.moraleMultiplier]
        case .batteryDoctrine: return [.secondaryHitMultiplier, .closeRangeMultiplier, .closeRangeFraction, .coverPierceFraction]
        case .forwardWorks: return [.rangeMultiplier, .obstacleSizeMultiplier]
        case .workingParties: return [.preparationMultiplier]
        case .powderWorks: return [.damageMultiplier, .moraleMultiplier]
        case .forwardMagazines: return [.priceMultiplier, .serviceRange]
        case .localSuppliers, .artificerCorps, .modelCompany, .frenchContracts: return [.priceMultiplier]
        case .supplyConvoys: return [.incomeMultiplier]
        case .fieldHospitals: return [.healingMultiplier, .rangeMultiplier]
        }
    }
}
public enum MetaUpgradeParameter: String, CaseIterable, Sendable {
    case rangeMultiplier, reloadMultiplier, damageMultiplier, shotCount, preparationSeconds
    case healthMultiplier, respawnMultiplier, healingMultiplier, moraleThreshold, turnMultiplier
    case moraleMultiplier, secondaryHitMultiplier, closeRangeMultiplier, closeRangeFraction, coverPierceFraction
    case obstacleSizeMultiplier, preparationMultiplier, priceMultiplier, incomeMultiplier, serviceRange
    func accepts(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        switch self {
        case .shotCount: return value.rounded() == value && (1...10).contains(value)
        case .preparationSeconds: return value > 0 && value <= 120
        case .serviceRange: return value > 0 && value <= 10000
        case .reloadMultiplier, .respawnMultiplier, .preparationMultiplier, .priceMultiplier:
            return value > 0 && value < 1
        case .moraleThreshold, .closeRangeFraction, .coverPierceFraction: return value > 0 && value < 1
        default: return value > 1 && value <= 5
        }
    }
}
public struct MetaUpgradeTrackDefinition: Equatable, Identifiable, Sendable {
    public let id: MetaUpgradeTrack
    public let title: String
    public let shortTitle: String
    public let order: Int
}
public struct MetaUpgradeDefinition: Equatable, Identifiable, Sendable {
    public let id: MetaUpgrade
    public let track: MetaUpgradeTrack
    public let tier: Int
    public let cost: Int
    public let prerequisite: MetaUpgrade?
    public let title: String
    public let detail: String
    public let iconAssetName: String
    public let historicalInformation: String
    public let sourceTitle: String
    public let sourceURL: URL
    public let parameters: [MetaUpgradeParameter: Double]
    public func value(_ parameter: MetaUpgradeParameter) -> Double {
        guard let value = parameters[parameter] else {
            fatalError("meta_upgrade_effect[\(id.rawValue):\(parameter.rawValue)]: missing value")
        }
        return value
    }
}
public struct MetaUpgradeCatalog: Equatable, Sendable {
    public let tracks: [MetaUpgradeTrackDefinition]
    public let upgrades: [MetaUpgradeDefinition]
    public subscript(_ id: MetaUpgrade) -> MetaUpgradeDefinition {
        guard let row = upgrades.first(where: { $0.id == id }) else {
            fatalError("meta_upgrade[\(id.rawValue)]: missing record")
        }
        return row
    }
    public subscript(_ id: MetaUpgradeTrack) -> MetaUpgradeTrackDefinition {
        guard let row = tracks.first(where: { $0.id == id }) else {
            fatalError("meta_upgrade_track[\(id.rawValue)]: missing record")
        }
        return row
    }
    public func upgrades(in track: MetaUpgradeTrack) -> [MetaUpgradeDefinition] { upgrades.filter { $0.track == track } }
}
public enum MetaUpgradeAvailability: Equatable, Sendable {
    case selected, available, prerequisite(MetaUpgrade), insufficientStars
}
public struct MetaUpgradeLoadout: Equatable, Sendable {
    public let catalog: MetaUpgradeCatalog
    public let starBudget: Int
    public private(set) var selected: Set<MetaUpgrade>
    public init(catalog: MetaUpgradeCatalog, starBudget: Int, selected: Set<MetaUpgrade> = []) throws {
        guard starBudget >= 0, selected.reduce(0, { $0 + catalog[$1].cost }) <= starBudget,
              selected.allSatisfy({ catalog[$0].prerequisite.map(selected.contains) ?? true }) else {
            throw DbError.Db(message: "Invalid meta upgrade budget or prerequisite selection")
        }
        self.catalog = catalog; self.starBudget = starBudget; self.selected = selected
    }
    public var spentStars: Int { selected.reduce(0) { $0 + catalog[$1].cost } }
    public var availableStars: Int { starBudget - spentStars }
    public func availability(of upgrade: MetaUpgrade) -> MetaUpgradeAvailability {
        if selected.contains(upgrade) { return .selected }
        if let prerequisite = catalog[upgrade].prerequisite, !selected.contains(prerequisite) { return .prerequisite(prerequisite) }
        return availableStars >= catalog[upgrade].cost ? .available : .insufficientStars
    }
    @discardableResult public mutating func purchase(_ upgrade: MetaUpgrade) -> Bool {
        guard availability(of: upgrade) == .available else { return false }
        selected.insert(upgrade); return true
    }
    public func refunding(_ upgrade: MetaUpgrade) -> Set<MetaUpgrade> {
        guard selected.contains(upgrade) else { return [] }
        var removed: Set<MetaUpgrade> = [upgrade], previousCount = 0
        while previousCount != removed.count {
            previousCount = removed.count
            for id in selected where catalog[id].prerequisite.map(removed.contains) == true { removed.insert(id) }
        }
        return removed
    }
    public mutating func refund(_ upgrade: MetaUpgrade) { selected.subtract(refunding(upgrade)) }
    public mutating func reset() { selected.removeAll() }
    public var effects: MetaUpgradeEffects { MetaUpgradeEffects(catalog: catalog, selected: selected) }
}
/// Immutable battle-entry snapshot. Empty effects are an explicit disabled loadout, never missing-content recovery.
public struct MetaUpgradeEffects: Equatable, Sendable {
    private let definitions: [MetaUpgrade: MetaUpgradeDefinition]
    public var selected: Set<MetaUpgrade> { Set(definitions.keys) }
    public init(catalog: MetaUpgradeCatalog, selected: Set<MetaUpgrade>) {
        definitions = Dictionary(uniqueKeysWithValues: selected.map { ($0, catalog[$0]) })
    }
    private init() { definitions = [:] }
    public static let none = Self()
    public func value(_ upgrade: MetaUpgrade, _ parameter: MetaUpgradeParameter) -> Double? {
        definitions[upgrade].map { $0.value(parameter) }
    }
    public func priced(_ base: TowerLevel, kind: TowerKind, level: Int,
                       context: MetaUpgradePriceContext = .initial) -> TowerLevel {
        var result = base
        var multiplier = 1.0
        if kind == .supply, let v = value(.localSuppliers, .priceMultiplier) { multiplier *= v }
        if level == 1, let v = value(.artificerCorps, .priceMultiplier) { multiplier *= v }
        if (2...3).contains(level), context.trainingEstablished, let v = value(.modelCompany, .priceMultiplier) { multiplier *= v }
        if level == 4, context.firstSpecializationAvailable, let v = value(.frenchContracts, .priceMultiplier) { multiplier *= v }
        if level > 1, context.servedByMagazine, let v = value(.forwardMagazines, .priceMultiplier) { multiplier *= v }
        result.cost = Int(ceil(Double(base.cost) * multiplier - 1e-9))
        return result
    }
    public func combat(_ base: TowerLevel, kind: TowerKind) -> TowerLevel {
        var t = base
        if kind == .ranged {
            if let v = value(.rangeEstimation, .rangeMultiplier) { t.range *= v }
            if let v = value(.cartridgeDrill, .reloadMultiplier) { t.fireInterval *= v }
        }
        if kind == .melee, var m = t.meleeUnit {
            if let v = value(.campaignVeterans, .healthMultiplier) { m.hp *= v }
            if let v = value(.reliefCompanies, .respawnMultiplier) { m.respawnSeconds *= v }
            if let v = value(.fieldDressings, .healingMultiplier) { m.healPerSecond *= v }
            t.meleeUnit = m
        }
        if kind == .areaOfEffect {
            if let v = value(.gunCarriages, .turnMultiplier) { t.turnRateDegrees *= v }
            if let v = value(.thunderousReport, .moraleMultiplier) { t.terrorMin *= v; t.terrorMax *= v }
            if let v = value(.ammunitionWagons, .reloadMultiplier) { t.fireInterval *= v }
            if t.attackMode == .shell, let v = value(.batteryDoctrine, .coverPierceFraction) { t.splashCoverPierce += (1 - t.splashCoverPierce) * v }
        }
        if kind == .special {
            if let v = value(.forwardWorks, .rangeMultiplier) { t.range *= v }
            if let v = value(.forwardWorks, .obstacleSizeMultiplier) { t.engineerObstacles?.radius *= v }
            if let s = t.demolitionPreparationSeconds, let v = value(.workingParties, .preparationMultiplier) { t.demolitionPreparationSeconds = s * v }
            if t.attackMode == .demolition {
                if let v = value(.powderWorks, .damageMultiplier) { t.shotMinDamage *= v; t.shotMaxDamage *= v }
                if let v = value(.powderWorks, .moraleMultiplier) { t.terrorMin *= v; t.terrorMax *= v }
            }
        }
        if kind == .supply {
            // The doctrine establishes a service area even for income-only carts.
            if let v = value(.forwardMagazines, .serviceRange) { t.range = max(t.range, v) }
            if let v = value(.supplyConvoys, .incomeMultiplier) { t.support.incomePerWave = Int((Double(t.support.incomePerWave) * v).rounded(.down)) }
            if t.support.healPerSecond > 0 {
                if let v = value(.fieldHospitals, .healingMultiplier) { t.support.healPerSecond *= v }
                if let v = value(.fieldHospitals, .rangeMultiplier) { t.range *= v }
            }
        }
        return t
    }
    public func rangedDamageMultiplier(kind: TowerKind, blocked: Bool, prepared: Bool) -> Double {
        guard kind == .ranged else { return 1 }
        var result = 1.0
        if blocked, let v = value(.crossfire, .damageMultiplier) { result *= v }
        if prepared, let v = value(.twoGoodVolleys, .damageMultiplier) { result *= v }
        return result
    }
    public func fireLaneMultiplier(kind: TowerKind, inAbatis: Bool) -> Double {
        guard inAbatis, kind == .ranged || kind == .areaOfEffect else { return 1 }
        return value(.preparedFireLanes, .damageMultiplier) ?? 1
    }
    public func meleeDamageMultiplier(moraleFraction: Double) -> Double {
        guard let threshold = value(.bayonetCounterstroke, .moraleThreshold), moraleFraction < threshold else { return 1 }
        return definitions[.bayonetCounterstroke]!.value(.damageMultiplier)
    }
    public func batteryDamageMultiplier(mode: TowerAttackMode, priorHits: Int, distanceFraction: Double) -> Double {
        guard let doctrine = definitions[.batteryDoctrine] else { return 1 }
        if mode == .solidShot, priorHits > 0 { return doctrine.value(.secondaryHitMultiplier) }
        if mode == .grapeshot, distanceFraction <= doctrine.value(.closeRangeFraction) { return doctrine.value(.closeRangeMultiplier) }
        return 1
    }
}
public struct MetaUpgradePriceContext: Equatable, Sendable {
    public let trainingEstablished: Bool
    public let firstSpecializationAvailable: Bool
    public let servedByMagazine: Bool
    public static let initial = Self(trainingEstablished: false, firstSpecializationAvailable: true, servedByMagazine: false)
}
/// Purchase history survives selling/rebuilding and is discarded with the battle.
public struct MetaUpgradeBattleProgress: Equatable, Sendable {
    private var trainedTiers: [TowerKind: Set<Int>] = [:]
    public private(set) var hasSpecialization = false
    public init() {}
    public mutating func recordPurchase(kind: TowerKind, level: Int) {
        if (2...3).contains(level) { trainedTiers[kind, default: []].insert(level) }
        if level == 4 { hasSpecialization = true }
    }
    public func context(kind: TowerKind, level: Int, servedByMagazine: Bool) -> MetaUpgradePriceContext {
        .init(trainingEstablished: trainedTiers[kind]?.contains(level) == true,
              firstSpecializationAvailable: !hasSpecialization, servedByMagazine: servedByMagazine)
    }
}
/// Preparation uses game time. Tier upgrades keep this state; pauses and retargeting cannot replenish shots.
public struct PreparedMetaVolley: Equatable, Sendable, Codable {
    public private(set) var shotsRemaining: Int
    private var quietSeconds = 0.0
    private let shotCount: Int
    private let preparationSeconds: Double
    public init?(effects: MetaUpgradeEffects) {
        guard let count = effects.value(.twoGoodVolleys, .shotCount), let seconds = effects.value(.twoGoodVolleys, .preparationSeconds) else { return nil }
        shotCount = Int(count); preparationSeconds = seconds; shotsRemaining = Int(count)
    }
    public mutating func advance(seconds: Double, hasTarget: Bool) {
        guard seconds.isFinite, seconds > 0 else { return }
        if hasTarget { quietSeconds = 0 }
        else {
            quietSeconds = min(preparationSeconds, quietSeconds + seconds)
            if quietSeconds >= preparationSeconds { shotsRemaining = shotCount }
        }
    }
    @discardableResult public mutating func fire() -> Bool {
        quietSeconds = 0
        guard shotsRemaining > 0 else { return false }
        shotsRemaining -= 1; return true
    }
}
