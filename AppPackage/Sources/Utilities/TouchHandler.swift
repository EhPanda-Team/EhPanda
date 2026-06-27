import UIKit

public final class TouchHandler: NSObject, UIGestureRecognizerDelegate {
    public static let shared = TouchHandler()
    public var currentPoint: CGPoint?

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        currentPoint = touch.location(in: touch.window)
        return false
    }
}
