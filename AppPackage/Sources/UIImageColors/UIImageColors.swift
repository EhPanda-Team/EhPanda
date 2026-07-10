import UIKit

/// The dominant colors extracted from an image: a `background` plus three accent
/// slots (`primary`, `secondary`, `detail`) chosen for contrast and distinctness.
///
/// This is an app-owned, clean-room reimplementation of the narrow surface of the
/// former `jathu/UIImageColors` package that EhPanda actually consumes (DEP-02,
/// D-01/D-04/D-05). The color-selection algorithm is preserved verbatim so that
/// `UIImage.getColors(quality:)` returns the same component tuples as the external
/// package did (D-16); only the implementation is modernized (explicit sRGB bitmap
/// sampling, no force unwraps). Final subjective judgment stays with user
/// verification (D-19).
///
/// The slots are implicitly unwrapped to match the historical package API shape:
/// `getColors` always fills every slot (falling back to black/white text), so in
/// practice they are non-nil whenever a non-nil `UIImageColors` is returned.
public struct UIImageColors {
    public var background: UIColor!
    public var primary: UIColor!
    public var secondary: UIColor!
    public var detail: UIColor!

    public init(background: UIColor, primary: UIColor, secondary: UIColor, detail: UIColor) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.detail = detail
    }
}

/// Sampling resolution for `UIImage.getColors`.
///
/// The raw value is the target edge size, in points, the image is scaled down to
/// before its pixels are analyzed; a smaller value trades color accuracy for speed.
/// `.highest` skips scaling and analyzes the image at its native size.
public enum UIImageColorsQuality: CGFloat {
    case lowest = 50
    case low = 100
    case high = 250
    case highest = 0
}
