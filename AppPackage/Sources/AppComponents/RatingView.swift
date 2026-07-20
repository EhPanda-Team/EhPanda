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
    }
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
        RatingView(rating: rating).foregroundStyle(.yellow)
        Slider(value: $rating, in: 0...5, step: 0.5)
    }
    .padding()
}

#Preview("Empty (0)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 0).foregroundStyle(.yellow)
}

#Preview("Half (2.5)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 2.5).foregroundStyle(.yellow)
}

#Preview("Full (5)", traits: .sizeThatFitsLayout) {
    RatingView(rating: 5).foregroundStyle(.yellow)
}
