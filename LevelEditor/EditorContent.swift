import Foundation
import Combine

/// Tower stats the map-design view needs, read from the database.
///
/// The editor draws range rings so a designer can see what a slot will cover,
/// and rejects slots that no tower could reach. Those are database numbers: the
/// editor had its own hardcoded copies (`210`/`240` rings labelled with tower
/// names, and a flat `maxTowerRange` of 350) which had already drifted from the
/// `tower` table's real 150–300.
///
/// Loaded once and shared. If the database cannot be opened the rings simply do
/// not draw, rather than falling back to invented numbers — a fallback constant
/// is the hardcoded value again.
@MainActor
final class EditorContent: ObservableObject {
    static let shared = EditorContent()

    /// Display name and range for each tower kind's first tier, for the range
    /// rings. Empty when the database is unavailable.
    @Published private(set) var ringsByName: [(name: String, range: Double)] = []

    /// The longest range any tower can reach, used to flag a slot that no tower
    /// could cover. Nil when unknown, and callers skip the check rather than
    /// guessing.
    @Published private(set) var maxTowerRange: Double?

    private init() { reload() }

    func reload() {
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
            ringsByName = []
            maxTowerRange = nil
            return
        }
        let db = Db(dbPath: path, fullRefresh: refreshFromBundle)
        guard let byCategory = try? db.towerTypeDao.getTowerTypes() else {
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
