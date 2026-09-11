
import Foundation
import LevelEditorFormats

final class Probe {
    struct Clock { var tick: Int64 = 0 }
    var timer = Clock()
    var lives = 3
    var escapedEnemyCount = 0
    var isDefeated = false
    var pendingSpawns = [1, 2]
    var stopCount = 0
    var refreshCount = 0
    var walkers: [Walker] = []
    var blockedWalkerIDs: Set<Int> = []
    let paths = [Path(points: [Point(0, 0), Point(100, 0)]),
                 Path(points: [Point(0, 0), Point(200, 0)])]
    func stop() { stopCount += 1 }
    func refreshWaveStartState() { refreshCount += 1 }
    struct Walker: Identifiable {
        let id: Int
        let assetName: String
        let speed: Double
        let maxHP: Double
        var hp: Double
        let bounty: Int
        let damageMin: Double
        let damageMax: Double
        let cover: Double
        let blockImmune: Bool
        let spawnTick: Int64
        let pathIndex: Int
        var position: CGPoint = .zero
        var pathDistance: Double = 0
        /// Ticks spent standing still while a militia soldier blocked the way;
        /// subtracted from the analytic march so the walker resumes where it
        /// stopped instead of teleporting ahead.
        var haltedTicks: Double = 0
    }
private func loseLife() {
        guard !isDefeated else { return }
        lives = max(0, lives - 1)
        escapedEnemyCount += 1
        guard lives == 0 else { return }
        isDefeated = true
        pendingSpawns.removeAll()
        refreshWaveStartState()
        stop()
    }
    func march(to tick: Int64) {
        let frameDtTicks = Double(tick - timer.tick)
        timer.tick = tick
        let alpha = 0.0
                var marching: [Walker] = []
        for var walker in walkers {
            if blockedWalkerIDs.contains(walker.id) {
                walker.haltedTicks += frameDtTicks
                marching.append(walker)
                continue
            }
            let ticksWalking = Double(timer.tick - walker.spawnTick) + alpha
                - walker.haltedTicks
            let distance = walker.speed * ticksWalking * SimClock.dt
            let path = paths[min(max(walker.pathIndex, 0), paths.count - 1)]
            if path.totalLength > 0, distance >= path.totalLength {
                loseLife()
                continue
            }
            let p = path.point(atDistance: distance)
            walker.position = CGPoint(x: p.x, y: p.y)
            walker.pathDistance = distance
            marching.append(walker)
        }
        walkers = marching
    }
    func add(_ id: Int, path: Int = 0) {
        walkers.append(Walker(id: id, assetName: "fixture", speed: 30, maxHP: 10, hp: 10,
            bounty: 1, damageMin: 1, damageMax: 1, cover: 0, blockImmune: false,
            spawnTick: 0, pathIndex: path))
    }
    static func run() {
        let single = Probe()
        single.add(0)
        single.march(to: 99)
        precondition(single.walkers.count == 1 && single.lives == 3 && single.escapedEnemyCount == 0)
        single.march(to: 100)
        precondition(single.walkers.isEmpty && single.lives == 2 && single.escapedEnemyCount == 1)
        single.march(to: 200)
        precondition(single.escapedEnemyCount == 1 && single.stopCount == 0)

        let blocked = Probe()
        blocked.add(0)
        blocked.blockedWalkerIDs = [0]
        blocked.march(to: 100)
        precondition(blocked.escapedEnemyCount == 0 && blocked.walkers.count == 1)
        blocked.blockedWalkerIDs = []
        blocked.march(to: 199)
        precondition(blocked.escapedEnemyCount == 0)
        blocked.march(to: 200)
        precondition(blocked.escapedEnemyCount == 1)

        let routes = Probe()
        routes.add(0); routes.add(1, path: 1)
        routes.march(to: 100)
        precondition(routes.escapedEnemyCount == 1 && routes.walkers.map(\.id) == [1])
        routes.march(to: 200)
        precondition(routes.escapedEnemyCount == 2 && routes.lives == 1)

        let burst = Probe()
        for id in 0..<5 { burst.add(id) }
        burst.march(to: 200)
        precondition(burst.isDefeated && burst.lives == 0 && burst.escapedEnemyCount == 3)
        precondition(burst.stopCount == 1 && burst.pendingSpawns.isEmpty)
        burst.loseLife()
        precondition(burst.escapedEnemyCount == 3 && burst.stopCount == 1)
        print("PASS: exit boundary, removal without duplicate events, blocked enemies, multiple routes, burst losses, final-life event, and defeat shutdown")
    }
}
@main struct Main { static func main() { Probe.run() } }
