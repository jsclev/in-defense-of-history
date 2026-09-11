import SwiftUI
import UIKit

@main struct HudStatsRuntimeProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store = Store()
    var body: some Scene {
        WindowGroup {
            ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { canvas in
                ProbeScreen(store: store, canvas: canvas)
            }.statusBarHidden(true).persistentSystemOverlays(.hidden)
        }
    }
}
struct ProbeScreen: View {
    let store: Store
    let canvas: RuntimeCanvas
    var body: some View {
        let node = CampaignNode.load(db: store.db)[0]
        LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
            towerMenuLayout: store.towerMenuLayout, node: node,
            difficulty: try! store.db.difficultyDao.getAll()[0], hudLayoutConfig: .standard, onExit: {})
            .task {
                let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                do {
                    try await Task.sleep(for: .seconds(2))
                    let levels = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
                    var rows: [[String: Any]] = []
                    for (index, level) in levels.enumerated() {
                        let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                            runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName)
                        precondition(runner.isReady)
                        let total = runner.waveCount
                        precondition(total > 0 && runner.currentWaveNumber == 1)
                        if index == 14 { try saveHUD(runner, "start", out) }
                        let numbers = runner.probeWaveProgression()
                        precondition(numbers == Array(1...total))
                        precondition(runner.waveCount == total && runner.currentWaveNumber == total)
                        if index == 14 {
                            runner.probeCounterValues()
                            try saveHUD(runner, "end", out)
                        }
                        rows.append(["level":index+1,"name":level.name,"total":total,"displayedWaveNumbers":numbers])
                        await Task.yield()
                    }
                    if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1
                        let data = UIGraphicsImageRenderer(bounds: window.bounds, format: format).pngData { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        try data.write(to: out.appendingPathComponent("gameplay@1x.png"))
                    }
                    try JSONSerialization.data(withJSONObject:["passed":true,"levels":rows],options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("stats.json"))
                } catch {
                    try? JSONSerialization.data(withJSONObject:["passed":false,"error":String(describing:error)]).write(to:out.appendingPathComponent("stats.json"))
                }
            }
    }
    @MainActor private func saveHUD(_ runner: LevelRunner, _ state: String, _ out: URL) throws {
        for density in [CGFloat(1),2,3] {
            let renderer = ImageRenderer(content: HudStatsView(runtimeCanvas:canvas,runner:runner))
            renderer.scale = density
            try renderer.uiImage!.pngData()!.write(to:out.appendingPathComponent("device-\(state)@\(Int(density))x.png"))
        }
    }
}
