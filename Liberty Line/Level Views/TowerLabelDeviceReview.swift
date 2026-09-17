#if DEBUG
import SwiftUI
import UIKit

/// Opt-in physical-device review of the production selection UI and copy.
struct TowerLabelDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var runner: LevelRunner?
    @State private var node: CampaignNode?

    var body: some View {
        Group {
            if let runner, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node, difficulty: Difficulty(id: UUID(), level: 1, name: "Review",
                        detail: "", enemyHPMultiplier: 1), hudLayoutConfig: store.hudLayoutConfig,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            } else { Color.black }
        }
        .task { await review() }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tower-label-review", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName,
                                     enemyHPMultiplier: try store.db.difficultyDao.requireSelected().enemyHPMultiplier)
            self.runner = runner
            self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .milliseconds(400))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first else { throw failure("Missing device window") }
            func labels(in view: UIView) -> [UILabel] {
                (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
            }
            var captures: [[String: Any]] = []
            func capture(_ details: TowerMenuDetails, name: String) async throws {
                try await Task.sleep(for: .milliseconds(250))
                window.layoutIfNeeded()
                guard let label = labels(in: window).first(where: {
                    $0.attributedText?.string == details.name + "\n" + details.description
                }), let text = label.attributedText else { throw failure("Missing rendered label: \(details.name)") }
                let rect = label.convert(label.bounds, to: window)
                guard canvas.safeInsetsRect.contains(rect) else { throw failure("Text outside safe area: \(details.name) \(rect)") }
                var ancestor = label.superview
                while ancestor != nil && !(ancestor is UIScrollView) { ancestor = ancestor?.superview }
                guard let viewport = ancestor as? UIScrollView,
                      abs(label.bounds.width - (viewport.bounds.width - 24)) < 1
                else { throw failure("Native text ignored the measured wrapping width: \(details.name)") }
                let measured = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                guard measured.height <= label.bounds.height + 1 else { throw failure("Clipped text: \(details.name)") }
                let titleFont = text.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
                let bodyFont = text.attribute(.font, at: text.length - 1, effectiveRange: nil) as! UIFont
                guard titleFont.pointSize >= 20, bodyFont.pointSize >= 17 else { throw failure("Text below reading-size floor") }
                let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw failure("Could not capture screen") }
                try data.write(to: directory.appendingPathComponent(name + ".png"))
                captures.append(["name": details.name, "file": name + ".png",
                                 "textFrame": [rect.minX, rect.minY, rect.width, rect.height],
                                 "titlePoints": titleFont.pointSize, "bodyPoints": bodyFont.pointSize])
                record["captures"] = captures
            }
            for kind in TowerKind.allCases {
                runner.dismissMenu()
                guard let empty = runner.slotPositions.indices.first(where: { !runner.isSlotOccupied($0) })
                else { throw failure("Missing empty slot") }
                runner.selectSlot(empty)
                let before = runner.money
                runner.tapBuildButton(kind)
                guard runner.money == before, runner.armedBuildKind == kind,
                      let details = runner.menuDetails(for: kind, atLevel: 1)
                else { throw failure("First tap did not select \(kind)") }
                try await capture(details, name: "build-\(kind.rawValue)")
                runner.dismissMenu()
                for level in 1...3 {
                    try runner.prepareTowerUpgradeReview(kind: kind, atLevel: level)
                    let offers = runner.upgradeOffers
                    for offer in offers {
                        runner.tapUpgradeButton(branch: offer.branch)
                        guard let details = runner.menuDetails(for: kind, atLevel: offer.nextLevel, branch: offer.branch)
                        else { throw failure("Missing upgrade description") }
                        try await capture(details, name: "upgrade-\(kind.rawValue)-\(offer.nextLevel)-\(offer.branch)")
                    }
                }
            }
            // Confirm through the same interaction handlers, then ensure the
            // selection label disappears along with the menu.
            runner.tapUpgradeButton(branch: runner.armedUpgradeBranch!)
            try await Task.sleep(for: .milliseconds(250))
            guard runner.armedUpgradeBranch == nil,
                  labels(in: window).allSatisfy({ $0.attributedText?.string.contains("\n") != true })
            else { throw failure("Confirmation retained the label") }
            record["passed"] = true
            record["captures"] = captures
            record["devicePoints"] = [window.bounds.width, window.bounds.height]
            record["safeBounds"] = [canvas.safeInsetsRect.minX, canvas.safeInsetsRect.minY,
                                    canvas.safeInsetsRect.width, canvas.safeInsetsRect.height]
            record["screenScale"] = window.screen.scale
        } catch { record["error"] = error.localizedDescription }
        do {
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { print("Tower label review could not save its result: \(error)") }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "TowerLabelReview", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
#endif
