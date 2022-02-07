//
//  RatingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/29.
//

import SwiftUI

struct RatingView: View {
    private let rawRating: Float

    init(rating: Float) {
        self.rawRating = rating
    }

    var body: some View {
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

struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0.0, through: 5.0, by: 0.5)), id: \.self) {
                RatingView(rating: Float($0)).foregroundStyle(.yellow)
            }
        }
    }
}
