import Foundation

final class SimulatorStore {
    let db: Db
    let virtualCanvas: VirtualCanvas
    let roster: DesignRoster
    let arsenal: DesignArsenal
    let blueprints: Blueprints

    /// Sweep progress lives in its own database; a failure to open it must
    /// not keep the simulator from running, so it is optional.
    let runs: SimulatorRunDAO?

    init() throws {
        db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                fullRefresh: false)
        virtualCanvas = try db.virtualCanvasDao.get()
        roster = DesignRoster()
        arsenal = DesignArsenal()
        blueprints = Blueprints(virtualCanvas: virtualCanvas)
        runs = try? SimulatorRunDAO()
    }
}
