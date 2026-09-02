import SwiftUI

/// A common text ramp prevents different title styles from giving the same cover role different sizes.
/// Only artwork growth is bounded; surrounding text keeps the full Dynamic Type range.
@propertyWrapper
public struct GalleryCoverMetrics: DynamicProperty {
    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1
    private let style: GalleryCoverStyle

    public init(_ style: GalleryCoverStyle) {
        self.style = style
    }

    public var wrappedValue: CGSize {
        style.size(scale: scale)
    }
}
