// Captures production SwiftUI screens in a separate app sandbox. Metal campaign
// rendering is excluded because the simulator SDK does not expose Metal 4.
import SwiftUI
import UIKit

@MainActor final class CaptureDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { .landscape }
}
@main struct CanvasScreenProbe: App {
    @UIApplicationDelegateAdaptor(CaptureDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { CaptureRoot(store: store) } }
}
struct CaptureRoot: View {
    let store: Store
    @State private var index = 0
    @State private var minimum = false
    private let names = ["heroes", "hero-details", "encyclopedia", "settings", "hud-layout", "briefing", "level"]
    var body: some View {
        Group {
            if minimum {
                ScreenCanvas {
                    let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
                    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
                    RuntimeCanvasView(runtimeCanvas: canvas) { screen(canvas) }
                }
            } else {
                ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { canvas in screen(canvas) }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for small in [false, true] {
              minimum = small
              for (i, name) in names.enumerated() {
                index = i
                try? await Task.sleep(for: .milliseconds(900))
                let window = (UIApplication.shared.connectedScenes.first as! UIWindowScene).windows.first!
                for scale in [CGFloat(1), CGFloat(3)] {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = scale
                    let bounds = small ? CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340) : window.bounds
                    let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    try! data.write(to: dir.appendingPathComponent("\(small ? "minimum-" : "")\(name)@\(Int(scale))x.png"))
                }
            }
            }
            try! Data("complete".utf8).write(to: dir.appendingPathComponent("complete.txt"))
        }
    }
    @ViewBuilder private func screen(_ canvas: RuntimeCanvas) -> some View {
        let node = CampaignNode.load(db: store.db)[0]
        switch index {
        case 0: HeroesView(db: store.db, runtimeCanvas: canvas, onExit: {})
        case 1: HeroDetailsView(db: store.db, runtimeCanvas: canvas, hero: try! store.db.heroDao.getAll()[0], onExit: {})
        case 2: EncyclopediaView(runtimeCanvas: canvas, onExit: {})
        case 3: SettingsView(runtimeCanvas: canvas, onConfigureHudLayout: {}, onExit: {})
        case 4: HudLayoutConfigView(db: store.db, runtimeCanvas: canvas, hudLayoutConfig: .standard, onSave: { _ in }, onExit: {})
        case 5: LevelBriefingView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas, node: node, onStart: { _ in })
        default: LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
            towerMenuLayout: store.towerMenuLayout, node: node, difficulty: try! store.db.difficultyDao.getAll()[0],
            hudLayoutConfig: .standard, onExit: {})
        }
    }
}
