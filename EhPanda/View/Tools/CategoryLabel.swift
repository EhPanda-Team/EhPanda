//
//  CategoryLabel.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/02.
//

import SwiftUI

struct CategoryLabel: View {
    private let text: String
    private let color: Color
    private let insets: EdgeInsets
    private let cornerRadius: CGFloat
    private let corners: UIRectCorner

    init(
        text: String, color: Color,
        insets: EdgeInsets = .init(
            top: 1, leading: 3,
            bottom: 1, trailing: 3
        ),
        cornerRadius: CGFloat = 2,
        corners: UIRectCorner = .allCorners
    ) {
        self.text = text
        self.color = color
        self.insets = insets
        self.cornerRadius = cornerRadius
        self.corners = corners
    }

    var body: some View {
        Text(text)
            .fontWeight(.bold)
            .lineLimit(1)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(insets)
            .background(
                Rectangle()
                    .foregroundStyle(color)
                    .cornerRadius(
                        cornerRadius,
                        corners: corners
                    )
            )
    }
}
