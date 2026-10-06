import SwiftUI

/// A common text ramp prevents different title styles from giving the same cover role different sizes.
/// Only artwork growth is bounded; surrounding text keeps the full Dynamic Type range.
@propertyWrapper
public struct GalleryCoverMetrics: DynamicProperty {
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .headline) private var scale: CGFloat = 1
    private let style: GalleryCoverStyle
    private let maximumHeight: CGFloat?

    public init(_ style: GalleryCoverStyle, maximumHeight: CGFloat? = nil) {
        self.style = style
        self.maximumHeight = maximumHeight
    }

    public var wrappedValue: CGSize {
        style.size(scale: scale, displayScale: displayScale, maximumHeight: maximumHeight)
    }
}
