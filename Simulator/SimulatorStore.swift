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
        // The command-line target has no resource bundle. Read the authoritative
        // exports from the checkout, or an explicitly configured GeoJSON directory.
        let levelDirectory = ProcessInfo.processInfo.environment["LIBERTY_LINE_GEOJSON_DIRECTORY"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("Db", isDirectory: true)
        db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                fullRefresh: false, levelGeoJSONDao: LevelGeoJSONDAO(directory: levelDirectory))
        virtualCanvas = try db.virtualCanvasDao.get()
        roster = DesignRoster()
        arsenal = DesignArsenal()
        blueprints = Blueprints(virtualCanvas: virtualCanvas)
        runs = try? SimulatorRunDAO()
    }
}
