import SwiftUI

/// Shared card geometry keeps the carousel's width ceiling aligned with the rendered card height.
enum HomeSlideshowSizing {
    // Owner-selected reference: the regular portrait card is approximately 751 × 274 points.
    static let maximumAspectRatio: CGFloat = 751 / 274
    static let compactPadding: CGFloat = 20
    static let regularPadding: CGFloat = 26
    static let regularMinimumContentHeight: CGFloat = 222
    static let cardSpacing: CGFloat = 20
    // VoiceOver leaves the carousel instead of moving to the next card unless that card reaches this
    // far into the scroll view's bounds, whether or not that part is on screen. Measured on iPhone Air,
    // 2026-11-02: 21 points walks all six cards both ways and 20 points does not, at any card width or
    // spacing. Why it depends on this is unknown. Widening the card's accessibility frame or touch
    // shape, wrapping the cards in an accessibility container and posting a layout notification did
    // not help. Keep this a whole number: at 21.5, a phone leaves a card re-entered from outside the
    // carousel 40 points off center until the next flick.
    static let minimumNeighborExposure: CGFloat = 21

    // The width is rounded for VoiceOver too. Measured on 2026-11-02, a fractional width of 669.6 points
    // on iPad mini or 750.6 on the 11-inch iPad leaves a re-entered card 40 points off center, and at
    // 361.8 on a 402-point phone VoiceOver leaves the carousel after one card. Whole points fix both.
    static func cardWidth(availableWidth: CGFloat, minimumHeight: CGFloat, showsRichInformation: Bool) -> CGFloat {
        let preferredWidth = availableWidth * (showsRichInformation ? 0.9 : 0.8)
        return max(0, min(preferredWidth, minimumHeight * maximumAspectRatio)).rounded()
    }

    /// How far the scroll view extends past each side of the available width so that a neighboring
    /// card reaches `minimumNeighborExposure` into its bounds. Zero when the layout already allows it.
    static func viewportOverhang(availableWidth: CGFloat, cardWidth: CGFloat) -> CGFloat {
        let centeringMargin = (availableWidth - cardWidth) / 2
        return max(0, cardSpacing + minimumNeighborExposure - centeringMargin)
    }
}
