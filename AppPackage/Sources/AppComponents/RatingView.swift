import AppTools
import SFSafeSymbols
import SwiftUI

public struct RatingView: View {
    private let rawRating: Float

    public init(rating: Float) {
        self.rawRating = rating
    }

    public var body: some View {
        HStack(spacing: 0) {
            if rating == 0.0 {
                ForEach(0..<5) { _ in NotFilledStar() }
            } else if rating == 0.5 {
                ForEach(0..<1) { _ in HalfFilledStar() }
                ForEach(0..<4) { _ in NotFilledStar() }
            } else if rating == 1.0 {
                ForEach(0..<1) { _ in FilledStar() }
                ForEach(0..<4) { _ in NotFilledStar() }
            } else if rating == 1.5 {
                ForEach(0..<1) { _ in FilledStar() }
                ForEach(0..<1) { _ in HalfFilledStar() }
                ForEach(0..<3) { _ in NotFilledStar() }
            } else if rating == 2.0 {
                ForEach(0..<2) { _ in FilledStar() }
                ForEach(0..<3) { _ in NotFilledStar() }
            } else if rating == 2.5 {
                ForEach(0..<2) { _ in FilledStar() }
                ForEach(0..<1) { _ in HalfFilledStar() }
                ForEach(0..<2) { _ in NotFilledStar() }
            } else if rating == 3.0 {
                ForEach(0..<3) { _ in FilledStar() }
                ForEach(0..<2) { _ in NotFilledStar() }
            } else if rating == 3.5 {
                ForEach(0..<3) { _ in FilledStar() }
                ForEach(0..<1) { _ in HalfFilledStar() }
                ForEach(0..<1) { _ in NotFilledStar() }
            } else if rating == 4.0 {
                ForEach(0..<4) { _ in FilledStar() }
                ForEach(0..<1) { _ in NotFilledStar() }
            } else if rating == 4.5 {
                ForEach(0..<4) { _ in FilledStar() }
                ForEach(0..<1) { _ in HalfFilledStar() }
            } else if rating == 5.0 {
                ForEach(0..<5) { _ in FilledStar() }
            }
        }
        // The five symbols are one fact, not five: read separately they are SF Symbol descriptions
        // ("Star Fill, Star Fill, Star Leadinghalf Filled, Star, Star") that make the listener count.
        // One element carries the fact as a label and the half-rounded value the stars draw, so a
        // list cell or the Detail header announces "Rating, 4.5 out of 5" once.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.accessibilityRating)
        .accessibilityValue(.accessibilityRatingValue(rating: rating))
    }
}

extension Color {
    /// The colour every rating star is drawn in (Phase 16 D-28, owner decision `STARS=B`).
    ///
    /// `.yellow` measured 1.51:1 on a white list cell and 1.23:1 on the Home card's gray in light
    /// mode — under the 3:1 a non-text glyph needs — while passing in dark (≥ 12:1) and under
    /// Increase Contrast, where iOS already swaps in its own amber. The light entry is therefore the
    /// darkened `#A38100` (3.69:1 on white, 3.01:1 on the card), the smallest visible departure
    /// from `.yellow` that clears both measured light backgrounds; dark keeps the value `.yellow`
    /// renders (`#FFD600`); the Increase Contrast entries are the system's own yellow variants
    /// (`#A16A00` light, `#FEDF43` dark), so raising contrast never lowers it.
    ///
    /// A colorset rather than a `colorScheme` read: the star is drawn at five call sites across
    /// four modules, and the per-scheme and per-contrast choice belongs in one asset those sites
    /// name, not in five switches that would have to agree. The Home card's *dark* background is a
    /// cover-derived gradient, so the dark ratio there is content-dependent and stays a recorded
    /// caveat; the star group's accessibility value carries the rating regardless.
    public static let ratingStar = Color("RatingStar", bundle: .module)
}

private extension RatingView {
    var rating: Float {
        rawRating.halfRounded
    }

    struct FilledStar: View {
        var body: some View {
            Image(systemSymbol: .starFill)
        }
    }
    struct HalfFilledStar: View {
        var body: some View {
            Image(systemSymbol: .starLeadinghalfFilled)
        }
    }
    struct NotFilledStar: View {
        var body: some View {
            Image(systemSymbol: .star)
        }
    }
}

#Preview("Interactive", traits: .sizeThatFitsLayout) {
    @Previewable @State var rating: Float = 2.5
    VStack(spacing: 16) {
        RatingView(rating: rating).foregroundStyle(Color.ratingStar)
        Slider(value: $rating, in: 0...5, step: 0.5)
    }
    .padding()
}

#Preview("Empty (0)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 0).foregroundStyle(Color.ratingStar)
}

#Preview("Half (2.5)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 2.5).foregroundStyle(Color.ratingStar)
}

#Preview("Full (5)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 5).foregroundStyle(Color.ratingStar)
}
