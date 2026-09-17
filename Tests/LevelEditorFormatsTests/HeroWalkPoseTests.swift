import XCTest
@testable import LevelEditorFormats

final class HeroWalkPoseTests: XCTestCase {
    private let washington = HeroWalkCycle.georgeWashingtonAssetName

    func testWashingtonNormalSpeedTakesTwoStepsInPointEightFourSeconds() {
        var pose = HeroWalkPose(baseAssetName: washington, position: .zero)
        // 180 map units/second: 0.42 s used to exhaust the whole cycle.
        // It now reaches the opposite foot contact, halfway through the cycle.
        pose.advance(to: Point(180 * 0.42, 0))
        XCTAssertEqual(pose.sample(alpha: 1).assetName, "\(washington)_walk_e_16")
        pose.advance(to: Point(180 * 0.84, 0))
        XCTAssertEqual(pose.sample(alpha: 1).assetName, "\(washington)_walk_e_0")
        XCTAssertEqual(pose.position.x, 151.2, accuracy: 1e-9)
        XCTAssertEqual(HeroWalkCycle.cycleDistance(for: HeroWalkCycle.henryKnoxAssetName), 75.6)
    }

    func testCatchUpInterpolatesOnlyTheLastTickOfActualMovement() throws {
        let area = try HeroMovementArea(geoJSON: Data("""
            {"features":[{"properties":{"category":"gameplay","kind":"enemy_path","widthPx":20},
            "geometry":{"type":"LineString","coordinates":[[0,0],[1000,0]]}}]}
            """.utf8), defaultPathWidth: 20)
        var movement = try HeroMovement(area: area, spawn: .zero)
        var unit = MilitiaUnit(position: .zero, hp: 100)
        var pose = HeroWalkPose(baseAssetName: washington, position: unit.position)
        XCTAssertTrue(movement.command(to: Point(900, 0), unit: &unit))
        let context = MilitiaContext(rules: AuthoredDatabaseFixture.combatRules, freeEnemies: [], targetPosition: nil, rallyPoint: .zero,
                                    towerPosition: .zero, leashRadius: 130, engageScanRadius: 80)
        // Variable display delivery, including a late frame and game speed-up.
        // The simulation still takes ordinary fixed ticks in each batch.
        var ticks = 0
        for batch in [1, 3, 1, 8, 2, 1, 4] {
            for _ in 0..<batch {
                _ = movement.update(&unit, context: context, moveSpeed: 180, deltaTime: SimClock.dt)
                pose.advance(to: unit.position)
                ticks += 1
            }
            let step = 180 * SimClock.dt
            for alpha in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let sample = pose.sample(alpha: alpha)
                let distance = (Double(ticks - 1) + alpha) * step
                XCTAssertEqual(sample.position.x, distance, accuracy: 1e-8)
                XCTAssertEqual(sample.walkPhase,
                               distance.truncatingRemainder(dividingBy: 151.2), accuracy: 1e-8)
            }
            // Repeated display samples must not advance simulation or animation.
            XCTAssertEqual(pose.sample(alpha: 0.5).assetName, pose.sample(alpha: 0.5).assetName)
            XCTAssertEqual(pose.position, unit.position)
        }
    }

    func testTurningRetainsDistancePhaseAndStoppingFreezesIt() {
        var pose = HeroWalkPose(baseAssetName: washington, position: .zero)
        pose.advance(to: Point(60, 0))
        pose.advance(to: Point(60, 12))
        XCTAssertEqual(pose.facing, .north)
        XCTAssertEqual(pose.sample(alpha: 0.5).position, Point(60, 6))
        XCTAssertEqual(pose.sample(alpha: 0.5).walkPhase, 66, accuracy: 1e-9)
        pose.advance(to: pose.position)
        for alpha in [0.0, 0.5, 1.0] {
            XCTAssertEqual(pose.sample(alpha: alpha).assetName, "\(washington)_idle_e")
            XCTAssertEqual(pose.sample(alpha: alpha).walkPhase, 72, accuracy: 1e-9)
        }
        // A respawn creates a new pose at the spawn, with no animated teleport.
        pose = HeroWalkPose(baseAssetName: washington, position: .zero)
        XCTAssertEqual(pose.sample(alpha: 0.5).position, .zero)
        XCTAssertEqual(pose.sample(alpha: 0.5).walkPhase, 0)
        XCTAssertFalse(pose.isWalking)
    }

    func testFrameSelectionDependsOnDistanceRatherThanDisplayRate() {
        for speed in [90.0, 180.0, 360.0] {
            for framesPerSecond in [30, 60, 120] {
                var pose = HeroWalkPose(baseAssetName: washington, position: .zero)
                var ticks = 0
                for frame in 1...framesPerSecond {
                    let time = Double(frame) / Double(framesPerSecond)
                    let dueTick = Int((time / SimClock.dt).rounded(.down))
                    while ticks < dueTick {
                        ticks += 1
                        pose.advance(to: Point(Double(ticks) * SimClock.dt * speed, 0))
                    }
                    guard ticks > 0 else { continue }
                    let alpha = time / SimClock.dt - Double(ticks)
                    let sample = pose.sample(alpha: alpha)
                    XCTAssertEqual(sample.position.x, (time - SimClock.dt) * speed, accuracy: 1e-8)
                    XCTAssertEqual(sample.walkPhase,
                                   sample.position.x.truncatingRemainder(dividingBy: 151.2), accuracy: 1e-8)
                }
            }
        }
    }
}
