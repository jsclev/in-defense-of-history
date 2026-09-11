import UIKit

final class ProbeController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { false }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
}

final class ProbeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ProbeController()
        window.makeKeyAndVisible()
        self.window = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let screen = window.screen
            let data: [String: Any] = [
                "window": [window.bounds.width, window.bounds.height],
                "screen": [screen.bounds.width, screen.bounds.height],
                "scale": screen.scale,
                "interfaceOrientation": scene.interfaceOrientation.rawValue,
                "safeInsets": [window.safeAreaInsets.top, window.safeAreaInsets.left,
                               window.safeAreaInsets.bottom, window.safeAreaInsets.right]
            ]
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("geometry.json")
            try! JSONSerialization.data(withJSONObject: data).write(to: url)
        }
    }
}

@main final class ProbeDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Probe", sessionRole: session.role)
        config.delegateClass = ProbeSceneDelegate.self
        return config
    }
}
