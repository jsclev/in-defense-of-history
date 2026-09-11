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
    public let primary: Hero
    public let secondary: Hero?

    public var heroes: [Hero] { [primary] + (secondary.map { [$0] } ?? []) }
    public var ids: [UUID] { heroes.map(\.id) }

    public init(heroes: [Hero]) throws {
        guard (1...Self.maxSelected).contains(heroes.count) else {
            throw SelectionError.invalidCount
        }
        guard Set(heroes.map(\.id)).count == heroes.count else {
            throw SelectionError.duplicateHero
        }
        let ordered = heroes.sorted(by: Self.precedes)
        primary = ordered[0]
        secondary = ordered.count == 2 ? ordered[1] : nil
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
