import UIKit

/// Which way the app's interface is oriented, independent of how the device is physically held.
///
/// Deliberately *interface* orientation rather than `UIDevice.current.orientation`. The device
/// property is backed by motion hardware, reports `.faceUp`/`.faceDown` for a device lying flat,
/// and — the reason this type exists — reads `.unknown` entirely unless something has called
/// `beginGeneratingDeviceOrientationNotifications()`. The interface value needs no accelerometer,
/// answers what the user is actually looking at, and stays correct in iPad Split View, where the
/// window and the device can disagree.
public enum InterfaceOrientation: Equatable, Sendable, CaseIterable {
    case portrait
    case landscape
}

extension InterfaceOrientation {
    /// `nil` for `.unknown` and for any orientation a future SDK adds.
    ///
    /// Failable rather than defaulting to `.portrait`: an absent answer has to stay absent. Folding
    /// it into a real orientation would mean a caller that cannot tell "the interface is upright"
    /// from "nobody knows", and for analytics that is a fabricated data point rather than a missing
    /// one.
    init?(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait, .portraitUpsideDown:
            self = .portrait
        case .landscapeLeft, .landscapeRight:
            self = .landscape
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
