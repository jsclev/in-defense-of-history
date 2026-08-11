import Foundation
import SQLite3
import os

public class Db {
    private let logger = LogUtility.getLogger(LogCategory.Db, Db.self)

    let dbExtension = "sqlite"
    private var conn: OpaquePointer?
    public let fullRefresh: Bool
    
    public let campaignDao: CampaignDAO
    public let levelInfoDao: LevelInfoDAO
    public let towerSlotDao: TowerSlotDAO
    public let pathDao: PathDAO
    public let enemyTypeDao: EnemyTypeDAO
    public let towerUnlockDao: TowerUnlockDAO
    public let towerTypeDao: TowerTypeDAO
    public let simBoundsDao: SimBoundsDAO
    public let simEnemyTypeDao: SimEnemyTypeDAO
    public let simMeleeUnitDao: SimMeleeUnitDAO
    public let heroDao: HeroDAO
    public let waveDao: WaveDAO
    public let difficultyDao: DifficultyDAO
    
    public static func getAbsolutePathToDb(dbFilename: String, fullRefresh: Bool) -> String {
        let logger = LogUtility.getLogger(LogCategory.Db, Db.self)
        let dbExtension = "sqlite"
        let fileManager = FileManager.default
        let documentsDirectory = FileUtil.getDocumentsURL()
        
        if let dbBundleUrl = Bundle.main.url(forResource: dbFilename, withExtension: dbExtension) {
            let targetDbPath = documentsDirectory.appendingPathComponent("\(dbFilename).\(dbExtension)").path

            if fullRefresh {
                do {
                    if fileManager.fileExists(atPath: targetDbPath) {
                        do {
                            try fileManager.removeItem(atPath: targetDbPath)
                        }
                        catch let error {
                            logger.error("error occurred, here are the details: \(error)")
                        }
                    }
                    
                    try fileManager.copyItem(atPath: dbBundleUrl.path, toPath: targetDbPath)
                }
                catch {
                    logger.error("Unable to copy \(dbFilename).\(dbExtension): \(error)")
                }
            } else {
                if !fileManager.fileExists(atPath: targetDbPath) {
                    do {
                        try fileManager.copyItem(atPath: dbBundleUrl.path, toPath: targetDbPath)
                    }
                    catch let error {
                        logger.error("error occurred, here are the details: \(error)")
                    }
                }
            }
        }
        else {
            logger.warning("Unable to find the database file inside the bundle.")
        }
        
        #if os(tvOS)
        #else
            let docDirUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        #endif
        
        if docDirUrls.count == 0 {
            logger.error("Unable to find the \"Documents\" directory.")
        }
        
        let documentsUrl = docDirUrls[0]
        let dbPath = documentsUrl.appendingPathComponent("\(dbFilename).\(dbExtension)").path
        
        return dbPath
    }
    
    public init(dbPath: String, fullRefresh: Bool) {
        var rc: Int32
        rc = sqlite3_open_v2(dbPath, &conn, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        
        if (rc != SQLITE_OK) {
            let sqliteMsg = String(cString: sqlite3_errmsg(conn))
            let errMsg = "Failed to open database connection to \(dbPath).  \(sqliteMsg)"
            fatalError("\(errMsg)")
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
        
        campaignDao = CampaignDAO(conn: conn)
        towerSlotDao = TowerSlotDAO(conn: conn)
        pathDao = PathDAO(conn: conn)
        waveDao = WaveDAO(conn: conn)
        levelInfoDao = LevelInfoDAO(conn: conn, towerSlotDao: towerSlotDao,
                                    pathDao: pathDao, waveDao: waveDao)
        enemyTypeDao = EnemyTypeDAO(conn: conn)
        towerUnlockDao = TowerUnlockDAO(conn: conn)
        towerTypeDao = TowerTypeDAO(conn: conn)
        simBoundsDao = SimBoundsDAO(conn: conn)
        simEnemyTypeDao = SimEnemyTypeDAO(conn: conn)
        simMeleeUnitDao = SimMeleeUnitDAO(conn: conn)
        heroDao = HeroDAO(conn: conn)
        difficultyDao = DifficultyDAO(conn: conn)
    }

    public func close() {
        if let conn = conn {
            sqlite3_close(conn)
        }
    }
}
