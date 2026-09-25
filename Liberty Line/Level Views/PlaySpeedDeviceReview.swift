#if DEBUG
import SwiftUI

/// Exercises the real display clock and recording DAO on a physical device.
struct PlaySpeedDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var runner: LevelRunner?
    @State private var node: CampaignNode?

    var body: some View {
        Group {
            if let runner, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node, hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            } else { Color.black }
        }.task { await verify() }
    }

    @MainActor private func verify() async {
        guard runner == nil else { return }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("play-speed-review.json")
        var report: [String: Any] = ["passed": false]
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw DbError.Db(message: "Play speed review: \(message)") }
        }
        do {
            let id = try store.db.levelInfoDao.getIdBy(levelName: "Charleston")!
            let content = try BattleContent(db: store.db, levelID: id)
            let player = LevelRunner(db: store.db, content: content, runtimeCanvas: canvas,
                hudLayoutConfig: store.hudLayoutConfig, replaySeed: 1776)
            runner = player
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first { $0.id == id }!
            node = CampaignNode(order: 15, level: level)
            try require(player.playSpeed.factor == 1, "Initial player rate is not authored 1.0")
            player.selectSlot(17); player.tapBuildButton(.ranged)
            try require(player.tapBuildButton(.ranged) == .ok, "Player purchase failed")
            player.startNextWave()
            try await Task.sleep(for: .milliseconds(500))
            var samples: [[String: Any]] = []
            for factor in [1.0, 0.5, 2.0] {
                player.setPlaySpeed(try PlaySpeed(factor))
                player.resume(); player.start()
                let clock = ContinuousClock(), started = ContinuousClock().now
                let firstTick = player.timer.tick
                try await Task.sleep(for: .seconds(2))
                player.pause()
                let wall = started.duration(to: clock.now) / .seconds(1)
                let game = Double(player.timer.tick - firstTick) * SimClock.dt
                let measured = game / wall
                samples.append(["factor": factor, "wallSeconds": wall, "gameSeconds": game, "measuredFactor": measured])
                try require(abs(measured - factor) < factor * 0.2,
                    "Expected \(factor)x, measured \(measured)x")
                let pausedTick = player.timer.tick
                try await Task.sleep(for: .milliseconds(150))
                try require(player.timer.tick == pausedTick, "Paused gameplay advanced")
            }
            player.finishRecording(status: .abandoned)
            let runID = player.runID!
            let run = try store.db.levelRunDao.get(id: runID)
            try require(run.source == .player && run.playSpeed.factor == 1, "Incorrect run metadata")
            let replay = try LevelReplayer(dao: store.db.levelRunDao, runID: runID)
            var rates = Set<Double>(), changes = 0, builds = 0
            while try replay.advance() {
                rates.insert(replay.playSpeed.factor)
                changes += replay.actions.filter { $0.name == "setPlaySpeed" }.count
                builds += replay.actions.filter { $0.name == "towerBuilt" }.count
            }
            try require(rates == Set([0.5, 1.0, 2.0]) && changes == 3 && builds == 1, "Missing recorded speeds or purchase")
            report = ["passed": true, "runID": runID.uuidString, "initialFactor": run.playSpeed.factor,
                "rates": samples, "speedChangeActions": changes, "towerBuiltActions": builds,
                "lastTick": run.lastTick, "source": run.source.rawValue]
        } catch {
            runner?.pause(); runner?.finishRecording(status: .failed)
            report["error"] = String(describing: error)
        }
        report["completedAt"] = ISO8601DateFormatter().string(from: Date())
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output, options: .atomic)
        } catch { print("Unable to save play speed review: \(error)") }
    }
}
#endif
