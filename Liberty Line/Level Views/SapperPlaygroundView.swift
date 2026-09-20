#if DEBUG
import SwiftUI
import UIKit

struct SapperPlaygroundView: View {
    let store: Store
    let runtimeCanvas: RuntimeCanvas
    @State private var session: Session?
    @State private var error: String?
    @State private var exited = false

    private struct Session {
        let node: CampaignNode
        let runner: LevelRunner
        let hudLayout: HudLayoutConfig
    }

    var body: some View {
        Group {
            if exited {
                RootView(store: store, runtimeCanvas: runtimeCanvas)
            } else if let session {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: runtimeCanvas, towerMenuLayout: store.towerMenuLayout,
                    node: session.node,
                    hudLayoutConfig: session.hudLayout, reviewRunner: session.runner) {
                        exited = true
                    }
            } else if let error {
                Text("Unable to start level 15: \(error)")
            } else {
                ProgressView("Opening level 15…")
            }
        }
        .task {
            guard session == nil, !exited else { return }
            await startSession()
        }
    }

    @MainActor private func startSession() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sapper-playground", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: record)
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
            guard let node = CampaignNode.load(db: store.db).first(where: { $0.id == 15 }) else {
                throw NSError(domain: "SapperPlayground", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Level is missing"])
            }
            let hudLayout = try store.db.hudLayoutDao.get()
            func makeRunner() -> LevelRunner {
                LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: runtimeCanvas, hudLayoutConfig: hudLayout,
                    levelInfoID: node.levelInfoID, mapImageName: node.mapImageName)
            }
            var runner = makeRunner()
            guard runner.isReady, runner.maxLevel(for: .areaOfEffect) >= 4, runner.maxLevel(for: .special) >= 4 else {
                throw NSError(domain: "SapperPlayground", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Level is not ready with the charge-placement branch unlocked: \(runner.status)"])
            }

            guard let levelID = node.levelInfoID else {
                throw NSError(domain: "SapperPlayground", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Level has no database identity"])
            }
            let authoredMoney = try store.db.levelInfoDao.getBy(id: levelID).startingMoney
            guard runner.startingMoney == authoredMoney, runner.money == authoredMoney else {
                throw NSError(domain: "SapperPlayground", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Level starting money differs from level_info.starting_money"])
            }
            record["databaseStartingMoney"] = authoredMoney
            // Campaign re-entry creates a fresh runner. Spend through the real
            // purchase handler, then verify that re-entry reloads the DAO value.
            guard let slot = runner.slotPositions.indices.first,
                  let kind = TowerKind.allCases.first(where: {
                      runner.maxLevel(for: $0) > 0 && (runner.buildCost(for: $0).map { $0 <= authoredMoney } == true)
                  }) else {
                throw NSError(domain: "SapperPlayground", code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "No affordable tower for the re-entry check"])
            }
            runner.selectSlot(slot)
            runner.tapBuildButton(kind)
            runner.tapBuildButton(kind)
            guard runner.money < authoredMoney else {
                throw NSError(domain: "SapperPlayground", code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Purchase did not spend money"])
            }
            record["moneyAfterPurchase"] = runner.money
            runner = makeRunner()
            guard runner.isReady, runner.money == authoredMoney, runner.placedTowers.isEmpty else {
                throw NSError(domain: "SapperPlayground", code: 8,
                    userInfo: [NSLocalizedDescriptionKey: "Campaign re-entry did not restore the database starting money"])
            }
            record["moneyAfterReentry"] = runner.money
            record["reentryVerified"] = true
            record["level"] = node.id
            record["levelName"] = node.title
            record["startingMoney"] = runner.startingMoney
            record["moneyAtLaunch"] = runner.money
            record["moneySource"] = "Normal level data; no session override"
            record["difficulty"] = runner.content.difficulty.name
            record["artilleryMaxLevel"] = runner.maxLevel(for: .areaOfEffect)
            record["engineersMaxLevel"] = runner.maxLevel(for: .special)
            record["awaitingFirstWave"] = runner.awaitingWaveStart
            session = Session(node: node, runner: runner, hudLayout: hudLayout)

            try await Task.sleep(for: .milliseconds(700))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "SapperPlayground", code: 3)
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = image.pngData() else { throw NSError(domain: "SapperPlayground", code: 4) }
            try png.write(to: directory.appendingPathComponent("level-15.png"), options: .atomic)
            record["passed"] = true
        } catch {
            self.error = error.localizedDescription
            record["error"] = error.localizedDescription
        }
        record["completedAt"] = Date().timeIntervalSince1970
        do {
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        } catch { self.error = "Unable to save launch verification: \(error.localizedDescription)" }
    }
}
#endif
