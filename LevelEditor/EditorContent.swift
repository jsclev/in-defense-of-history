import Foundation
import Combine

/// The editor's shared content, loaded once at launch and injected into
/// every view that needs it: the one database connection, the coordinate
/// system from virtual_canvas, and the tower stats the canvas draws with.
///
/// The editor draws range rings so a designer can see what a slot will cover,
/// and rejects slots that no tower could reach. Those are database numbers —
/// hardcoded copies drifted from the tower table before, so nothing here
/// falls back to invented values: if the database cannot be opened the rings
/// simply do not draw and `virtualCanvas` is nil, and the app decides
/// whether that is fatal.
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
            arsenal = try db.towerTypeDao.getDesignArsenal()
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
        guard let db, let byCategory = try? db.towerTypeDao.getTowerTypes() else {
            ringsByName = []
            maxTowerRange = nil
            return
        }
        ringsByName = byCategory.values
            .compactMap { type in
                guard let first = type.levels.first, first.range > 0 else { return nil }
                return (type.name, first.range)
            }
            .sorted { $0.range < $1.range }
        maxTowerRange = byCategory.values
            .flatMap { $0.levels.map(\.range) }
            .max()
    }
}
