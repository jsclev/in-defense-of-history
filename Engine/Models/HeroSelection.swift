import Foundation

/// One or two chosen heroes. Roles are derived from ranking, never click order.
public struct HeroSelection: Sendable, Equatable {
    public enum Role: String, Codable, CaseIterable, Sendable {
        case primary
        case secondary

        public var title: String { self == .primary ? "Primary hero" : "Secondary hero" }
    }

    public enum SelectionError: Error, LocalizedError {
        case invalidCount
        case duplicateHero
        case unknownHero
        case lockedHero

        public var errorDescription: String? {
            switch self {
            case .invalidCount: return "Choose one or two heroes."
            case .duplicateHero: return "Choose two different heroes."
            case .unknownHero: return "A chosen hero is no longer in the roster."
            case .lockedHero: return "Unlock this hero before choosing them."
            }
        }
    }

    public static let maxSelected = 2
    // Keep one immutable, ranked selection. Reconstructing this array from
    // separate role fields copied the full hero content on every HUD capture.
    public let heroes: [Hero]
    public var primary: Hero { heroes[0] }
    public var secondary: Hero? { heroes.count == 2 ? heroes[1] : nil }

    public var ids: [UUID] { heroes.map(\.id) }

    public init(heroes: [Hero]) throws {
        guard (1...Self.maxSelected).contains(heroes.count) else {
            throw SelectionError.invalidCount
        }
        guard Set(heroes.map(\.id)).count == heroes.count else {
            throw SelectionError.duplicateHero
        }
        self.heroes = heroes.sorted(by: Self.precedes)
    }

    /// Equal rankings use UUID order to keep roles stable across saves and reloads.
    public static func precedes(_ lhs: Hero, _ rhs: Hero) -> Bool {
        if lhs.ranking != rhs.ranking { return lhs.ranking > rhs.ranking }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    public func role(for heroID: UUID) -> Role? {
        if primary.id == heroID { return .primary }
        if secondary?.id == heroID { return .secondary }
        return nil
    }

    /// A lone hero stays chosen. A third choice replaces the current secondary.
    public func toggling(_ hero: Hero) throws -> HeroSelection {
        if role(for: hero.id) != nil {
            guard secondary != nil else { return self }
            return try HeroSelection(heroes: heroes.filter { $0.id != hero.id })
        }
        guard hero.unlocked else { throw SelectionError.lockedHero }
        return try HeroSelection(heroes: [primary, hero])
    }
}
