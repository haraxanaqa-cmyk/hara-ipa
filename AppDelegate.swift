import UIKit

/// App entry point. No scene manifest on purpose: a single window keeps the
/// WKWebView alive through rotation, backgrounding and memory warnings.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor(red: 0.043, green: 0.063, blue: 0.094, alpha: 1)
        window.rootViewController = LensWebViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad
            ? .all
            : .allButUpsideDown
    }
}
