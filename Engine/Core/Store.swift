public final class Store {
    public let canvasSpec: CanvasSpec
    public let db: Db
    public let towerMenuLayout: TowerMenuLayout

    public init() {
        do {
            db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: true),
                fullRefresh: true
            )
            canvasSpec = try db.canvasSpecDao.get()
            towerMenuLayout = TowerMenuLayout(canvasSpec: canvasSpec)
        }
        catch {
            fatalError("\(error)")
        }
    }
    
}
