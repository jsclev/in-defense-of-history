import Foundation
import SQLite3
import os

public class Db {
    private let logger = LogUtility.getLogger(LogCategory.Db, Db.self)

    let dbExtension = "sqlite"
    private(set) var conn: OpaquePointer?
    public let fullRefresh: Bool
    
    public let virtualCanvasDao: VirtualCanvasDAO
    public let campaignDao: CampaignDAO
    public let levelInfoDao: LevelInfoDAO
    public let levelLoader: LevelLoader
    public let pathDao: PathDAO
    public let enemyTypeDao: EnemyTypeDAO
    public let towerUnlockDao: TowerUnlockDAO
    public let meleeUnitDao: MeleeUnitDAO
    public let towerTypeDao: TowerTypeDAO
    public let combatRulesDao: CombatRulesDAO
    public let simBoundsDao: SimBoundsDAO
    public let simEnemyTypeDao: SimEnemyTypeDAO
    public let simMeleeUnitDao: SimMeleeUnitDAO
    public let simTowerSweepDao: SimTowerSweepDAO
    public let heroDao: HeroDAO
    public let levelGeoJSONDao: LevelGeoJSONDAO
    public let waveDao: WaveDAO
    public let difficultyDao: DifficultyDAO
    public let hudLayoutDao: HudLayoutDAO
    public let reinforcementConfigDao: ReinforcementConfigDAO
    public let encyclopediaDemoDao: EncyclopediaDemoDAO
    public let metaUpgradeDao: MetaUpgradeDAO
    public let playerMetaUpgradeDao: PlayerMetaUpgradeDAO
    public let playerSettingsDao: PlayerSettingsDAO
    public let simulatorRunDao: SimulatorRunDAO
    public let playSpeedDao: PlaySpeedDAO
    private let localLevelRunDao: LevelRunDAO
    private var runRecordingDatabase: Db?
    public var levelRunDao: LevelRunDAO {
        if let runRecordingDatabase { return runRecordingDatabase.levelRunDao }
        return localLevelRunDao
    }
    public func recordRuns(in database: Db) {
        precondition(database !== self)
        runRecordingDatabase = database
    }
    public let path: String
    
    public static var authoredDatabaseURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Db/in_defense_of_history.sqlite")
    }

    public static func getAbsolutePathToDb(dbFilename: String) -> String {
        let destination = FileUtil.getDocumentsURL().appendingPathComponent("\(dbFilename).sqlite")
        do {
            guard let source = Bundle.main.url(forResource: dbFilename, withExtension: "sqlite") else {
                throw DbError.Db(message: "Missing bundled database \(dbFilename).sqlite")
            }
            return try BundledDatabase.prepare(source: source, destination: destination).path
        } catch {
            fatalError("Unable to prepare the authored database: \(error)")
        }
    }
    
    public init(dbPath: String, fullRefresh: Bool, levelGeoJSONDao: LevelGeoJSONDAO = LevelGeoJSONDAO()) {
        self.path = dbPath
        var rc: Int32
        rc = sqlite3_open_v2(dbPath, &conn, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        
        if (rc != SQLITE_OK) {
            let sqliteMsg = String(cString: sqlite3_errmsg(conn))
            let errMsg = "Failed to open database connection to \(dbPath).  \(sqliteMsg)"
            fatalError("\(errMsg)")
        }

        // Independent simulator workers have separate connections. Let their
        // short DAO transactions take turns; never drop a recording on BUSY.
        guard sqlite3_busy_timeout(conn, 30_000) == SQLITE_OK else {
            fatalError("Unable to configure database lock wait for \(dbPath)")
        }
        
        let pragma = "PRAGMA foreign_keys=ON;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(conn, pragma, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
            }
            else {
                let errMsg = String(cString: sqlite3_errmsg(conn)!)
                fatalError("\(errMsg)")
            }
        }
        else {
            let errMsg = String(cString: sqlite3_errmsg(conn)!)
            fatalError("\(errMsg)")
        }
        
        if sqlite3_finalize(stmt) != SQLITE_OK {
            let errMsg = String(cString: sqlite3_errmsg(conn)!)
            fatalError("\(errMsg)")
        }
        
        self.fullRefresh = fullRefresh
        
        virtualCanvasDao = VirtualCanvasDAO(conn: conn)
        campaignDao = CampaignDAO(conn: conn)
        pathDao = PathDAO(conn: conn)
        waveDao = WaveDAO(conn: conn)
        levelInfoDao = LevelInfoDAO(conn: conn)
        self.levelGeoJSONDao = levelGeoJSONDao
        levelLoader = LevelLoader(info: levelInfoDao, paths: pathDao, waves: waveDao, geoJSON: levelGeoJSONDao)
        enemyTypeDao = EnemyTypeDAO(conn: conn)
        towerUnlockDao = TowerUnlockDAO(conn: conn)
        combatRulesDao = CombatRulesDAO(conn: conn)
        meleeUnitDao = MeleeUnitDAO(conn: conn, combatRulesDao: combatRulesDao)
        towerTypeDao = TowerTypeDAO(conn: conn, meleeUnitDao: meleeUnitDao, combatRulesDao: combatRulesDao)
        simBoundsDao = SimBoundsDAO(conn: conn)
        simEnemyTypeDao = SimEnemyTypeDAO(conn: conn)
        simMeleeUnitDao = SimMeleeUnitDAO(conn: conn)
        simTowerSweepDao = SimTowerSweepDAO(conn: conn)
        heroDao = HeroDAO(conn: conn)
        difficultyDao = DifficultyDAO(conn: conn)
        hudLayoutDao = HudLayoutDAO(conn: conn)
        reinforcementConfigDao = ReinforcementConfigDAO(conn: conn)
        encyclopediaDemoDao = EncyclopediaDemoDAO(conn: conn)
        playerSettingsDao = PlayerSettingsDAO(conn: conn)
        metaUpgradeDao = MetaUpgradeDAO(conn: conn)
        playerMetaUpgradeDao = PlayerMetaUpgradeDAO(conn: conn)
        simulatorRunDao = SimulatorRunDAO(conn: conn)
        playSpeedDao = PlaySpeedDAO(conn: conn)
        localLevelRunDao = LevelRunDAO(conn: conn)
    }

    public func close() {
        if let conn = conn {
            localLevelRunDao.close()
            let rc = sqlite3_close_v2(conn)
            if rc != SQLITE_OK {
                logger.error("sqlite3_close_v2 failed with code \(rc)")
            }
            self.conn = nil
        }
    }

    deinit {
        close()
    }
}
