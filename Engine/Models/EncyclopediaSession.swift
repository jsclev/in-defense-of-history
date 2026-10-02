import Foundation

/// One visit, created by the menu action before the encyclopedia is presented.
/// Replacing its identity also resets all descendant browsing and playback state.
@MainActor
final class EncyclopediaSession: Identifiable {
    enum Category {
        case towers, enemies
    }

    let id = UUID()
    let initialCategory: Category?
    let arsenal: DesignArsenal
    let demonstrations: TowerDemonstrationCatalog
    let enemies: [EnemyEncyclopediaEntry]
    let enemyDemonstrations: EnemyDemonstrationCatalog

    init(db: Db, initialCategory: Category? = nil) throws {
        self.initialCategory = initialCategory
        arsenal = try db.towerTypeDao.getDesignArsenal()
        enemies = try db.enemyTypeDao.getEncyclopedia()
        demonstrations = TowerDemonstrationCatalog(db: db)
        enemyDemonstrations = EnemyDemonstrationCatalog(db: db)
    }
}
