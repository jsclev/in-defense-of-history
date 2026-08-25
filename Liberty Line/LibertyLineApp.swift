import SwiftUI
import UIKit

@main
struct LibertyLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Constants.debugModeKey) private var debugMode = false

    // The composition root: SwiftUI makes exactly one App instance per
    // process, so this is the game's single Db/VirtualCanvas.
    private let store = Store()
    @State private var runtimeCanvas: RuntimeCanvas?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let runtimeCanvas {
                    RootView(store: store, runtimeCanvas: runtimeCanvas)
                }
            }
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .onAppear {
                runtimeCanvas = measureScreenGeometry()
            }
        }
    }

    private func measureScreenGeometry() -> RuntimeCanvas? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow ?? windowScene.windows.first else {
            return nil
        }
        let physicalRect = CGRect(origin: .zero, size: window.bounds.size)
        let insets = window.safeAreaInsets
        let safeInsetsRect = CGRect(x: insets.left,
                                    y: insets.top,
                                    width: physicalRect.width - insets.left - insets.right,
                                    height: physicalRect.height - insets.top - insets.bottom)
        return RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                              physicalRect: physicalRect,
                              safeInsetsRect: safeInsetsRect)
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
