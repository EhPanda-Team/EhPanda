import SwiftUI

/// Shared card geometry keeps the carousel's width ceiling aligned with the rendered card height.
enum HomeSlideshowSizing {
    // Owner-selected reference: the regular portrait card is approximately 751 × 274 points.
    static let maximumAspectRatio: CGFloat = 751 / 274
    static let compactPadding: CGFloat = 20
    static let regularPadding: CGFloat = 26
    static let regularMinimumContentHeight: CGFloat = 222

    static func cardWidth(availableWidth: CGFloat, minimumHeight: CGFloat, showsRichInformation: Bool) -> CGFloat {
        let preferredWidth = availableWidth * (showsRichInformation ? 0.9 : 0.8)
        return max(0, min(preferredWidth, minimumHeight * maximumAspectRatio))
    }
}
