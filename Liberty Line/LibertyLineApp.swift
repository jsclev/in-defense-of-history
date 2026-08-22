import SwiftUI
import UIKit

@main
struct LibertyLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Constants.debugModeKey) private var debugMode = false

    // The composition root: SwiftUI makes exactly one App instance per
    // process, so this is the game's single Db/VirtualCanvas.
    private let store = Store()

    var body: some Scene {
        WindowGroup {
            ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { screen in
                RootView(store: store, screen: screen)
            }
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
//            .border(debugMode ? Color.red : Color.clear, width: debugMode ? 2 : 0)
        }
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
