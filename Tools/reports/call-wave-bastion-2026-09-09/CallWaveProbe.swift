import SwiftUI
import UIKit

@main struct CallWaveProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { CallWaveProbeScreen(store: store) } }
}

private let callWaveFixturePoints = [Point(1200, 1100), Point(1434, 1100), Point(1668, 1100)]

private struct CallWaveProbeScreen: View {
    let store: Store
    @State private var minimum = false
    @State private var fixtures = false
    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            Group {
                if fixtures {
                    let art = LevelMapArt(mapImageName: "level_15_charleston")
                    let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
                    ZStack(alignment: .topLeading) {
                        art.underlay(in: projection)
                        art.forestOcclusion(in: projection)
                        art.occlusion(in: projection)
                        ForEach(0..<3) { index in
                            CallWaveButtonView(layout: CallWaveButtonLayout(position: callWaveFixturePoints[index], runtimeCanvas: canvas),
                                waveNumber: index == 0 ? 1 : 2,
                                countdownSeconds: index == 0 ? nil : (index == 1 ? 13 : 1), action: {})
                        }
                    }
                } else {
                    let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_15_charleston" }!
                    LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                        towerMenuLayout: store.towerMenuLayout, node: node,
                        difficulty: try! store.db.difficultyDao.getAll()[0],
                        hudLayoutConfig: try! store.db.hudLayoutDao.get(), onExit: {})
                }
            }
            .id("\(minimum)-\(fixtures)")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                guard let image = UIImage(named: CallWaveButtonLayout.imageName), image.size == CGSize(width: 128, height: 128) else {
                    throw NSError(domain: "CallWaveProbe", code: 1)
                }
                var captures: [[String: Any]] = []
                let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
                let smallCanvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
                for small in [false, true] {
                    minimum = small
                    try await Task.sleep(for: .milliseconds(1600))
                    let window = keyWindow()
                    let canvas = small ? smallCanvas : RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                        physicalRect: window.bounds, safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
                    let layout = CallWaveButtonLayout(position: callWaveFixturePoints[1], runtimeCanvas: canvas)
                    guard abs(layout.frame.width - 44) < 0.01 else { throw NSError(domain: "CallWaveProbe", code: 2) }
                    for density in [CGFloat(1), 2, 3] {
                        let bounds = small ? rect : window.bounds
                        let file = "charleston-\(small ? "minimum" : "device")@\(Int(density))x.png"
                        try screenshot(window: window, bounds: bounds, density: density).write(to: directory.appendingPathComponent(file))
                        captures.append(["file": file, "points": [bounds.width, bounds.height], "density": density,
                            "buttonPoints": layout.frame.width, "pulsePoints": [layout.frame.width * 0.94, layout.frame.width * 1.08],
                            "countdownFontPoints": layout.countdownFontSize])
                    }
                }
                try saveStaticButtons(canvas: smallCanvas, directory: directory)
                let transition = try checkManualWaveStart(store: store, canvas: smallCanvas)
                fixtures = true
                try await Task.sleep(for: .milliseconds(900))
                let window = keyWindow()
                let frames = callWaveFixturePoints.map { CallWaveButtonLayout(position: $0, runtimeCanvas: smallCanvas).frame }
                let crop = frames.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -15, dy: -18)
                for density in [CGFloat(1), 2, 3] {
                    try screenshot(window: window, bounds: crop, density: density)
                        .write(to: directory.appendingPathComponent("countdown-row@\(Int(density))x.png"))
                }
                var pulseFrames: [[String: Any]] = []
                let start = CACurrentMediaTime()
                for index in 0..<16 {
                    let file = String(format: "pulse-%02d@1x.png", index)
                    try screenshot(window: window, bounds: crop, density: 1).write(to: directory.appendingPathComponent(file))
                    pulseFrames.append(["file": file, "elapsedSeconds": CACurrentMediaTime() - start])
                    try await Task.sleep(for: .milliseconds(100))
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID", "device": UIDevice.current.model,
                    "systemVersion": UIDevice.current.systemVersion, "assetLogicalSize": [image.size.width, image.size.height],
                    "captures": captures, "manualStart": transition, "pulseFrames": pulseFrames,
                    "countdownFixtures": ["manual/no badge", "13s (maximum authored countdown)", "1s"]]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("call-wave-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("call-wave-check.json"), options: .atomic)
            }
        }
    }
}

@MainActor private func keyWindow() -> UIWindow {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }!
}

@MainActor private func screenshot(window: UIWindow, bounds: CGRect, density: CGFloat) -> Data {
    let format = UIGraphicsImageRendererFormat(); format.scale = density
    return UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { context in
        context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
}

@MainActor private func saveStaticButtons(canvas: RuntimeCanvas, directory: URL) throws {
    let play = canvas.virtualCanvas.playAreaRect
    let point = Point(play.minX + 22 / canvas.scaleFactor, play.maxY - 22 / canvas.scaleFactor)
    let layout = CallWaveButtonLayout(position: point, runtimeCanvas: canvas)
    for value in [nil, Int?(13), Int?(1)] {
        for density in [CGFloat(1), 2, 3] {
            let content = CallWaveButtonView(layout: layout, waveNumber: value == nil ? 1 : 2,
                countdownSeconds: value, action: {}).frame(width: 44, height: 44)
            let renderer = ImageRenderer(content: content); renderer.scale = density
            guard let bytes = renderer.uiImage?.pngData() else { throw NSError(domain: "CallWaveProbe", code: 3) }
            let state = value.map { "\($0)s" } ?? "ready"
            try bytes.write(to: directory.appendingPathComponent("call-wave-minimum-\(state)@\(Int(density))x.png"))
        }
    }
}

@MainActor private func checkManualWaveStart(store: Store, canvas: RuntimeCanvas) throws -> [String: Any] {
    let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_15_charleston" }!
    let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
        levelInfoID: node.levelInfoID, mapImageName: node.mapImageName)
    guard runner.isReady && runner.awaitingWaveStart && runner.nextWaveNumber == 1 else { throw NSError(domain: "CallWaveProbe", code: 4) }
    let money = runner.money
    runner.startNextWave()
    guard !runner.awaitingWaveStart && runner.nextWaveNumber == 2 && runner.money == money else { throw NSError(domain: "CallWaveProbe", code: 5) }
    runner.startNextWave()
    guard runner.nextWaveNumber == 2 && runner.money == money else { throw NSError(domain: "CallWaveProbe", code: 6) }
    return ["passed": true, "firstCallStartsWaveOnce": true, "prematureRepeatedCallIgnored": true,
        "note": "Invoked the real runner action; this is not a physical double-tap gesture test."]
}
