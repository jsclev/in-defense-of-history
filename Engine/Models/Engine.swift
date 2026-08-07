// Engine.swift
// The deterministic fixed-timestep core. One instance == one run of one level
// with one seed and one policy. The shipped game renders on top of this same
// class; the balancer runs it headless at thousands of ticks per second.
//
// Tick order (stable, documented, load-bearing for determinism):
//   1. policy               (build/upgrade decisions)
//   2. spawns               (wave timeline)
//   3. position cache       (path scalar -> Point, once per tick)
//   4. auras                (rally beat, command aura)
//   5. towers fire          (shot / terror / contagion application)
//   6. contagion tick       (drain to floor, convert to morale, spread)
//   7. morale resolution    (shaken/broken transitions + break cascades)
//   8. movement & exits     (routs run backwards; leaks cost lives)
//   9. compaction           (order-preserving removal)
//  10. end conditions
import Foundation

/// Telemetry seam. No-op today; a recorder conforms to this later and the
/// engine never changes. Events are deliberately coarse-grained.
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

