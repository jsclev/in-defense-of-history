#if DEBUG
import SwiftUI
import UIKit

/// Isolated physical-device gameplay checks and native, runtime-sized melee captures.
struct CombatDeviceReview: View {
    let store: Store
    @State private var runner: LevelRunner?
    @State private var canvas: RuntimeCanvas?
    @State private var frame: LevelRunner.CombatReviewFrame?
    @State private var message = "Checking morale and melee…"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            if let runner, let canvas, let frame {
                let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas,
                                                       fitting: canvas.playAreaRect)
                runner.mapArt.underlay(in: projection)
                GroundTroopLayer(walkers: frame.walkers, militia: frame.militia,
                                 sprites: MapSpriteScale(runtimeCanvas: canvas), projection: projection)
            }
            Text(message).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(8).background(.black.opacity(0.85)).padding(.leading, 65)
        }
        .ignoresSafeArea()
        .task { await runReview() }
    }

    @MainActor private func runReview() async {
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
}
#endif
