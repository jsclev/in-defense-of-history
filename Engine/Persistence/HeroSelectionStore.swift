import Foundation

/// Restores the player's choices after the bundled content database is refreshed.
/// Preferences and database rows always contain the same primary-first IDs.
public final class HeroSelectionStore {
    public static let key = "selectedHeroIDs"
    private let dao: HeroDAO
    private let defaults: UserDefaults

    public init(dao: HeroDAO, defaults: UserDefaults = .standard) {
        self.dao = dao
        self.defaults = defaults
    }

    @discardableResult
    public func load() throws -> HeroSelection {
        let roster = try dao.getAll()
        func resolve(_ ids: [UUID]) -> [Hero] {
            var seen = Set<UUID>()
            return Array(ids.compactMap { id -> Hero? in
                guard seen.insert(id).inserted else { return nil }
                return roster.first { $0.id == id }
            }.prefix(HeroSelection.maxSelected))
        }
        let saved = (defaults.string(forKey: Self.key) ?? "")
            .split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        var heroes = resolve(saved)
        if heroes.isEmpty { heroes = resolve(try dao.getSelectedHeroIds()) }
        if heroes.isEmpty, let first = roster.first(where: \.unlocked) { heroes = [first] }
        return try save(HeroSelection(heroes: heroes))
    }

    @discardableResult
    public func save(_ selection: HeroSelection) throws -> HeroSelection {
        try dao.setSelectedHeroes(selection.ids)
        let persisted = try dao.getSelectedHeroes()
        defaults.set(persisted.ids.map(\.uuidString).joined(separator: ","), forKey: Self.key)
        return persisted
    }

    @discardableResult
    public func toggle(_ hero: Hero) throws -> HeroSelection {
        try save(load().toggling(hero))
    }
}
