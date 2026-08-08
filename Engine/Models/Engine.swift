import Foundation

public enum SimEvent: Sendable {
    case waveStarted(index: Int)
    case towerBuilt(slot: Int, towerID: UUID)
    case towerUpgraded(slot: Int, level: Int)
    case enemySpawned(spawnID: Int, typeID: UUID)
    case enemyRemoved(spawnID: Int, typeID: UUID, fate: EnemyFate)
    case towerFired(slot: Int, target: Point)
}

public protocol SimulationObserver: AnyObject {
    func handle(_ event: SimEvent, atTime time: Double)
}

