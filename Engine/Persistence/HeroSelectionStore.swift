import Foundation

/// Hero choices come only from the current database. A content refresh replaces
/// them with the authored selection; no preferences restore an older lineup.
public final class HeroSelectionStore {
    private let dao: HeroDAO

    public init(dao: HeroDAO) {
        self.dao = dao
    }

    @discardableResult
    public func load() throws -> HeroSelection {
        try dao.getSelectedHeroes()
    }

    @discardableResult
    public func save(_ selection: HeroSelection) throws -> HeroSelection {
        try dao.setSelectedHeroes(selection.ids)
        return try dao.getSelectedHeroes()
    }

    @discardableResult
    public func toggle(_ hero: Hero) throws -> HeroSelection {
        try save(load().toggling(hero))
    }
}
