//
//  TagCloudView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/14.
//  Copied from https://stackoverflow.com/questions/62102647/
//

import SwiftUI

struct TagCloudView: View {
    private let tag: MangaTag
    private let font: Font
    private let textColor: Color
    private let backgroundColor: Color
    private let paddingV: CGFloat
    private let paddingH: CGFloat
    private let onTapAction: (String) -> Void

    @State private var totalHeight
          = CGFloat.zero       // << variant for ScrollView/List
//        = CGFloat.infinity   // << variant for VStack

    init(
        tag: MangaTag,
        font: Font,
        textColor: Color,
        backgroundColor: Color,
        paddingV: CGFloat,
        paddingH: CGFloat,
        onTapAction: @escaping
            (String) -> Void = { _ in }
    ) {
        self.tag = tag
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.paddingV = paddingV
        self.paddingH = paddingH
        self.onTapAction = onTapAction
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight) // << variant for ScrollView/List
//        .frame(maxHeight: totalHeight) // << variant for VStack
    }
}

private extension TagCloudView {
    func generateContent(in proxy: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            var width = CGFloat.zero
            var height = CGFloat.zero
            ForEach(tag.content, id: \.self) { tag in
                item(for: tag)
                    .padding([.trailing, .bottom], 4)
                    .alignmentGuide(.leading, computeValue: { dimensions in
                        if abs(width - dimensions.width) > proxy.size.width {
                            width = 0
                            height -= dimensions.height
                        }
                        let result = width
                        if tag == self.tag.content.last {
                            width = 0 // last item
                        } else {
                            width -= dimensions.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if tag == self.tag.content.last {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader(binding: $totalHeight))
    }

    func item(for text: String) -> some View {
        Text(text)
            .fontWeight(.bold)
            .lineLimit(1)
            .font(font)
            .foregroundColor(textColor)
            .padding(.vertical, paddingV)
            .padding(.horizontal, paddingH)
            .background(
                Rectangle()
                    .foregroundColor(backgroundColor)
            )
            .cornerRadius(5)
            .onTapGesture {
                onTapAction(
                    tag.category.rawValue + ":" + text
                )
            }
    }

    func viewHeightReader(binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}
