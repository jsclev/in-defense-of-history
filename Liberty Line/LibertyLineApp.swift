import SwiftUI
import UIKit

@main
struct LibertyLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The composition root: SwiftUI makes exactly one App instance per
    // process, so this is the game's single Db/VirtualCanvas.
    private let store = Store()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if CommandLine.arguments.contains("--tower-label-review") {
                    ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { canvas in
                        TowerLabelDeviceReview(store: store, canvas: canvas)
                    }
                    .statusBarHidden(true)
                    .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--engineer-review") {
                    EngineerDeviceReview(store: store)
                        .statusBarHidden(true)
                        .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--sapper-playground") {
                    ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { runtimeCanvas in
                        SapperPlaygroundView(store: store, runtimeCanvas: runtimeCanvas)
                    }
                    .statusBarHidden(true)
                    .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--demolition-haptics-review") {
                    DemolitionHapticsDeviceReview(store: store)
                        .statusBarHidden(true)
                        .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--demolition-review")
                            || CommandLine.arguments.contains("--demolition-ui-review")
                            || CommandLine.arguments.contains("--artillery-menu-review")
                            || CommandLine.arguments.contains("--demolition-interaction-review")
                            || CommandLine.arguments.contains("--demolition-auto-review")
                            || CommandLine.arguments.contains("--demolition-ready-review") {
                    DemolitionDeviceReview(store: store)
                        .statusBarHidden(true)
                        .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--combat-review") {
                    CombatDeviceReview(store: store)
                        .statusBarHidden(true)
                        .persistentSystemOverlays(.hidden)
                } else if CommandLine.arguments.contains("--morale-review") {
                    MoraleDeviceReview(store: store)
                        .statusBarHidden(true)
                        .persistentSystemOverlays(.hidden)
                } else {
                    gameRoot
                }
                #else
                gameRoot
                #endif
            }
            .environmentObject(store.settings)
        }
    }

    private var gameRoot: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { runtimeCanvas in
            RootView(store: store, runtimeCanvas: runtimeCanvas)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

}

@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    private(set) var allowed: UIInterfaceOrientationMask = .landscape

    func allow(_ mask: UIInterfaceOrientationMask) {
        guard mask != allowed else { return }
        allowed = mask
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationLock.shared.allowed }
    }
}
