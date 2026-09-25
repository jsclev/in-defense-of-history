import XCTest
@testable import LevelEditorFormats

final class BattlePresentationTests: XCTestCase {
    func testHealthLevelsHandleDamageHealingAndOverkillWithoutViewCalculations() {
        for (hp, fraction, damaged) in [(100.0, 1.0, false), (75, 0.75, true),
                                        (0, 0, true), (-20, 0, true), (110, 1, false)] {
            let health = UnitHealth(current: hp, maximum: 100)
            XCTAssertEqual(health.fraction, fraction)
            XCTAssertEqual(health.isDamaged, damaged)
        }
        XCTAssertEqual(UnitHealth(current: 75, maximum: 150).fraction, 0.5,
                       "Changing maximum HP must change the level without changing a view")
    }

    @MainActor func testInterpolationFollowsPathThroughBendsAndKeepsCombatStateUntouched() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .ranged, level: 1, branch: 1)
        var walker = try XCTUnwrap(demo.frames.first?.enemies.first)
        let route = Path(points: [Point(0, 0), Point(10, 0), Point(10, 20)])
        walker.pathDistance = 15
        walker.position = CGPoint(x: 10, y: 5)
        walker.hp = walker.maxHP * 0.75
        walker.morale.apply(loss: 25, direction: 1)
        let frame = BattlePresentation(walkers: [walker], projectiles: [], paths: [route],
            previousWalkerDistances: [walker.id: 5], previousProjectilePositions: [:])
        for (alpha, expected) in [(-1.0, CGPoint(x: 5, y: 0)), (0.25, CGPoint(x: 7.5, y: 0)),
                                  (0.5, CGPoint(x: 10, y: 0)), (0.75, CGPoint(x: 10, y: 2.5)),
                                  (2, CGPoint(x: 10, y: 5))] {
            let displayed = try XCTUnwrap(frame.displayedWalkers(alpha: alpha).first)
            XCTAssertEqual(displayed.position, expected)
            XCTAssertEqual(displayed.pathDistance, 15)
            XCTAssertEqual(displayed.hp, walker.hp)
            XCTAssertEqual(displayed.health.fraction, 0.75, accuracy: 1e-10)
            XCTAssertEqual(displayed.morale.value, walker.morale.value)
            XCTAssertEqual(displayed.morale.displayedFraction, walker.morale.displayedFraction)
        }
        XCTAssertEqual(frame.walkers[0].position, CGPoint(x: 10, y: 5))
    }

    @MainActor func testSpawnRemovalAndRecordingStayFaithfulToLivePresentation() throws {
        let content = try BattleTestFixture.authored()
        let game = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.publishesPresentation = true
        XCTAssertEqual(game.perform(.startWave), .ok)
        game.advance(ticks: 1, interpolation: 0)
        let spawn = game.presentation
        XCTAssertFalse(spawn.walkers.isEmpty)
        XCTAssertEqual(spawn.displayedWalkers(alpha: 0).map(\.position), spawn.walkers.map(\.position))
        game.advance(ticks: 30, interpolation: 0)
        let recording = game.presentation
        for alpha in [0.0, 0.25, 0.5, 0.75, 1.0] {
            game.advance(ticks: 0, interpolation: alpha)
            XCTAssertEqual(recording.displayedWalkers(alpha: alpha).map(\.position),
                           game.presentation.displayedWalkers(alpha: game.presentationAlpha).map(\.position))
        }
        game.advance(ticks: 30, interpolation: 1)
        XCTAssertNotEqual(recording.walkers.map(\.position), game.walkers.map(\.position),
                          "A recording must not follow later mutations of the live engine")
        let removed = BattlePresentation(walkers: [], projectiles: [], paths: recording.paths,
            previousWalkerDistances: recording.previousWalkerDistances, previousProjectilePositions: [:])
        XCTAssertTrue(removed.displayedWalkers(alpha: 0.5).isEmpty,
                      "Previous positions cannot resurrect an enemy removed by combat")
    }

    @MainActor func testPreviewUsesFractionalTicksAndCanonicalProjectionAndSizing() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .areaOfEffect, level: 4, branch: 1)
        let elapsed = 12.5 * SimClock.dt
        XCTAssertEqual(demo.frameIndex(at: elapsed), 12)
        XCTAssertEqual(demo.interpolation(at: elapsed), 0.5, accuracy: 1e-10)
        XCTAssertEqual(demo.interpolation(at: elapsed + demo.loopDuration), 0.5, accuracy: 1e-10)
        let frame = demo.frames[12]
        let atStart = frame.presentation.displayedWalkers(alpha: 0)
        let midway = frame.presentation.displayedWalkers(alpha: demo.interpolation(at: elapsed))
        XCTAssertNotEqual(atStart.map(\.position), midway.map(\.position))
        let camera = DemonstrationProjection(bounds: demo.bounds, size: CGSize(width: 321, height: 256),
                                             virtualCanvas: demo.virtualCanvas)
        let levelScale = MapSpriteScale(playArea: demo.bounds, viewSize: camera.projection.fitRect.size)
        XCTAssertEqual(camera.sprites, levelScale)
        XCTAssertEqual(camera.unitHeight, MapSpriteSizing.walker.minimum)
        for enemy in frame.enemies {
            XCTAssertEqual(camera.point(enemy.position), camera.projection.viewPoint(enemy.position))
        }
        for (before, after) in zip(demo.frames, demo.frames.dropFirst()) {
            XCTAssertEqual(after.seconds - before.seconds, SimClock.dt, accuracy: 1e-10,
                           "Every frame must advance the encounter; no frozen tail")
        }
        for offset in [0.25, 0.5, 1.75, 5.5] {
            let time = demo.loopDuration - offset * SimClock.dt
            let alpha = demo.interpolation(at: time)
            XCTAssertEqual(alpha, ceil(offset) - offset, accuracy: 1e-10,
                           "Keep ordinary interpolation right up to the loop boundary")
        }
        XCTAssertEqual(demo.frameIndex(at: demo.loopDuration + SimClock.dt / 2), 0)
    }

    func testLevelsPreviewsAndReviewCannotOwnAlternateEnemyOrHealthRendering() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["Liberty Line/Level Views/LevelMapView.swift",
                     "Liberty Line/Level Views/TowerDemonstrationPage.swift",
                     "Liberty Line/Level Views/MoraleDeviceReview.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertTrue(source.contains("GroundTroopLayer(presentation:"), path)
            for forbidden in ["EnemyMoraleSprite(", "UnitHealthBar(", "drawUnits(", "enemy.hp /", "walker.hp /",
                              "enemy.morale.remainingFraction", "point(atDistance:"] {
                XCTAssertFalse(source.contains(forbidden), "\(path) bypasses shared presentation: \(forbidden)")
            }
        }
    }
}
