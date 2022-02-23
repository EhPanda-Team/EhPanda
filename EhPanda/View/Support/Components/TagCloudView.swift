//
//  TagCloudView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/14.
//  Copied from https://stackoverflow.com/questions/62102647/
//

import SwiftUI
import Kingfisher

struct TagCloudView<Element, ID, TagCell>: View
where TagCell: View, Element: Equatable & Identifiable, ID == Element.ID {
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: Double
    private let content: (Element) -> TagCell

    @State private var totalHeight = CGFloat.zero

    init<Data: RandomAccessCollection>(
        data: Data, id: KeyPath<Element, ID> = \Element.id, spacing: Double = 4,
        @ViewBuilder content: @escaping (Element) -> TagCell
    ) where Data.Index == Int, Data.Element == Element {
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.content = content
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
            ForEach(data, id: id) { content in
                self.content(content)
                    .padding([.trailing, .bottom], spacing)
                    .alignmentGuide(.leading, computeValue: { dimensions in
                        if abs(width - dimensions.width) > proxy.size.width {
                            width = 0
                            height -= dimensions.height
                        }
                        let result = width
                        if content == data.last {
                            width = 0 // last item
                        } else {
                            width -= dimensions.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if content == data.last {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader(binding: $totalHeight))
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

struct TagCloudCell: View {
    private let text: String
    private let imageURL: URL?
    private let showsImages: Bool
    private let font: Font
    private let padding: EdgeInsets
    private let textColor: Color
    private let backgroundColor: Color

    init(
        text: String, imageURL: URL?, showsImages: Bool, font: Font,
        padding: EdgeInsets, textColor: Color, backgroundColor: Color
    ) {
        self.text = text
        self.imageURL = imageURL
        self.showsImages = showsImages
        self.font = font
        self.padding = padding
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(showsImages ? text : text.emojisRipped)
            if let imageURL = imageURL, showsImages {
                Image(systemSymbol: .photo).opacity(0)
                    .overlay(KFImage(imageURL).resizable().scaledToFit())
            }
        }
        .font(font.bold()).lineLimit(1).foregroundColor(textColor)
        .padding(padding).background(backgroundColor).cornerRadius(5)
    }
}
