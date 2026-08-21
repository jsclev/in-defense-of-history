public final class Store {
    public let virtualCanvas: VirtualCanvas
    public let db: Db
    public let towerMenuLayout: TowerMenuLayout

    public init() {
        do {
            db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: true),
                fullRefresh: true
            )
            virtualCanvas = try db.virtualCanvasDao.get()
            towerMenuLayout = TowerMenuLayout(virtualCanvas: virtualCanvas)
        }
        catch {
            fatalError("\(error)")
        }
    }
    
}
