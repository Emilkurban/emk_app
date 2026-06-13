import UIKit
import Flutter

class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        (UIApplication.shared.delegate as! FlutterAppDelegate).window = window
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
