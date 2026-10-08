#if DEBUG
import SwiftUI
import UIKit

/// Isolated physical-device gameplay checks and native, runtime-sized melee captures.
struct CombatDeviceReview: View {
    let store: Store
    @State private var runner: LevelRunner?
    @State private var reviewScene: LevelSceneSetup?
    @State private var canvas: RuntimeCanvas?
    @State private var frame: LevelRunner.CombatReviewFrame?
    @State private var message = "Checking morale and melee…"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            if let scene = reviewScene ?? runner?.sceneSetup, let canvas, let frame {
                let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas,
                                                       fitting: canvas.playAreaRect)
                scene.mapArt.underlay(in: projection)
                GroundTroopLayer(presentation: frame.presentation, interpolation: 1, militia: frame.militia,
                                 sprites: MapSpriteScale(runtimeCanvas: canvas), projection: projection)
            }
            Text(message).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(8).background(.black.opacity(0.85)).padding(.leading, 65)
        }
        .ignoresSafeArea()
        .task { await runReview() }
    }

    @MainActor private func runReview() async {
        if CommandLine.arguments.contains("--melee-animation-review") {
            await runAnimationReview()
            return
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("combat-review", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first,
                let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first
            else { throw NSError(domain: "CombatReview", code: 1) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                                       safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                                     levelInfoID: level.id, mapImageName: level.mapImageName)
            let ranges = try runner.verifyArtilleryRangeOnDevice()
            let morale = try runner.verifyArtilleryMoraleOnDevice()
            let result = try runner.verifyMoraleCombatOnDevice()
            self.runner = runner; self.canvas = canvas
            record = ["passed": true, "combat": result.checks, "rangeChecks": ranges,
                      "moraleChecks": morale.checks, "displayScale": window.screen.scale,
                      "walkerHeightPoints": MapSpriteScale(runtimeCanvas: canvas).points(MapSpriteSizing.walker),
                      "combatSpacingPoints": runner.combatRules.meleeCombatSpacing * canvas.scaleFactor]
            let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
            for (index, frame) in result.frames.enumerated() {
                self.frame = frame
                message = String(format: "Melee %.1f s · six living enemies · top: full morale · bottom: 35%%", frame.seconds)
                try await Task.sleep(for: .milliseconds(350))
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw NSError(domain: "CombatReview", code: 2) }
                try data.write(to: directory.appendingPathComponent(String(format: "melee-%02d.png", index)))
            }
        } catch {
            message = "Combat review failed: \(error.localizedDescription)"
            record["passed"] = false; record["error"] = error.localizedDescription
        }
        do {
            record["completedAt"] = Date().timeIntervalSince1970
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { message = "Unable to save combat review: \(error.localizedDescription)" }
    }

    @MainActor private func runAnimationReview() async {
        // A full native capture takes longer than the phone's idle timeout.
        // Keep only this diagnostic awake, restoring the prior app setting on exit.
        let wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("melee-animation-review", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first else { throw NSError(domain: "MeleeAnimationReview", code: 1) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                                       safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let review = try LevelRunner.makeMeleeAnimationReview(db: store.db)
            self.canvas = canvas; reviewScene = review.scene
            let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas,
                                                   fitting: canvas.playAreaRect)
            let sprites = MapSpriteScale(runtimeCanvas: canvas)
            let height = sprites.points(MapSpriteSizing.meleeUnit)
            let density = window.screen.scale
            var crop = CGRect.null
            for sample in review.samples {
                let positions = sample.frame.militia.map(\.position) + sample.frame.presentation.walkers.map(\.position)
                for position in positions {
                    let foot = projection.viewPoint(position)
                    crop = crop.union(CGRect(x: foot.x - height * 2, y: foot.y - height * 1.5,
                                             width: height * 4, height: height * 2))
                }
            }
            crop = crop.insetBy(dx: -20, dy: -20)
            crop = CGRect(x: crop.midX - max(200, crop.width) / 2,
                          y: crop.midY - max(120, crop.height) / 2,
                          width: max(200, crop.width), height: max(120, crop.height))
                .intersection(window.bounds).integral
            let pixelCrop = CGRect(x: crop.minX * density, y: crop.minY * density,
                                   width: crop.width * density, height: crop.height * density).integral
            let format = UIGraphicsImageRendererFormat(); format.scale = density
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
            var captures: [[String: Any]] = []
            for (index, sample) in review.samples.enumerated() {
                frame = sample.frame
                message = "Melee animation review · \(index + 1)/\(review.samples.count)"
                // Let SwiftUI commit the selected real tick. Capture wall time
                // is deliberately not the movie clock: PNG encoding may be slow.
                try await Task.sleep(for: .milliseconds(34))
                var drewHierarchy = false
                let image = renderer.image { _ in
                    drewHierarchy = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard drewHierarchy else {
                    throw NSError(domain: "MeleeAnimationReview", code: 2,
                        userInfo: [NSLocalizedDescriptionKey:
                            "UIKit hierarchy capture failed at frame \(index); app state \(UIApplication.shared.applicationState.rawValue), scene state \(window.windowScene?.activationState.rawValue ?? -99), window hidden \(window.isHidden)"])
                }
                guard let pixels = image.cgImage,
                      let cropped = pixels.cropping(to: pixelCrop),
                      let data = UIImage(cgImage: cropped).pngData() else {
                    throw NSError(domain: "MeleeAnimationReview", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Native screenshot crop/encoding failed at frame \(index), crop \(pixelCrop), image size \(image.size)"])
                }
                let filename = String(format: "frame-%04d.png", index)
                try data.write(to: directory.appendingPathComponent(filename))
                if [0, review.firstImpactIndex, review.samples.count - 1].contains(index) {
                    guard let full = image.pngData() else { throw NSError(domain: "MeleeAnimationReview", code: 3) }
                    try full.write(to: directory.appendingPathComponent(String(format: "full-%04d.png", index)))
                }
                var metadata = sample.metadata
                metadata["file"] = filename; metadata["index"] = index
                captures.append(metadata)
                if index % 15 == 0 {
                    try JSONSerialization.data(withJSONObject: ["captured": index + 1, "total": review.samples.count])
                        .write(to: directory.appendingPathComponent("progress.json"), options: .atomic)
                }
            }
            record = review.metadata
            record["passed"] = true; record["captures"] = captures
            record["displayScale"] = density
            record["meleeHeightPoints"] = height
            record["groundInsetFraction"] = MapSpriteSizing.meleeGroundInsetFraction
            record["windowPoints"] = [window.bounds.width, window.bounds.height]
            record["cropRectPoints"] = [crop.minX, crop.minY, crop.width, crop.height]
            record["cropPixels"] = [pixelCrop.width, pixelCrop.height]
            message = "Melee animation captured · \(captures.count) real engine frames"
        } catch {
            record["error"] = String(describing: error)
            message = "Melee animation review failed: \(error.localizedDescription)"
        }
        do {
            record["completedAt"] = Date().timeIntervalSince1970
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        } catch { message = "Unable to save melee animation review: \(error.localizedDescription)" }
    }
}
#endif
