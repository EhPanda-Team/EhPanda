//  Copied from https://stackoverflow.com/questions/62102647/
//

import SwiftUI
import Kingfisher
import FoundationExt

struct TagCloudView<Element, ID, TagCell>: View
where TagCell: View, Element: Equatable & Identifiable, ID == Element.ID {
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: Double
    private let content: (Element) -> TagCell

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
        FlowLayout(spacing: spacing) {
            ForEach(data, id: id) { element in
                content(element)
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: Double

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let frames = frames(
            for: subviews,
            maxWidth: proposal.width ?? .infinity
        )
        let size = frames.reduce(CGSize.zero) { size, frame in
            CGSize(
                width: max(size.width, frame.maxX),
                height: max(size.height, frame.maxY)
            )
        }
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = frames(for: subviews, maxWidth: bounds.width)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + frames[index].minX,
                    y: bounds.minY + frames[index].minY
                ),
                proposal: ProposedViewSize(frames[index].size)
            )
        }
    }

    private func frames(for subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var frames = [CGRect]()
        var origin = CGPoint.zero
        var rowHeight = CGFloat.zero
        let maxWidth = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude
        let spacing = CGFloat(spacing)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
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
