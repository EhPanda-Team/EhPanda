import AppTools
import Kingfisher
import SFSafeSymbols
import SwiftUI

public struct TagCloudView<Element, ID, TagCell>: View
where TagCell: View, Element: Equatable & Identifiable, ID == Element.ID {
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: Double
    private let content: (Element) -> TagCell

    public init<Data: RandomAccessCollection>(
        data: Data, id: KeyPath<Element, ID> = \Element.id, spacing: Double = 4,
        @ViewBuilder content: @escaping (Element) -> TagCell
    ) where Data.Index == Int, Data.Element == Element {
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(data, id: id) { element in
                content(element)
            }
        }
    }
}

public struct TagCloudCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let text: String
    private let imageURL: URL?
    private let showsImages: Bool
    private let font: Font
    private let padding: EdgeInsets
    private let textColor: Color
    private let backgroundColor: Color

    public init(
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

    /// A chip is a badge, not prose on a line of its own, so its text keeps a budget instead of
    /// losing the cap outright: the designed single line at and below the default size, three lines
    /// above it. A tag whose enlarged text no longer fits the cloud's width then wraps inside its
    /// own background — the cloud's flow layout confines it to that width — instead of running past
    /// the trailing edge, and three lines is enough for the longest tag at the largest size while
    /// still bounding a chip's height.
    private var textLineLimit: Int {
        dynamicTypeSize <= .large ? 1 : 3
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(showsImages ? text : text.emojisRipped)
            if let imageURL = imageURL, showsImages {
                Image(systemSymbol: .photo).opacity(0)
                    .overlay(KFImage(imageURL).resizable().scaledToFit())
            }
        }
        .font(font.bold())
        .lineLimit(textLineLimit)
        // A chip is usually a Button's label, and a Button centres the wrapped lines of its label;
        // a tag that wraps inside its chip reads leading-aligned like every other wrapped text.
        // Single lines, which are all there are at and below the default size, are unaffected.
        .multilineTextAlignment(.leading)
        .foregroundStyle(textColor)
        .padding(padding)
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: 5))
    }
}
