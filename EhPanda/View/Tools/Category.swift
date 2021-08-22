//
//  Category.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/02.
//

import SwiftUI

// MARK: CategoryLabel
struct CategoryLabel: View {
    private let text: String
    private let color: Color
    private let font: Font
    private let insets: EdgeInsets
    private let cornerRadius: CGFloat
    private let corners: UIRectCorner

    init(
        text: String, color: Color,
        font: Font = .footnote,
        insets: EdgeInsets = .init(
            top: 1, leading: 3,
            bottom: 1, trailing: 3
        ),
        cornerRadius: CGFloat = 2,
        corners: UIRectCorner = .allCorners
    ) {
        self.text = text
        self.color = color
        self.font = font
        self.insets = insets
        self.cornerRadius = cornerRadius
        self.corners = corners
    }

    var body: some View {
        Text(text)
            .fontWeight(.bold)
            .lineLimit(1)
            .font(font)
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

// MARK: CategoryView
struct CategoryView: View {
    private let bindings: [Binding<Bool>]

    private let gridItems = [
        GridItem(.adaptive(
            minimum: isPadWidth ? 100 : 80, maximum: 100
        ))
    ]
    private var tuples: [(Binding<Bool>, Category)] {
        Category.allCases.enumerated().map { value in
            (bindings[value.offset], value.element)
        }
    }

    init?(bindings: [Binding<Bool>]) {
        guard bindings.count == 10 else { return nil }
        self.bindings = bindings
    }

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.1) { isFiltered, category in
                CategoryCell(
                    isFiltered: isFiltered,
                    category: category
                )
            }
        }
        .padding(.vertical)
    }
}

// MARK: CategoryCell
private struct CategoryCell: View {
    @Binding private var isFiltered: Bool
    private let category: Category

    init(isFiltered: Binding<Bool>, category: Category) {
        _isFiltered = isFiltered
        self.category = category
    }

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(
                    isFiltered
                        ? category.color.opacity(0.3)
                        : category.color
                )
            Text(category.rawValue.localized)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.vertical, 5)
                .lineLimit(1)
        }
        .onTapGesture(perform: onTapGesture)
        .cornerRadius(5)
    }

    private func onTapGesture() {
        isFiltered.toggle()
    }
}
