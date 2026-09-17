import Foundation
import Combine

@MainActor
final class EditorContent: ObservableObject {
    let db: Db?
    let virtualCanvas: VirtualCanvas?
    @Published private(set) var enemyTypes: [EnemyType] = []
    @Published private(set) var enemyRosterError: String?
    @Published private(set) var arsenal: DesignArsenal?
    @Published private(set) var towerTextError: String?

    /// Display name and range for each tower kind's first tier, for the range
    /// rings. Empty when the database is unavailable.
    @Published private(set) var ringsByName: [(name: String, range: Double)] = []

    /// The longest range any tower can reach, used to flag a slot that no tower
    /// could cover. Nil when unknown, and callers skip the check rather than
    /// guessing.
    @Published private(set) var maxTowerRange: Double?

    init() {
        #if os(iOS)
        let refreshFromBundle = true
        let path = Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history")
        #else
        let refreshFromBundle = false
        let path = Db.authoredDatabaseURL.path
        #endif
        guard FileManager.default.fileExists(atPath: path) else {
            db = nil
            virtualCanvas = nil
            return
        }
        let db = Db(dbPath: path, fullRefresh: refreshFromBundle)
        self.db = db
        virtualCanvas = try? db.virtualCanvasDao.get()
        reload()
    }

    func reload() {
        do {
            guard let db else {
                throw DbError.Db(message: "The authored tower database is unavailable.")
            }
            let loaded = try db.towerTypeDao.getDesignArsenal()
            arsenal = loaded
            ringsByName = loaded.rangeRings
            maxTowerRange = loaded.maximumRange
            towerTextError = nil
        } catch {
            fatalError("Invalid authored tower data: \(error)")
        }
        do {
            guard let db else {
                throw DbError.Db(message: "The authored enemy database is unavailable.")
            }
            enemyTypes = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).enemyTypes
            enemyRosterError = nil
        } catch {
            enemyTypes = []
            enemyRosterError = String(describing: error)
        }
    }
}
