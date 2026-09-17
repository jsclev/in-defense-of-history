#if DEBUG
import SwiftUI
import UIKit

/// Runs on a physical iPhone using the production runner, map and controls.
struct EngineerDeviceReview: View {
    let store: Store
    @State private var runner: LevelRunner?
    @State private var canvas: RuntimeCanvas?
    @State private var node: CampaignNode?

    var body: some View {
        ZStack {
            Color.black
            if let runner, let canvas, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node, difficulty: Difficulty(id: UUID(), level: 1, name: "Review",
                        detail: "", enemyHPMultiplier: 1), hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            }
        }
        .ignoresSafeArea()
        .task { await review() }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engineer-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: result).write(to: directory.appendingPathComponent("result.json"))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first,
                let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").dropFirst(14).first
            else { throw NSError(domain: "EngineerReview", code: 3) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                                     levelInfoID: level.id, mapImageName: level.mapImageName)
            result["checks"] = try runner.verifyEngineerObstaclesOnDevice()
            result["sapperChecks"] = try runner.verifyDemolitionAutomationOnDevice()
            result["displayScale"] = window.screen.scale
            result["startingMoney"] = runner.startingMoney
            self.runner = runner; self.canvas = canvas; self.node = CampaignNode(order: 15, level: level)
            let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
            func capture(_ name: String) throws {
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let png = image.pngData() else { throw NSError(domain: "EngineerReview", code: 4) }
                try png.write(to: directory.appendingPathComponent(name + ".png"))
            }
            for tier in 1...3 {
                let slot = try runner.prepareEngineerObstacleReview(level: tier)
                try await Task.sleep(for: .milliseconds(300))
                try capture("level-\(tier)")
                runner.selectPlacedTower(atSlot: slot)
                try await Task.sleep(for: .milliseconds(200))
                try capture("menu-\(tier)")
                runner.dismissMenu()
                guard let stats = runner.towerLevels[.special]?[tier]?[1]?.engineerObstacles else {
                    throw NSError(domain: "EngineerReview", code: 5)
                }
                let radius = CGFloat(stats.radius) * 340 / store.virtualCanvas.playAreaRect.height
                for density in 1...3 {
                    let renderer = ImageRenderer(content: EngineerObstacleView(radius: radius))
                    renderer.scale = CGFloat(density)
                    guard let image = renderer.uiImage, let png = image.pngData() else {
                        throw NSError(domain: "EngineerReview", code: 6)
                    }
                    try png.write(to: directory.appendingPathComponent("obstacles-\(tier)@\(density)x.png"))
                }
            }
            // Native motion frames keep neighboring units, the footprint and the
            // actual movement loop together for inspection at normal cadence.
            for frame in 0..<20 {
                runner.advanceEngineerObstacleReview(seconds: 0.1)
                try await Task.sleep(for: .milliseconds(100))
                try capture(String(format: "motion-%02d", frame))
            }
            result["passed"] = true
        } catch { result["error"] = error.localizedDescription }
        result["completedAt"] = Date().timeIntervalSince1970
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        } catch { print("Engineer review export failed: \(error)") }
    }
}
#endif
