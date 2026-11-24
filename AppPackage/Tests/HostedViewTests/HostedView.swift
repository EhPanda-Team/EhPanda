import Foundation
import SwiftUI
import Testing
import UIKit

/// A SwiftUI view in a window of its own, in the host app's foreground scene.
///
/// The tests of this target need what a view only has inside a window: the UIKit views a `List` builds, and
/// accessibility elements with their frames. A window belongs to a scene, and only a process inside the app has one.
/// A package test target runs in a bare test process, where the one way to make a window was the scene-less
/// `UIWindow(frame:)`, deprecated since iOS 26 and banned by the `no_sceneless_window` lint rule. So every test that
/// needs a window lives in this target, which runs inside the app.
@MainActor
enum HostedView {
    /// Lays `view` out in a window of `size`, gives it a moment to settle, and hands its root view to `body`. The
    /// window is hidden again when `body` returns.
    static func withRoot<Result>(
        of view: some View, size: CGSize, _ body: (UIView) throws -> Result
    ) throws -> Result {
        let controller = UIHostingController(rootView: view)
        let window = try UIWindow(windowScene: foregroundScene())
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: .now.addingTimeInterval(0.2))
        return try body(controller.view)
    }

    /// The size of the host app's foreground scene, which is the size a screen has on the device: a window of this
    /// size has the device's safe area.
    static func sceneSize() throws -> CGSize {
        try foregroundScene().coordinateSpace.bounds.size
    }

    /// The host app's foreground scene. The app may still be launching when the first test starts, so the main run
    /// loop is turned until the scene is active, for at most `timeout` seconds.
    private static func foregroundScene(timeout: TimeInterval = 30) throws -> UIWindowScene {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while activeScene == nil, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return try #require(activeScene, "The host app has no foreground scene.")
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
    }
}
