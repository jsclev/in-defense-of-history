import Foundation

@MainActor
public final class Store {
    public let virtualCanvas: VirtualCanvas
    public let db: Db
    public let towerMenuLayout: TowerMenuLayout
    public let settings: PlayerSettingsStore
    public let hudLayoutConfig: HudLayoutConfig

    public init() {
        do {
            if let domain = Bundle.main.bundleIdentifier {
                BundledDatabase.discardLegacyPreferences(domain: domain)
            }
            db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history"),
                fullRefresh: true
            )
            try db.towerTypeDao.validateAuthoredContent()
            virtualCanvas = try db.virtualCanvasDao.get()
            towerMenuLayout = TowerMenuLayout(virtualCanvas: virtualCanvas)
            settings = try PlayerSettingsStore(dao: db.playerSettingsDao)
            hudLayoutConfig = try db.hudLayoutDao.get()
        }
        catch {
            fatalError("\(error)")
        }
    }
    
}
