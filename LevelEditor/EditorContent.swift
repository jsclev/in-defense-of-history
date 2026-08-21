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

    /// Display name and range for each tower kind's first tier, for the range
    /// rings. Empty when the database is unavailable.
    @Published private(set) var ringsByName: [(name: String, range: Double)] = []

    /// The longest range any tower can reach, used to flag a slot that no tower
    /// could cover. Nil when unknown, and callers skip the check rather than
    /// guessing.
    @Published private(set) var maxTowerRange: Double?

    init() {
        // On the Mac this resolves to ~/Documents/in_defense_of_history.sqlite,
        // which Db/create_db.sh maintains — never overwrite it with the copy
        // baked into the app at build time. On iPad the sandbox copy has no
        // maintainer, so refresh it from the bundle every launch the way the
        // game does; keeping a stale copy is how an old schema crashed the
        // virtual_canvas load at startup.
        #if os(iOS)
        let refreshFromBundle = true
        #else
        let refreshFromBundle = false
        #endif
        let path = Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history",
                                          fullRefresh: refreshFromBundle)
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
