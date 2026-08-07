import Foundation

public struct ContentCatalog: Sendable {
    public let enemyTypes: [EnemyType]
    public let towerTypes: [TowerType]

    private let enemyIndexByID: [UUID: Int]
    private let towerIndexByID: [UUID: Int]

    public init(enemyTypes: [EnemyType], towerTypes: [TowerType]) {
        // Sort for deterministic index assignment regardless of source order.
        let enemies = enemyTypes.sorted { $0.id < $1.id }
        let towers = towerTypes.sorted { $0.id < $1.id }
        self.enemyTypes = enemies
        self.towerTypes = towers
        var em: [UUID: Int] = [:]
        em.reserveCapacity(enemies.count)
        for (i, e) in enemies.enumerated() { em[e.id] = i }
        var tm: [UUID: Int] = [:]
        tm.reserveCapacity(towers.count)
        for (i, t) in towers.enumerated() { tm[t.id] = i }
        self.enemyIndexByID = em
        self.towerIndexByID = tm
    }

    public func enemyIndex(id: UUID) -> Int? { enemyIndexByID[id] }
    public func towerIndex(id: UUID) -> Int? { towerIndexByID[id] }

    public enum CatalogError: Error, CustomStringConvertible {
        case unknownEnemyType(UUID)
        case unknownTowerType(UUID)

        public var description: String {
            switch self {
            case .unknownEnemyType(let id): return "Unknown enemy type id '\(id)'"
            case .unknownTowerType(let id): return "Unknown tower type id '\(id)'"
            }
        }
    }

    public func requireEnemyIndex(id: UUID) throws -> Int {
        guard let i = enemyIndexByID[id] else { throw CatalogError.unknownEnemyType(id) }
        return i
    }

    public func requireTowerIndex(id: UUID) throws -> Int {
        guard let i = towerIndexByID[id] else { throw CatalogError.unknownTowerType(id) }
        return i
    }
}
