import Foundation

/// Shared gameplay/balancing loader. Explicit GeoJSON routes and slots are authoritative.
public final class LevelLoader {
    private let info: LevelInfoDAO
    private let paths: PathDAO
    private let waves: WaveDAO
    private let geoJSON: LevelGeoJSONDAO

    init(info: LevelInfoDAO, paths: PathDAO, waves: WaveDAO, geoJSON: LevelGeoJSONDAO) {
        self.info = info
        self.paths = paths
        self.waves = waves
        self.geoJSON = geoJSON
    }

    public func load(id: UUID) throws -> LevelInfo {
        let record = try info.getBy(id: id)
        let authoredRoutes = try geoJSON.getEnemyRoutes(mapImageName: record.mapImageName)
        let loadedPaths = try authoredRoutes?.map(\.path) ?? paths.getPathsFor(levelInfoId: id)
        let loadedWaves = try waves.getWavesFor(levelInfoId: id)
        guard loadedWaves.allSatisfy({ $0.spawns.allSatisfy { loadedPaths.indices.contains($0.pathIndex) } }) else {
            throw DbError.Db(message: "Level waves reference a missing enemy route")
        }
        return try LevelInfo(id: record.id, name: record.name, campaign: record.campaign,
            startedAt: record.startedAt, endedAt: record.endedAt,
            startingMoney: record.startingMoney, numStartingLives: record.numStartingLives,
            numWaves: record.numWaves, playArea: record.playArea, mapImageName: record.mapImageName,
            paths: loadedPaths,
            towerSlots: geoJSON.getTowerSlots(mapImageName: record.mapImageName),
            waves: loadedWaves)
    }
}
