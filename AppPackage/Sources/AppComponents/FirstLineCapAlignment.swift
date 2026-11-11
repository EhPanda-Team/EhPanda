public import SwiftUI
import UIKit

extension View {
    /// Centres this view on the middle of the capital letters of the first line of text beside it.
    ///
    /// For a glyph in an `HStack(alignment: .firstTextBaseline)` next to a text block (UI-SPEC C-2, C-3): the
    /// glyph's first-baseline guide is moved to its centre plus half the cap height of `style`, so the stack puts
    /// the glyph's centre half a cap height above the text's first baseline, which is the middle of the capitals.
    /// `style` is the text style of the first line (body for the age wall's sentence, headline for a choice's name).
    /// The cap height scales with Dynamic Type through `ScaledMetric`, so it follows a live size change.
    public func firstLineCapCentered(_ style: Font.TextStyle) -> some View {
        modifier(FirstLineCapCenteredModifier(style: style))
    }
}

private struct FirstLineCapCenteredModifier: ViewModifier {
    /// The cap height of the style's font at the default size (Large); `ScaledMetric` scales it from there.
    @ScaledMetric private var capHeight: CGFloat

    init(style: Font.TextStyle) {
        _capHeight = ScaledMetric(wrappedValue: Self.defaultCapHeight(of: style), relativeTo: style)
    }

    func body(content: Content) -> some View {
        let halfCapHeight = capHeight / 2
        return content.alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center] + halfCapHeight
        }
    }

    private static func defaultCapHeight(of style: Font.TextStyle) -> CGFloat {
        UIFont.preferredFont(
            forTextStyle: style.uiTextStyle,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        ).capHeight
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        case .body: .body
        @unknown default: .body
        }
    }
}
