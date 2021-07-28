//
//  Placeholder.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI

struct Placeholder: View {
    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        colorScheme == .light
        ? Color(.systemGray4)
        : Color(.systemGray6)
    }

    private let style: PlaceholderStyle

    init(style: PlaceholderStyle) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .activity(let ratio, let cornerRadius):
            ZStack {
                Color(.systemGray5)
                ProgressView()
            }
            .aspectRatio(ratio, contentMode: .fill)
            .cornerRadius(cornerRadius)
        case .progress(let pageNumber, let progress):
            GeometryReader { proxy in
                ZStack {
                    backgroundColor
                    VStack {
                        Text(pageNumber.withoutComma)
                            .fontWeight(.bold)
                            .font(.largeTitle)
                            .foregroundColor(
                                backgroundColor.darker()
                            )
                            .padding(.bottom, 15)
                        ProgressView(progress)
                            .progressViewStyle(.plainLinear)
                            .frame(width: proxy.size.width * 0.5)
                    }
                }
            }
        }
    }
}

enum PlaceholderStyle {
    case activity(ratio: CGFloat, cornerRadius: CGFloat = 5)
    case progress(pageNumber: Int, progress: Progress)
}
