import CoreGraphics

/// Fixed-cover roles share one proportion and retain their hierarchy at every text size.
/// Masonry artwork deliberately uses its own image-driven aspect ratio.
public enum GalleryCoverStyle: Sendable {
    case compact
    case standard
    case hero

    public static let aspectRatio: CGFloat = 8 / 11
    public static let maximumScale: CGFloat = 1.25

    public var baseHeight: CGFloat {
        switch self {
        case .compact: 90
        case .standard: 120
        case .hero: 150
        }
    }

    /// Round height first, then derive and round width, always resolving ties away from zero.
    /// Integral device-pixel dimensions keep the same role the same size in different rows. A half-pixel
    /// height otherwise alternates between two rendered heights as SwiftUI rounds its positioned edges.
    /// Maximum-height constraints share this rule so a constrained carousel cannot restore fractional pixels.
    public func size(scale: CGFloat, displayScale: CGFloat, maximumHeight: CGFloat? = nil) -> CGSize {
        precondition(displayScale.isFinite && displayScale > 0)
        let nominalHeight = baseHeight * min(max(scale, 1), Self.maximumScale)
        let height = min(nominalHeight, max(0, maximumHeight ?? nominalHeight))
        let heightPixels = (height * displayScale).rounded(.toNearestOrAwayFromZero)
        let widthPixels = (heightPixels * Self.aspectRatio).rounded(.toNearestOrAwayFromZero)
        return CGSize(width: widthPixels / displayScale, height: heightPixels / displayScale)
    }
}
