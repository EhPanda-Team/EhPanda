public import AppModels
import AppTools
import Kingfisher
import Resources
import SFSafeSymbols
public import SwiftUI

public struct TagCloudView<Element, ID, TagCell>: View
where TagCell: View, Element: Equatable & Identifiable, ID == Element.ID {
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: Double
    private let content: (Element) -> TagCell

    public init<Data: RandomAccessCollection>(
        data: Data, id: KeyPath<Element, ID> = \Element.id, spacing: Double = 4,
        @ContentBuilder content: @escaping (Element) -> TagCell
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
    /// The My Tags highlight of a tag in an enabled tag set, nil for any other tag.
    private let myTag: MyTagHighlight?

    public init(
        text: String, imageURL: URL?, showsImages: Bool, font: Font,
        padding: EdgeInsets, textColor: Color, backgroundColor: Color, myTag: MyTagHighlight? = nil
    ) {
        self.text = text
        self.imageURL = imageURL
        self.showsImages = showsImages
        self.font = font
        self.padding = padding
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.myTag = myTag
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

    /// The label. A tag in My Tags carries its state's symbol, Bold like the label, inside the same `Text`, so the
    /// symbol wraps and truncates with it: `eye` watched, `eye.slash` hidden, `tag` otherwise, in the tag's colour as
    /// the user picked it, else the label's. The chip keeps its own colours. VoiceOver reads the label and then a
    /// watched or hidden tag's state, never the symbol (port of PR 462 item 10, design approved 2026-11-22).
    @ContentBuilder private var label: some View {
        let title = showsImages ? text : text.emojisRipped
        if let myTag {
            let marked = Text(Self.markedKey(title, symbol: Self.symbol(of: myTag))).accessibilityLabel(title)
            if let state = myTag.kind.accessibilityState {
                marked.accessibilityValue(state)
            } else {
                marked
            }
        } else {
            Text(title)
        }
    }

    private static func symbol(of myTag: MyTagHighlight) -> Text {
        let symbol = Text(Image(systemSymbol: myTag.kind.symbol))
        guard let color = myTag.color else { return symbol }
        return symbol.foregroundStyle(color.color)
    }

    /// `symbol` and `label` in one `Text`, a space apart. The key is built from its interpolation in code: the literal
    /// `"\(symbol) \(label)"` would have Xcode extract a `%@ %@` catalog key with nothing to translate, which is why
    /// `SuggestionCell` builds its label in code too.
    private static func markedKey(_ label: String, symbol: Text) -> LocalizedStringKey {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 1, interpolationCount: 2)
        interpolation.appendInterpolation(symbol)
        interpolation.appendLiteral(" ")
        interpolation.appendInterpolation(Text(verbatim: label))
        return LocalizedStringKey(stringInterpolation: interpolation)
    }

    public var body: some View {
        HStack(spacing: 2) {
            label
            if let imageURL = imageURL, showsImages {
                // The chip's text is what names it; the tag image is decoration, and the spacer
                // that reserves its space would otherwise be announced by its symbol name.
                Image(systemSymbol: .photo).opacity(0)
                    .overlay {
                        KFImage(imageURL).resizable().scaledToFit()
                    }
                    .accessibilityHidden(true)
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

extension MyTagKind {
    /// The symbol a tag of this kind carries in a chip.
    fileprivate var symbol: SFSymbol {
        switch self {
        case .flagged: .tag
        case .watched: .eye
        case .hidden: .eyeSlash
        }
    }

    /// What VoiceOver reads after the label; a tag that is neither watched nor hidden reads nothing more.
    fileprivate var accessibilityState: LocalizedStringResource? {
        switch self {
        case .flagged: nil
        case .watched: .RLocalizable.myTagsStateWatched
        case .hidden: .RLocalizable.myTagsStateHidden
        }
    }
}
