import Foundation

/// The simulator's one set of shared objects, built once in main.swift and
/// handed to everything that needs them — the CLI counterpart of the game's
/// Store. Nothing else opens the content database or loads the canvas spec.
final class SimulatorStore {
    let db: Db
    let canvasSpec: CanvasSpec
    let roster: DesignRoster
    let arsenal: DesignArsenal
    let blueprints: Blueprints

    /// Sweep progress lives in its own database; a failure to open it must
    /// not keep the simulator from running, so it is optional.
    let runs: SimulatorRunDAO?

    init() throws {
        db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                fullRefresh: false)
        canvasSpec = try db.canvasSpecDao.get()
        roster = DesignRoster()
        arsenal = DesignArsenal()
        blueprints = Blueprints(canvasSpec: canvasSpec)
        runs = try? SimulatorRunDAO()
    }
}
