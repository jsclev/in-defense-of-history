import Foundation

final class SimulatorStore {
    let db: Db
    init() throws {
        // The command-line target has no resource bundle. Read the authoritative
        // exports from the checkout, or an explicitly configured GeoJSON directory.
        let levelDirectory = ProcessInfo.processInfo.environment["LIBERTY_LINE_GEOJSON_DIRECTORY"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("Db", isDirectory: true)
        let databaseURL = Db.authoredDatabaseURL
        db = Db(dbPath: databaseURL.path,
                fullRefresh: false, levelGeoJSONDao: LevelGeoJSONDAO(directory: levelDirectory))
    }
}
