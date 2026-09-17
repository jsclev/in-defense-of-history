#if DEBUG
import SwiftUI
import UIKit

/// Opt-in native renderer/runner check. It never builds towers in a player's level.
struct MoraleDeviceReview: View {
    let store: Store
    @State private var walkers: [LevelRunner.Walker] = []
    @State private var message = "Checking artillery morale…"
    @State private var crowdTravel: CGFloat = 0
    @State private var impactRadius: CGFloat = 0
    @State private var impactAge = Double.infinity
    private let hpFractions = [1.0, 0.85, 0.70, 0.55, 0.40, 0.25, 0.10]
    private let paths: [(String, Color)] = [
        ("Tan dirt", Color(red: 201/255.0, green: 176/255.0, blue: 128/255.0)),
        ("Dark mud", Color(red: 72/255.0, green: 61/255.0, blue: 52/255.0)),
        ("Red clay", Color(red: 173/255.0, green: 101/255.0, blue: 80/255.0)),
        ("Gray stone", Color(red: 143/255.0, green: 150/255.0, blue: 157/255.0)),
        ("Snow", Color(red: 244/255.0, green: 245/255.0, blue: 245/255.0))]

    var body: some View {
        VStack(spacing: 3) {
            Text(message).font(.system(size: 13)).foregroundStyle(.white)
            ForEach(paths.indices, id: \.self) { index in
                HStack {
                    Text(paths[index].0).font(.system(size: 12)).foregroundStyle(.white).frame(width: 78)
                    HStack(spacing: 22) {
                        ForEach(walkers.indices, id: \.self) { index in
                            reviewUnit(index).frame(width: 40, height: 44)
                        }
                    }.padding(.horizontal, 16).frame(height: 50).background(paths[index].1)
                }
            }
            HStack {
                Text("Crowded").font(.system(size: 12)).foregroundStyle(.white).frame(width: 78)
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { index in
                        if !walkers.isEmpty {
                            reviewUnit(1 + index % 6)
                                .frame(width: 24, height: 44).offset(y: index % 2 == 0 ? -3 : 3)
                        }
                    }
                }
                .offset(x: crowdTravel)
                .padding(.horizontal, 17).frame(height: 53)
                .background { ArtilleryImpactView(age: impactAge, radius: impactRadius) }
                .background(paths[0].1).clipped()
            }
            Text("Level 1 hits: 0 / 1 / 2 / 3 / 4 / 5 / 6 · blue = morale remaining · troops: 30.1 pt")
                .font(.system(size: 12)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        .task { await runReview() }
    }

    private func reviewUnit(_ index: Int) -> some View {
        let walker = walkers[index]
        let hp = hpFractions[index]
        let height = MapSpriteSizing.walker.minimum
        return ZStack {
            EnemyMoraleSprite(assetName: walker.assetName, morale: walker.morale, height: height)
            if hp < 1 {
                UnitHealthBar(fraction: hp, width: MapSpriteSizing.healthBarWidth.minimum,
                               height: MapSpriteSizing.healthBarHeight.minimum)
                    .offset(y: -height / 2 - MapSpriteSizing.walkerLabelLift.minimum)
            }
        }
        .frame(height: height)
    }

    @MainActor private func runReview() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("morale-review", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows).first,
                  let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first
            else { throw NSError(domain: "MoraleReview", code: 1) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                                       safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                                     levelInfoID: level.id, mapImageName: level.mapImageName,
                                     enemyHPMultiplier: try store.db.difficultyDao.requireSelected().enemyHPMultiplier)
            let rangeChecks = try runner.verifyArtilleryRangeOnDevice()
            let result = try runner.verifyArtilleryMoraleOnDevice()
            impactRadius = CGFloat(result.checks.first?["aoeRadius"] as? Double ?? 0) * canvas.scaleFactor
            walkers = result.walkers
            message = "All six artillery tiers passed · firing boundary · separate blast radius · morale"
            record = ["passed": true, "checks": result.checks, "rangeChecks": rangeChecks,
                      "displayMorale": result.walkers.map { $0.morale.value },
                      "displayHPFractions": hpFractions,
                      "displayMoraleFractions": result.walkers.map { $0.morale.displayedFraction },
                      "healthBarWidthPoints": MapSpriteSizing.healthBarWidth.minimum,
                      "healthBarHeightPoints": MapSpriteSizing.healthBarHeight.minimum,
                      "spriteHeightPoints": MapSpriteSizing.walker.minimum,
                      "displayScale": window.screen.scale,
                      "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown"]
            try await Task.sleep(for: .seconds(1))
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = image.pngData() else { throw NSError(domain: "MoraleReview", code: 2) }
            try png.write(to: directory.appendingPathComponent("native.png"))
            walkers = try runner.applyLevelOneReviewImpact(to: walkers)
            impactAge = 0.12
            for index in walkers.indices {
                walkers[index].morale.advance(seconds: 0.12)
            }
            message = "Another level 1 shell · blue drains toward the lower value · 0.12 seconds"
            record["afterHitMorale"] = walkers.map { $0.morale.value }
            record["duringDrainFractions"] = walkers.map { $0.morale.displayedFraction }
            try await Task.sleep(for: .seconds(1))
            let impact = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let impactPNG = impact.pngData() else { throw NSError(domain: "MoraleReview", code: 3) }
            try impactPNG.write(to: directory.appendingPathComponent("impact.png"))
            let motionDirectory = directory.appendingPathComponent("motion", isDirectory: true)
            try FileManager.default.createDirectory(at: motionDirectory, withIntermediateDirectories: true)
            message = "Moving crowd · blue fill shows morale remaining · no white reset"
            for frame in 0..<12 {
                crowdTravel = CGFloat(frame) * 4 - 22
                impactAge += 0.1
                for index in walkers.indices {
                    walkers[index].morale.advance(seconds: 0.1)
                }
                try await Task.sleep(for: .milliseconds(100))
                let motion = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let motionPNG = motion.pngData() else { throw NSError(domain: "MoraleReview", code: 4) }
                try motionPNG.write(to: motionDirectory.appendingPathComponent(String(format: "%02d.png", frame)))
            }
            record["motionFrames"] = 12
            record["afterDrainFractions"] = walkers.map { $0.morale.displayedFraction }
            record["moraleCue"] = "one continuous blue fill proportional to morale remaining, over a fixed dark track"
        } catch {
            message = "Morale review failed: \(error.localizedDescription)"
            record["passed"] = false
            record["error"] = error.localizedDescription
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("result.json"))
        } catch { message = "Unable to save morale review: \(error.localizedDescription)" }
    }
}
#endif
