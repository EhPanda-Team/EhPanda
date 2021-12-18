//
//  TagCloudView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/14.
//  Copied from https://stackoverflow.com/questions/62102647/
//

import SwiftUI

struct TagCloudView: View {
    private let tag: GalleryTag
    private let font: Font
    private let textColor: Color
    private let backgroundColor: Color
    private let paddingV: CGFloat
    private let paddingH: CGFloat
    private let onTapAction: (String) -> Void
    private let translateAction: ((String) -> String)?

    @State private var totalHeight = CGFloat.zero

    init(
        tag: GalleryTag, font: Font, textColor: Color,
        backgroundColor: Color, paddingV: CGFloat, paddingH: CGFloat,
        onTapAction: @escaping (String) -> Void = { _ in },
        translateAction: ((String) -> String)? = nil
    ) {
        self.tag = tag
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.paddingV = paddingV
        self.paddingH = paddingH
        self.onTapAction = onTapAction
        self.translateAction = translateAction
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
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

    @ViewBuilder
    func item(for text: String) -> some View {
        let (rippedText, wrappedHex) = Parser.parseWrappedHex(string: text)
        let containsHex = wrappedHex != nil
        let textColor = containsHex ? .white : textColor
        let translatedText = translateAction?(rippedText)
        let displayText: String = translatedText == nil ? rippedText : translatedText.forceUnwrapped
        let backgroundColor = containsHex ? Color(hex: wrappedHex.forceUnwrapped) : backgroundColor

        Text(displayText).font(font.bold()).lineLimit(1).foregroundColor(textColor)
            .padding(.vertical, paddingV).padding(.horizontal, paddingH).background(backgroundColor)
            .cornerRadius(5).onTapGesture {
                onTapAction(
                    tag.category == .temp ? "\"\(text)$\"" : tag.namespace.lowercased()
                    + ":" + "\"\(text)$\""
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
