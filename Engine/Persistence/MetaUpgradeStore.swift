import Combine
import Foundation

/// Observable database snapshot. Each mutation commits through the DAO before
/// publishing; launch refresh continues to use exactly the bundled SQL seed.
@MainActor public final class MetaUpgradeStore: ObservableObject {
    @Published public private(set) var loadout: MetaUpgradeLoadout
    @Published public private(set) var bestStarsByLevel: [UUID: Int]
    private let dao: PlayerMetaUpgradeDAO

    public init(dao: PlayerMetaUpgradeDAO) throws {
        self.dao = dao
        let profiles = try dao.getAll()
        guard let active = profiles[.active] else {
            throw DbError.Db(message: "player_meta_upgrade_profile[active]: missing profile")
        }
        loadout = active.loadout
        bestStarsByLevel = active.bestStarsByLevel
    }
    public func reload() throws {
        let active = try dao.get()
        loadout = active.loadout
        bestStarsByLevel = active.bestStarsByLevel
    }
    @discardableResult public func purchase(_ upgrade: MetaUpgrade) throws -> Bool {
        let result = try dao.purchase(upgrade)
        try reload()
        return result
    }
    public func refund(_ upgrade: MetaUpgrade) throws { try dao.refund(upgrade); try reload() }
    public func reset() throws { try dao.reset(); try reload() }
    public func restoreLevel15() throws { try dao.restoreLevel15(); try reload() }
    @discardableResult public func recordVictory(levelID: UUID, lives: Int, startingLives: Int) throws -> Int {
        let earned = try dao.recordVictory(levelID: levelID, lives: lives, startingLives: startingLives)
        try reload()
        return earned
    }
}
