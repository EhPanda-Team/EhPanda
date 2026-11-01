import AppTools
public import CoreGraphics

/// Fixed-cover roles share the grid's book proportion and retain their hierarchy at every text size.
public enum GalleryCoverStyle: Sendable {
    case compact
    case standard
    case hero
    case homeCompact
    case homeSlideshow
    case homeFrontPage
    case homeRanking

    public static let aspectRatio: CGFloat = Defaults.ImageSize.coverAspect
    public static let maximumScale: CGFloat = 1.25

    public var baseHeight: CGFloat {
        switch self {
        case .compact: 90
        case .standard: 120
        case .hero: 150
        case .homeCompact: 165
        case .homeSlideshow: 211.75
        case .homeFrontPage: 199.375
        case .homeRanking: 115.5
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
