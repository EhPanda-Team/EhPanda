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

    public func size(scale: CGFloat) -> CGSize {
        let height = baseHeight * min(max(scale, 1), Self.maximumScale)
        return CGSize(width: height * Self.aspectRatio, height: height)
    }
}
