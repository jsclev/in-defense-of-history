import SwiftUI
import UIKit
@main struct HeroMovementProbe: App {
 @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
 private let store = Store()
 var body: some Scene { WindowGroup {
  ScreenGeometryGate(virtualCanvas:store.virtualCanvas) { runtime in
   Text("Checking hero movement").task {
    let level = try! store.db.levelInfoDao.getCampaignLevels(campaignName:"Main").first { $0.mapImageName == "level_15_charleston" }!
    let runner=LevelRunner(db:store.db,virtualCanvas:store.virtualCanvas,runtimeCanvas:runtime,levelInfoID:level.id,mapImageName:level.mapImageName)
    let result=runner.probeHeroMovement()
    let data=try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
    try! data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("movement-results.json"))
   }
  }.statusBarHidden(true).persistentSystemOverlays(.hidden)
 } }
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
