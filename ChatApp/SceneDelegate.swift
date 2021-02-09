import UIKit
import Applozic
import ApplozicSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        window?.backgroundColor = .white
        window?.makeKeyAndVisible()
        if ALUserDefaultsHandler.isLoggedIn() {
            let vc = UINavigationController(rootViewController: ViewController())
            window?.rootViewController = vc
            print("user is logged in")
        } else {
            let signup = UINavigationController(rootViewController: LoginVC())
            window?.rootViewController = signup
            print("user is not logged in")
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
       
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
 
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
       
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
}
