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
                    node: node, hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            }
        }
        .ignoresSafeArea()
        .task {
            if CommandLine.arguments.contains("--live-wave") { await reviewLiveWave() }
            else { await review() }
        }
    }

    /// Regression capture with ordinary purchases, authored waves, and CADisplayLink.
    /// This deliberately does not use the staged art-review movement helper.
    @MainActor private func reviewLiveWave() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engineer-live-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: result).write(to: directory.appendingPathComponent("result.json"))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first,
                let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").dropFirst(14).first
            else { throw NSError(domain: "EngineerLiveReview", code: 1) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                levelInfoID: level.id, mapImageName: level.mapImageName)
            defer { runner.stop() }
            result["startingMoney"] = runner.startingMoney
            result["coverage"] = runner.engineerLiveReviewCoverage()
            let slots = [17, 11, 15]
            for slot in slots {
                runner.selectSlot(slot)
                runner.tapBuildButton(.special); runner.tapBuildButton(.special)
            }
            guard runner.placedTowers.count == slots.count else {
                throw NSError(domain: "EngineerLiveReview.Purchase", code: 2)
            }
            result["towerSlots"] = slots
            result["moneyAfterPurchases"] = runner.money
            result["slowFractions"] = runner.engineerObstacleFields.map { $0.stats.slowFraction }
            self.runner = runner; self.canvas = canvas; self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .milliseconds(400))
            if CommandLine.arguments.contains("--double-speed") { runner.speedUp() }
            runner.startNextWave()
            runner.start()
            var samples: [[String: Any]] = []
            let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
            let start = ContinuousClock.now
            while start.duration(to: .now) < .seconds(60) {
                try await Task.sleep(for: .milliseconds(100))
                var sample = runner.engineerLiveReviewSnapshot
                let elapsed = start.duration(to: .now).components
                sample["wallSeconds"] = Double(elapsed.attoseconds) / 1e18 + Double(elapsed.seconds)
                samples.append(sample)
                if samples.count % 20 == 0 {
                    let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    try image.pngData()?.write(to: directory.appendingPathComponent("frame-\(samples.count).png"))
                }
            }
            result["samples"] = samples
            var slowedMeasurements = 0
            var normalMeasurements = 0
            var maximumRatioError = 0.0
            for (before, after) in zip(samples, samples.dropFirst()) {
                guard let oldTime = before["gameSeconds"] as? Double,
                      let newTime = after["gameSeconds"] as? Double, newTime > oldTime,
                      let oldWalkers = before["walkers"] as? [[String: Any]],
                      let newWalkers = after["walkers"] as? [[String: Any]] else { continue }
                for next in newWalkers {
                    guard let id = next["id"] as? Int,
                          let previous = oldWalkers.first(where: { ($0["id"] as? Int) == id }),
                          previous["blocked"] as? Bool == false, next["blocked"] as? Bool == false,
                          previous["morale"] as? Double == runner.combatRules.moraleMax,
                          next["morale"] as? Double == runner.combatRules.moraleMax,
                          let multiplier = next["slowMultiplier"] as? Double,
                          previous["slowMultiplier"] as? Double == multiplier,
                          let oldDistance = previous["distance"] as? Double,
                          let newDistance = next["distance"] as? Double,
                          let speed = next["baseSpeed"] as? Double else { continue }
                    let ratio = (newDistance - oldDistance) / ((newTime - oldTime) * speed)
                    maximumRatioError = max(maximumRatioError, abs(ratio - multiplier))
                    if multiplier < 1 { slowedMeasurements += 1 } else { normalMeasurements += 1 }
                }
            }
            result["slowedMeasurements"] = slowedMeasurements
            result["normalMeasurements"] = normalMeasurements
            result["maximumRatioError"] = maximumRatioError
            result["passed"] = slowedMeasurements > 100 && normalMeasurements > 100 && maximumRatioError < 0.001
        } catch { result["error"] = error.localizedDescription }
        result["completedAt"] = Date().timeIntervalSince1970
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        } catch { print("Engineer live review export failed: \(error)") }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engineer-abatis-review", isDirectory: true)
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
            // Decode the installed catalog at each requested display density.
            // The device may select its thinned rendition for every request.
            var renditions: [[String: Any]] = []
            for density in 1...3 {
                guard let image = UIImage(named: "engineer_rough_ground", in: .main,
                    compatibleWith: UITraitCollection(displayScale: CGFloat(density))),
                    let pixels = image.cgImage, let png = image.pngData() else {
                    throw NSError(domain: "EngineerReview.MissingAbatisAsset", code: density)
                }
                try png.write(to: directory.appendingPathComponent("compiled-abatis@\(density)x.png"))
                renditions.append(["requestedScale": density, "actualScale": image.scale,
                                   "width": pixels.width, "height": pixels.height])
            }
            result["abatisRenditions"] = renditions
            result["startingMoney"] = runner.startingMoney
            self.runner = runner; self.canvas = canvas; self.node = CampaignNode(order: 15, level: level)
            let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
            func capture(_ name: String, crop: CGRect? = nil) throws {
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let output: UIImage
                if let crop {
                    let pixels = crop.applying(CGAffineTransform(scaleX: format.scale, y: format.scale))
                    guard let part = image.cgImage?.cropping(to: pixels) else {
                        throw NSError(domain: "EngineerReview", code: 4)
                    }
                    output = UIImage(cgImage: part, scale: format.scale, orientation: .up)
                } else { output = image }
                guard let png = output.pngData() else { throw NSError(domain: "EngineerReview", code: 4) }
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
                guard let field = runner.engineerObstacleFields.first else { throw NSError(domain: "EngineerReview", code: 5) }
                let scale = 340 / store.virtualCanvas.playAreaRect.height
                for density in 1...3 {
                    for active in [false, true] {
                        let renderer = ImageRenderer(content: EngineerObstacleView(field: field, roadSurface: runner.roadSurfacePath,
                            scale: scale,
                            isSlowingEnemies: active).padding(field.size.width * scale / 2))
                        renderer.scale = CGFloat(density)
                        guard let image = renderer.uiImage, let png = image.pngData() else {
                            throw NSError(domain: "EngineerReview", code: 6)
                        }
                        let state = active ? "active" : "idle"
                        try png.write(to: directory.appendingPathComponent("obstacles-\(tier)-\(state)@\(density)x.png"))
                    }
                }
            }
            // Maximum extent used to spill far beyond the painted road.
            let upgradeSlot = try runner.prepareEngineerObstacleReview(level: 3)
            runner.selectPlacedTower(atSlot: upgradeSlot)
            runner.tapUpgradeButton(branch: 2); runner.tapUpgradeButton(branch: 2)
            runner.dismissMenu()
            try await Task.sleep(for: .milliseconds(250))
            try capture("level-4")
            runner.selectPlacedTower(atSlot: upgradeSlot)
            for path in runner.upgradePaths {
                for _ in path.ranks { runner.tapUpgradePath(path.id); runner.tapUpgradePath(path.id) }
            }
            runner.dismissMenu()
            try await Task.sleep(for: .milliseconds(250))
            try capture("level-4-max")
            let minimumScale = SpriteHeight.smallestPlayableHeight / store.virtualCanvas.playAreaRect.height
            var roadFits: [[String: Any]] = []
            for item in try runner.engineerRoadFitReviewFields() {
                let field = item.field
                let padding = field.size.width * minimumScale
                let renderer = ImageRenderer(content: EngineerObstacleView(field: field,
                    roadSurface: runner.roadSurfacePath, scale: minimumScale).padding(padding))
                renderer.scale = 1
                guard let image = renderer.uiImage, let png = image.pngData() else {
                    throw NSError(domain: "EngineerRoadFit.Render", code: item.slot)
                }
                let file = "road-fit-\(item.slot)-\(item.stage).png"
                try png.write(to: directory.appendingPathComponent(file))
                roadFits.append(["slot": item.slot, "stage": item.stage, "file": file,
                    "x": field.position.x, "y": field.position.y, "heading": field.heading,
                    "worldWidth": field.size.width, "worldHeight": field.size.height,
                    "scale": minimumScale, "padding": padding,
                    "imageWidth": image.size.width, "imageHeight": image.size.height])
            }
            result["roadFitRenders"] = roadFits
            result["roadFitSource"] = "loaded GeoJSON road polygon"
            // Native motion frames keep neighboring units, the footprint and the
            // actual movement loop together for inspection at normal cadence.
            try runner.prepareEngineerObstacleReview(level: 1, entering: true)
            guard let site = runner.engineerObstacleFields.first?.position else {
                throw NSError(domain: "EngineerReview", code: 7)
            }
            let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
            let center = projection.viewPoint(site)
            let motionCrop = CGRect(x: center.x - 140, y: center.y - 100, width: 280, height: 180)
                .intersection(window.bounds)
            var motion: [[String: Any]] = []
            for frame in 0..<100 {
                runner.advanceEngineerObstacleReview(seconds: 0.12)
                try await Task.sleep(for: .milliseconds(120))
                try capture(String(format: "motion-%02d", frame), crop: motionCrop)
                let feedback = runner.engineerObstacleFeedback
                motion.append(["frame": frame, "seconds": Double(frame + 1) * 0.12,
                    "slowedWalkerIDs": feedback.walkerIDs.sorted(),
                    "activeTowerSlots": feedback.towerSlots.sorted(),
                    "walkers": runner.walkers.map { ["id": $0.id, "pathIndex": $0.pathIndex,
                        "distance": $0.pathDistance, "x": $0.position.x, "y": $0.position.y] as [String: Any] }])
            }
            result["motion"] = motion
            result["motionTier"] = 1
            result["presentation"] = "four-clump-abatis"
            result["motionCropPoints"] = [motionCrop.minX, motionCrop.minY, motionCrop.width, motionCrop.height]
            result["minimumPlayableHeight"] = SpriteHeight.smallestPlayableHeight
            result["walkerHeightPoints"] = MapSpriteScale(runtimeCanvas: canvas).points(MapSpriteSizing.walker)
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
