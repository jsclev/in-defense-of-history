#if DEBUG
import SwiftUI
import UIKit

/// Runs the production clock and captures the real pause overlay on an iPhone.
struct LevelPauseDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var runner: LevelRunner?
    @State private var node: CampaignNode?
    @State private var showingCampaign = false

    var body: some View {
        Group {
            if showingCampaign {
                RootView(store: store, runtimeCanvas: canvas)
            } else if let runner, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node,
                    hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, onExit: { showingCampaign = true })
            } else { Color.black }
        }
        .task { await review() }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pause-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, hudLayoutConfig: store.hudLayoutConfig,
                levelInfoID: level.id, mapImageName: level.mapImageName)
            self.runner = runner
            self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .milliseconds(500))
            let controls = MasterControlsLayout(runtimeCanvas: canvas,
                                               location: store.hudLayoutConfig.masterControls)
            for (name, glyph) in [("speed", "speed_up_icon_glyph"), ("pause", "pause_icon_glyph")] {
                let renderer = ImageRenderer(content: PaintedMasterControlButton(
                    iconName: glyph, label: name, buttonSize: controls.buttonSize, action: {}))
                renderer.scale = 3
                guard let data = renderer.uiImage?.pngData() else {
                    throw NSError(domain: "PauseReview", code: 4)
                }
                try data.write(to: directory.appendingPathComponent("control-\(name).png"))
            }
            result = try await runner.runPauseLifecycleReview()
            try await Task.sleep(for: .milliseconds(300))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "PauseReview", code: 2)
            }
            window.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let capture = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let data = capture.pngData() else { throw NSError(domain: "PauseReview", code: 3) }
            try data.write(to: directory.appendingPathComponent("paused.png"))
            runner.resume()
            try await Task.sleep(for: .milliseconds(200))
            let hudCapture = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let hudData = hudCapture.pngData() else { throw NSError(domain: "PauseReview", code: 5) }
            try hudData.write(to: directory.appendingPathComponent("hud-controls.png"))
            runner.pause()
            result["masterControlButtonSize"] = controls.buttonSize
            result["screenWidth"] = window.bounds.width
            result["screenHeight"] = window.bounds.height
            result["scale"] = window.screen.scale
        } catch {
            result["passed"] = false
            result["error"] = error.localizedDescription
        }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { print("Could not save pause review: \(error)") }
    }
}
#endif
