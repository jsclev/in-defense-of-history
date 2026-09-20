#if DEBUG
import SwiftUI
import UIKit

/// Physical-device verification through the production menus and purchase handlers.
struct TowerUpgradeDeviceReview: View {
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
            .appendingPathComponent("level4-upgrade-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        func require(_ valid: Bool, _ message: String) throws {
            if !valid { throw NSError(domain: "TowerUpgradeReview", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName)
            self.runner = runner; self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .milliseconds(400))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first else { throw NSError(domain: "TowerUpgradeReview", code: 2) }
            func labels(in view: UIView) -> [UILabel] {
                (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
            }
            func verifyLabel(_ details: TowerMenuDetails, screenshot: String?) async throws {
                try await Task.sleep(for: .milliseconds(120))
                window.layoutIfNeeded()
                guard let label = labels(in: window).first(where: {
                    $0.attributedText?.string == details.name + "\n" + details.description
                }) else { throw NSError(domain: "TowerUpgradeReview", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Missing displayed label: \(details.name)"]) }
                var ancestor = label.superview
                while ancestor != nil && !(ancestor is UIScrollView) { ancestor = ancestor?.superview }
                guard let scroll = ancestor as? UIScrollView else { throw NSError(domain: "TowerUpgradeReview", code: 4) }
                let viewport = scroll.convert(scroll.bounds, to: window)
                try require(canvas.safeInsetsRect.insetBy(dx: -1, dy: -1).contains(viewport),
                            "Upgrade label viewport is outside safe bounds: \(details.name)")
                let measured = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                try require(measured.height <= label.bounds.height + 1, "Clipped label text: \(details.name)")
                if let screenshot {
                    let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                    let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    guard let data = image.pngData() else { throw NSError(domain: "TowerUpgradeReview", code: 5) }
                    try data.write(to: directory.appendingPathComponent(screenshot + ".png"))
                }
            }
            let arsenal = try store.db.towerTypeDao.getDesignArsenal()
            var checks: [[String: Any]] = [], purchases = 0, renderedLabels = 0
            let minimumSize = store.towerMenuLayout.getTowerButtonSize(
                playAreaScalingFactor: 340 / store.virtualCanvas.playAreaRect.height)
            for definition in arsenal.towers {
                for tier in definition.tiers where tier.level == 4 {
                    let slot = try runner.prepareTowerUpgradeReview(kind: definition.kind)
                    runner.tapUpgradeButton(branch: tier.branch)
                    try await verifyLabel(runner.menuDetails(for: definition.kind, atLevel: 4, branch: tier.branch)!, screenshot: nil)
                    renderedLabels += 1
                    runner.tapUpgradeButton(branch: tier.branch)
                    runner.selectPlacedTower(atSlot: slot)
                    try require(runner.upgradePaths.count == 2, "Missing level-four path choices")
                    for path in tier.tuning.upgradePaths {
                        try require(UIImage(named: path.iconName) != nil, "Missing authored icon: \(path.iconName)")
                        for rank in path.ranks {
                            let before = runner.money
                            runner.tapUpgradePath(path.id)
                            try require(runner.money == before, "First tap spent money")
                            try await verifyLabel(path.menuDetails(purchasedRank: rank.rank - 1),
                                                  screenshot: rank.rank == 1 ? path.id : nil)
                            renderedLabels += 1
                            runner.tapUpgradePath(path.id)
                            try require(runner.money == before - rank.cost, "Incorrect path price")
                            try require(runner.placedTower(atSlot: slot)?.upgrades.rank(for: path.id) == rank.rank,
                                        "Rank purchase was not stored on the selected tower")
                            purchases += 1
                        }
                        let before = runner.money
                        runner.tapUpgradePath(path.id); runner.tapUpgradePath(path.id)
                        try require(runner.money == before, "Maxed path spent money")
                        try await verifyLabel(path.menuDetails(purchasedRank: path.ranks.count), screenshot: nil)
                        renderedLabels += 1
                        runner.dismissMenu(); runner.selectPlacedTower(atSlot: slot)
                    }
                    // Native minimum-size proof with the real frame, price and continuous progress cue.
                    let proof = HStack(spacing: 12) {
                        ForEach(tier.tuning.upgradePaths) { path in
                            UpgradeMenuItem(towerMenuLayout: store.towerMenuLayout,
                                iconName: path.iconName, dropKind: definition.kind,
                                cost: path.ranks[0].cost, isArmed: false, isAffordable: true,
                                buttonSize: minimumSize, canInspect: true, progress: 0.5, action: {})
                        }
                    }.padding(12).background(Color(red: 0.22, green: 0.28, blue: 0.2))
                    let renderer = ImageRenderer(content: proof); renderer.scale = 3
                    guard let data = renderer.uiImage?.pngData() else { throw NSError(domain: "TowerUpgradeReview", code: 6) }
                    try data.write(to: directory.appendingPathComponent("minimum-\(definition.kind.rawValue)-\(tier.branch)@3x.png"))
                    checks.append(try runner.verifyPurchasedTowerOnDevice(slot: slot))
                }
            }
            try require(purchases == 56 && checks.count == 14, "Incomplete specialty coverage")
            result["purchases"] = purchases
            result["renderedLabels"] = renderedLabels
            result["checks"] = checks
            result["minimumButtonPoints"] = minimumSize.width
            result["screenScale"] = window.screen.scale
            result["passed"] = true
        } catch { result["error"] = String(describing: error) }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { print("Upgrade review could not save results: \(error)") }
    }
}
#endif
