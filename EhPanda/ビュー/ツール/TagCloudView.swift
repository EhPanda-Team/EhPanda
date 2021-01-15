//
//  TagCloudView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/14.
//  Copied from https://stackoverflow.com/questions/62102647/
//

import SwiftUI

struct TagCloudView: View {
    let tag: Tag
    let font: Font
    let textColor: Color
    let backgroundColor: Color
    let paddingV: CGFloat
    let paddingH: CGFloat
    let onTapAction: ((AssociatedKeyword)->())

    @State private var totalHeight
          = CGFloat.zero       // << variant for ScrollView/List
//        = CGFloat.infinity   // << variant for VStack

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)// << variant for ScrollView/List
//        .frame(maxHeight: totalHeight) // << variant for VStack
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.tag.content, id: \.self) { tag in
                self.item(for: tag)
                    .padding([.trailing, .bottom], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width)
                        {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if tag == self.tag.content.last! {
                            width = 0 //last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: {d in
                        let result = height
                        if tag == self.tag.content.last! {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }.background(viewHeightReader($totalHeight))
    }

    private func item(for text: String) -> some View {
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
            .onTapGesture(perform: {
                onTapAction(
                    AssociatedKeyword(
                        category: tag.category.rawValue,
                        content: text
                    )
                )
            })
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}
