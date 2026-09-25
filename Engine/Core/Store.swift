import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class Store {
    public let virtualCanvas: VirtualCanvas
    public let db: Db
    public let towerMenuLayout: TowerMenuLayout
    public let metaUpgrades: MetaUpgradeStore
    public let settings: PlayerSettingsStore
    public let hudLayoutConfig: HudLayoutConfig

    public init() {
        do {
            if let domain = Bundle.main.bundleIdentifier {
                BundledDatabase.discardLegacyPreferences(domain: domain)
            }
            #if targetEnvironment(macCatalyst)
            // Every desktop launch starts from the authoritative authored state.
            // Gameplay/settings remain disposable and never alter study records
            // or create a second persistent database in the checkout.
            let authored = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false,
                levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
            db = try BountyExperimentDAO.contentCopy(of: authored, fraction: 1)
            db.recordRuns(in: authored)
            #else
            db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history"),
                fullRefresh: true
            )
            #endif
            try db.towerTypeDao.validateAuthoredContent()
            let heroes = try db.heroDao.validateAuthoredContent()
            #if canImport(UIKit)
            for hero in heroes {
                try hero.validateArtwork { name in
                    guard let image = UIImage(named: name) else { return false }
                    return image.size.width > 0 && image.size.height > 0
                }
            }
            #endif
            virtualCanvas = try db.virtualCanvasDao.get()
            towerMenuLayout = TowerMenuLayout(virtualCanvas: virtualCanvas)
            settings = try PlayerSettingsStore(dao: db.playerSettingsDao)
            hudLayoutConfig = try db.hudLayoutDao.get()
            metaUpgrades = try MetaUpgradeStore(dao: db.playerMetaUpgradeDao)
        }
        catch {
            fatalError("\(error)")
        }
    }
    
}
