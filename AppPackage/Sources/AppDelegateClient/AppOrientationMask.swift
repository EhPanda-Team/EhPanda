import UIKit
import Utilities

/// The app's current supported-interface-orientation mask. The orientation lock is
/// owned by the orientation-setting client (written through `AppDelegateClient`), and
/// the app delegate reads this back from `application(_:supportedInterfaceOrientationsFor:)`.
@MainActor
public enum AppOrientationMask {
    public static var current: UIInterfaceOrientationMask =
        DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]
}
