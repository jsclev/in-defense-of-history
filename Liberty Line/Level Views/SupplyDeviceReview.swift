#if DEBUG
import SwiftUI
import UIKit

/// Opt-in review using the production menu, purchase handlers and bundled art.
/// Writes only PNGs and JSON; the normal launch still reloads authored state.
struct SupplyDeviceReview: View {
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
        }.task { await review() }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("supply-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        func require(_ valid: Bool, _ message: String) throws {
            if !valid { throw NSError(domain: "SupplyReview", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName)
            self.runner = runner
            self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .milliseconds(500))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first else { throw NSError(domain: "SupplyReview", code: 2) }
            func capture(_ name: String) async throws {
                try await Task.sleep(for: .milliseconds(250))
                window.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw NSError(domain: "SupplyReview", code: 3) }
                try data.write(to: directory.appendingPathComponent(name + ".png"))
            }
            let baseSlot = try runner.prepareTowerUpgradeReview(kind: .supply, atLevel: 1)
            runner.dismissMenu()
            let slots = runner.slotPositions.indices.filter { $0 != baseSlot }.sorted {
                let a = runner.slotPositions[$0], b = runner.slotPositions[$1]
                return hypot(a.x - runner.playArea.midX, a.y - runner.playArea.midY)
                    < hypot(b.x - runner.playArea.midX, b.y - runner.playArea.midY)
            }
            try require(slots.count >= 5, "Six supply sprites require six tower slots")
            runner.selectSlot(slots[0])
            try require(TowerKind.allCases.allSatisfy { runner.maxLevel(for: $0) >= 1 }, "Missing build choice")
            try await capture("five-build-buttons")
            runner.tapBuildButton(.supply)
            try await capture("supply-selected")
            runner.dismissMenu()
            let variants = [(2, 1), (3, 1), (4, 1), (4, 2), (4, 3)]
            for (index, variant) in variants.enumerated() {
                let slot = slots[index]
                runner.selectSlot(slot)
                let before = runner.money
                runner.tapBuildButton(.supply)
                try require(runner.money == before, "First build tap spent money")
                runner.tapBuildButton(.supply)
                for next in 2...variant.0 {
                    runner.selectPlacedTower(atSlot: slot)
                    if next == 4 {
                        try require(runner.upgradeOffers.count == 3, "Missing supply specialty")
                        try await capture("specialties-before-branch-\(variant.1)")
                    }
                    let branch = next == 4 ? variant.1 : 1
                    runner.tapUpgradeButton(branch: branch)
                    if next == 4 { try await capture("specialty-selected-\(branch)") }
                    runner.tapUpgradeButton(branch: branch)
                }
                let placed = runner.placedTower(atSlot: slot)
                try require(placed?.level == variant.0 && placed?.branch == variant.1, "Upgrade did not reach requested tier")
                runner.dismissMenu()
            }
            try await capture("six-supply-towers")
            runner.selectPlacedTower(atSlot: slots[4])
            try await capture("hospital-range")
            runner.dismissMenu()
            let minimumSize = store.towerMenuLayout.getTowerButtonSize(
                playAreaScalingFactor: 340 / store.virtualCanvas.playAreaRect.height)
            for branch in 1...3 {
                guard let name = TowerKind.supply.specializationMenuIconName(atLevel: 4, branch: branch),
                      let cost = runner.upgradeCost(for: .supply, to: 4, branch: branch) else {
                    throw NSError(domain: "SupplyReview", code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Missing supply specialty \(branch)"])
                }
                for density in 1...3 {
                    for affordable in [true, false] {
                        let renderer = ImageRenderer(content: UpgradeMenuItem(
                            towerMenuLayout: store.towerMenuLayout, iconName: name, dropKind: .supply,
                            cost: cost, isArmed: false, isAffordable: affordable,
                            buttonSize: minimumSize, action: {}).padding(.bottom, 10))
                        renderer.scale = CGFloat(density)
                        guard let data = renderer.uiImage?.pngData() else {
                            throw NSError(domain: "SupplyReview", code: 6)
                        }
                        let state = affordable ? "ready" : "unaffordable"
                        try data.write(to: directory.appendingPathComponent(
                            "minimum-supply-\(branch)-\(state)@\(density)x.png"))
                    }
                }
            }
            let expectedNames = (1...3).compactMap { TowerKind.supply.assetName(atLevel: $0) }
                + (1...3).compactMap { TowerKind.supply.assetName(atLevel: 4, branch: $0) }
                + [TowerKind.supply.menuIconName]
                + (1...3).compactMap { TowerKind.supply.specializationMenuIconName(atLevel: 4, branch: $0) }
            var images: [[String: Any]] = []
            for name in expectedNames {
                guard let image = UIImage(named: name), let cg = image.cgImage, let png = image.pngData()
                else { throw NSError(domain: "SupplyReview", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing compiled image \(name)"]) }
                try png.write(to: directory.appendingPathComponent(name + ".png"))
                images.append(["name": name, "width": cg.width, "height": cg.height, "scale": image.scale])
            }
            try require(runner.placedTowers.count == 6, "Missing placed supply sprites")
            try require(runner.placedTowers.allSatisfy {
                runner.towerLevel(for: $0)?.attackMode == TowerAttackMode.none &&
                $0.demolitionCharge == nil && runner.rallyPoint(forSlot: $0.slotIndex) == nil
            }, "Supply tower has a combat capability")
            let behavior = try runner.verifySupplyBehaviorOnDevice()
            result = ["passed": true, "behavior": behavior, "buildChoices": TowerKind.allCases.map(\.rawValue),
                "placedSupplyTowers": runner.placedTowers.count, "compiledImages": images,
                "devicePoints": [window.bounds.width, window.bounds.height],
                "minimumMenuButtonPoints": minimumSize.width,
                "screenScale": window.screen.scale,
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown"]
        } catch { result["error"] = String(describing: error) }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { print("Could not save supply review: \(error)") }
    }
}
#endif
