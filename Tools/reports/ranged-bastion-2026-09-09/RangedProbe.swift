import SwiftUI
import UIKit

@MainActor enum RangedProbeState { static var runner: LevelRunner? }

@main struct RangedProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { RangedProbeScreen(store: store) } }
}

private struct RangedProbeScreen: View {
    let store: Store
    @State private var minimum = false
    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_15_charleston" }!
            LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                towerMenuLayout: store.towerMenuLayout, node: node,
                difficulty: try! store.db.difficultyDao.getAll()[0],
                hudLayoutConfig: try! store.db.hudLayoutDao.get(), onExit: {})
                .id(minimum)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                let variants = [(1,1),(2,1),(3,1),(4,1),(4,2),(4,3)]
                var assets: [[String: Any]] = []
                for (level, branch) in variants {
                    let name = TowerKind.ranged.assetName(atLevel: level, branch: branch)!
                    guard let image = UIImage(named: name), image.size == CGSize(width: 136, height: 100) else {
                        throw failure("Missing or incorrectly sized \(name)")
                    }
                    assets.append(["name": name, "points": [image.size.width, image.size.height], "scale": image.scale])
                }
                guard let glyph = UIImage(named: TowerKind.ranged.menuIconName), glyph.size == CGSize(width: 128, height: 128) else {
                    throw failure("Missing musket menu emblem")
                }
                var captures: [[String: Any]] = []
                for small in [false, true] {
                    minimum = small
                    try await Task.sleep(for: .milliseconds(1800))
                    guard let runner = RangedProbeState.runner, runner.isReady, runner.slotPositions.count >= 6 else {
                        throw failure("Charleston runner or six slots unavailable")
                    }
                    runner.prepareRangedArtProbe()
                    let window = keyWindow()
                    let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
                    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                        physicalRect: small ? rect : window.bounds,
                        safeInsetsRect: small ? rect : window.bounds.inset(by: window.safeAreaInsets))
                    let bounds = small ? rect : window.bounds
                    let mode = small ? "minimum" : "device"
                    runner.selectSlot(0)
                    try await Task.sleep(for: .milliseconds(350))
                    try capture("build-menu-\(mode)", window: window, bounds: bounds, directory: directory)
                    runner.dismissMenu()
                    let slots = [0, 1, 5, 3, 4, 2]
                    for (offset, variant) in variants.enumerated() {
                        let slot = slots[offset]
                        runner.selectSlot(slot)
                        runner.tapBuildButton(.ranged)
                        guard runner.placedTower(atSlot: slot) == nil else { throw failure("Build skipped confirmation") }
                        runner.tapBuildButton(.ranged)
                        if variant.0 > 1 {
                            for next in 2...variant.0 {
                                runner.selectPlacedTower(atSlot: slot)
                                let branch = next == 4 ? variant.1 : 1
                                guard runner.upgradeOffers.contains(where: { $0.nextLevel == next && $0.branch == branch }) else {
                                    throw failure("Missing upgrade offer \(next)/\(branch)")
                                }
                                runner.tapUpgradeButton(branch: branch)
                                guard runner.placedTower(atSlot: slot)?.level == next - 1 else { throw failure("Upgrade skipped confirmation") }
                                runner.tapUpgradeButton(branch: branch)
                            }
                        }
                        guard let tower = runner.placedTower(atSlot: slot), tower.level == variant.0, tower.branch == variant.1 else {
                            throw failure("Wrong resulting variant at \(slot)")
                        }
                        runner.dismissMenu()
                    }
                    try await Task.sleep(for: .milliseconds(500))
                    try capture("all-ranged-\(mode)", window: window, bounds: bounds, directory: directory)
                    runner.selectPlacedTower(atSlot: 5)
                    guard runner.upgradeOffers.count == 3 else { throw failure("Expected all three specialist choices") }
                    try await Task.sleep(for: .milliseconds(400))
                    try capture("branch-menu-\(mode)", window: window, bounds: bounds, directory: directory)
                    let side = store.towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: canvas.scaleFactor).width
                    let icon = store.towerMenuLayout.getTowerIconSize(towerButtonSize: side)
                    let height = MapSpriteScale(runtimeCanvas: canvas).points(TowerKind.ranged.spriteHeight)
                    if small && abs(height - 70.0 / 655.0 * 340.0) > 0.001 { throw failure("Unexpected minimum tower size") }
                    for density in [CGFloat(1), 2, 3] {
                        let renderer = ImageRenderer(content: rangedProbeMenuRow(layout: store.towerMenuLayout, side: side))
                        renderer.scale = density
                        guard let bytes = renderer.uiImage?.pngData() else { throw failure("Menu component render failed") }
                        try bytes.write(to: directory.appendingPathComponent("menu-components-\(mode)@\(Int(density))x.png"))
                    }
                    captures.append(["mode": mode, "playableHeight": canvas.playAreaRect.height,
                        "mapTowerHeight": height, "menuButtonSide": side, "menuIconSide": icon,
                        "branchArtHeight": icon / 1.36, "placedCount": runner.placedTowers.count,
                        "allBuildAndUpgradeConfirmationsPassed": true])
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion,
                    "assets": assets, "captures": captures,
                    "fixture": "Temporary app only grants money and ranged unlock level4. Actual build/upgrade actions and production views are used. No physical tap automation."]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("ranged-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("ranged-check.json"), options: .atomic)
            }
        }
    }
}

private func failure(_ message: String) -> NSError { NSError(domain: "RangedProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
@MainActor private func keyWindow() -> UIWindow {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }!
}
@MainActor private func capture(_ name: String, window: UIWindow, bounds: CGRect, directory: URL) throws {
    for density in [CGFloat(1), 2, 3] {
        let format = UIGraphicsImageRendererFormat(); format.scale = density
        let bytes = UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { context in
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try bytes.write(to: directory.appendingPathComponent("\(name)@\(Int(density))x.png"))
    }
}
