import Combine
import XCTest
@testable import LevelEditorFormats

final class BattleObservationTests: XCTestCase {
    @MainActor func testHeadlessCombatAndRecordingsNeverInvalidateViews() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let content = try BattleTestFixture.authored(db: fixture.db)
        for destination in [BattleRecording.preview, .database(fixture.db.levelRunDao, .simulator),
                            .database(fixture.db.levelRunDao, .player)] {
            let battle = try BattleEngine(recording: destination, content: content, heroesEnabled: true,
                startingMoneyOverride: 1000, seed: 1776, onVictory: { _, _ in 0 })
            var notifications = 0
            let subscription = battle.objectWillChange.sink { notifications += 1 }
            defer { subscription.cancel() }
            XCTAssertEqual(battle.perform(.build(slot: 17, kind: .ranged)), .ok)
            XCTAssertEqual(battle.perform(.startWave), .ok)
            for _ in 0..<300 { battle.advance(ticks: 1, interpolation: 0) }
            XCTAssertFalse(battle.walkers.isEmpty)
            XCTAssertEqual(battle.timer.tick, 300)
            battle.pause()
            battle.resume()
            battle.finishRecording(status: .abandoned)
            XCTAssertEqual(notifications, 0, "Recordings and combat must not publish UI changes")
        }
    }

    @MainActor func testLiveFramesAndNestedInputsInvalidateOnceBeforeMutation() throws {
        let content = try BattleTestFixture.authored()
        let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
            startingMoneyOverride: 1000, seed: 1776, onVictory: { _, _ in 0 })
        battle.heroImageAspectRatios = Dictionary(uniqueKeysWithValues: content.deployments.map { ($0.hero.id, 1) })
        battle.publishesPresentation = true
        var ticksBeforeChanges: [Int64] = []
        var moneyBeforeChanges: [Int] = []
        let subscription = battle.objectWillChange.sink {
            ticksBeforeChanges.append(battle.timer.tick)
            moneyBeforeChanges.append(battle.money)
        }
        defer { subscription.cancel() }
        // The command nests selection, arming and purchase handlers.
        XCTAssertEqual(battle.perform(.build(slot: 17, kind: .ranged)), .ok)
        XCTAssertEqual(moneyBeforeChanges, [1000])
        XCTAssertLessThan(battle.money, 1000)
        XCTAssertEqual(battle.perform(.startWave), .ok)
        battle.advance(ticks: 30, interpolation: 0.25)
        XCTAssertEqual(ticksBeforeChanges, [0, 0, 0])
        XCTAssertEqual(battle.timer.tick, 30)
        XCTAssertFalse(battle.presentation.walkers.isEmpty)
        XCTAssertEqual(battle.presentationAlpha, 0.25)
        battle.advance(ticks: 0, interpolation: 0.75)
        XCTAssertEqual(ticksBeforeChanges, [0, 0, 0, 30])
        XCTAssertEqual(battle.presentationAlpha, 0.75)
    }

    @MainActor func testPausedControlsAndRallyDismissalStillInvalidateWithoutAFrame() throws {
        let content = try BattleTestFixture.authored()
        let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        battle.heroImageAspectRatios = Dictionary(uniqueKeysWithValues: content.deployments.map { ($0.hero.id, 1) })
        battle.publishesPresentation = true
        var notifications = 0
        let subscription = battle.objectWillChange.sink { notifications += 1 }
        defer { subscription.cancel() }
        battle.activateHUD(.pause)
        XCTAssertEqual(notifications, 1)
        XCTAssertTrue(battle.isPaused)
        battle.advance(ticks: 30, interpolation: 0.5)
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(battle.timer.tick, 0)
        let id = try XCTUnwrap(battle.heroPosts.first?.hero.id)
        let mode = try XCTUnwrap(battle.heroAIEnabled[id])
        XCTAssertTrue(battle.setHeroAIEnabled(!mode, for: id))
        XCTAssertEqual(notifications, 2)
        battle.setPlaySpeed(try PlaySpeed(2))
        XCTAssertEqual(notifications, 3)
        XCTAssertEqual(battle.playSpeed.factor, 2)
        battle.rallyFlagFlash = .init(id: 7, position: .zero)
        battle.dismissRallyFlag(id: 6)
        XCTAssertEqual(notifications, 3)
        battle.dismissRallyFlag(id: 7)
        XCTAssertNil(battle.rallyFlagFlash)
        XCTAssertEqual(notifications, 4)
        battle.resume()
        XCTAssertEqual(notifications, 5)
        XCTAssertFalse(battle.isPaused)
    }

    @MainActor func testHeroControlPublisherProvidesCurrentAndUpdatedModesWithoutUIObservation() throws {
        let content = try BattleTestFixture.authored()
        let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        let id = try XCTUnwrap(battle.heroPosts.first?.hero.id)
        let initial = battle.heroAIEnabled
        var modes: [[UUID: Bool]] = []
        var notifications = 0
        let controls = battle.heroAIChanges.sink { modes.append($0) }
        let views = battle.objectWillChange.sink { notifications += 1 }
        defer { controls.cancel(); views.cancel() }
        XCTAssertEqual(modes, [initial])
        let changed = !(try XCTUnwrap(initial[id]))
        XCTAssertTrue(battle.setHeroAIEnabled(changed, for: id))
        XCTAssertEqual(modes.count, 2)
        XCTAssertEqual(modes.last?[id], changed)
        var current: [UUID: Bool]?
        let lateSubscriber = battle.heroAIChanges.sink { current = $0 }
        defer { lateSubscriber.cancel() }
        XCTAssertEqual(current, battle.heroAIEnabled)
        XCTAssertTrue(battle.setHeroAIEnabled(changed, for: id))
        XCTAssertEqual(modes.count, 2, "An unchanged setting must not feed back into SQLite")
        XCTAssertEqual(notifications, 0)
    }
}
