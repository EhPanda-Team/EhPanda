public import SFSafeSymbols
public import SwiftUI
import UIKit

extension View {
    /// Puts the top of this glyph level with the top of the capital letters of the first line of text beside it.
    ///
    /// For a glyph in an `HStack(alignment: .firstTextBaseline)` next to a text block (UI-SPEC C-2, C-3, rev 1.8):
    /// the glyph's first-baseline guide is moved to its top plus the cap height of `style`, so the stack puts the
    /// glyph's top one cap height above the text's first baseline, which is the top of the capitals. An SF Symbol
    /// leaves a little empty padding above the circle it draws, so the guide is moved down by that padding as well
    /// (measured by rendering the symbol and finding its first opaque row), and the drawn circle's edge lines up,
    /// not the image frame.
    ///
    /// `style` is the text style of the first line (body for the age wall's sentence, headline for a choice's name).
    /// `symbols` are the system symbols the glyph draws, in the point size of `glyphStyle` at `.large` image scale
    /// (the glyph's own `.font(_:)` and `.imageScale(_:)`); the padding is the largest of theirs, so no symbol ends
    /// up above the capitals. Both the cap height and the padding are taken at the environment's Dynamic Type size,
    /// so they follow a live size change.
    public func firstLineCapTopAligned(
        _ style: Font.TextStyle,
        symbols: [SFSymbol],
        glyphStyle: Font.TextStyle = .title2
    ) -> some View {
        modifier(FirstLineCapTopAlignedModifier(style: style, symbols: symbols, glyphStyle: glyphStyle))
    }
}

private struct FirstLineCapTopAlignedModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let style: Font.TextStyle
    let symbols: [SFSymbol]
    let glyphStyle: Font.TextStyle

    func body(content: Content) -> some View {
        let metrics = FirstLineCapMetrics(
            style: style, symbols: symbols, glyphStyle: glyphStyle, dynamicTypeSize: dynamicTypeSize
        )
        let offset = metrics.baselineOffsetFromTop
        return content.alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[.top] + offset
        }
    }
}

/// The numbers behind the alignment, apart from SwiftUI so a test can check them.
@MainActor struct FirstLineCapMetrics: Equatable {
    /// The cap height of the first line's font at the Dynamic Type size.
    let capHeight: CGFloat
    /// The empty padding between the glyph's frame top and the top of the circle it draws.
    let glyphTopPadding: CGFloat

    /// Where the glyph's first-baseline guide goes, measured down from its frame top: the circle's top is then one
    /// cap height above the text's first baseline.
    var baselineOffsetFromTop: CGFloat { capHeight + glyphTopPadding }

    init(style: Font.TextStyle, symbols: [SFSymbol], glyphStyle: Font.TextStyle, dynamicTypeSize: DynamicTypeSize) {
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.contentSizeCategory)
        capHeight = UIFont.preferredFont(forTextStyle: style.uiTextStyle, compatibleWith: traits).capHeight
        let glyphFont = UIFont.preferredFont(forTextStyle: glyphStyle.uiTextStyle, compatibleWith: traits)
        glyphTopPadding = SymbolInk.topPadding(of: symbols, pointSize: glyphFont.pointSize)
    }
}

/// Measures the padding an SF Symbol leaves above what it draws.
enum SymbolInk {
    /// An alpha at or above this counts as the circle's edge: the visible edge, not its faint anti-aliased fringe.
    private static let edgeAlpha: UInt8 = 128
    /// The scale the symbol is rendered at, high enough for a measure finer than a device pixel.
    private static let renderScale: CGFloat = 12

    private struct Key: Hashable {
        let symbol: SFSymbol
        let pointSize: CGFloat
    }

    @MainActor private static var cache: [Key: CGFloat] = [:]

    /// The padding, in points, between the frame of the stack of `symbols` (centred on one another, as in a
    /// `ZStack`, the frame as tall as the tallest) and the topmost row any of them draws. The most padding of the
    /// symbols, so the lowest drawn edge is the one lined up. 0 for a symbol that cannot be rendered.
    @MainActor static func topPadding(of symbols: [SFSymbol], pointSize: CGFloat) -> CGFloat {
        let sizes = symbols.compactMap({ imageHeight(of: $0, pointSize: pointSize) })
        guard let frameHeight = sizes.max() else { return 0 }
        let paddings = symbols.compactMap { symbol -> CGFloat? in
            guard let height = imageHeight(of: symbol, pointSize: pointSize),
                  let padding = inkPadding(of: symbol, pointSize: pointSize) else { return nil }
            return (frameHeight - height) / 2 + padding
        }
        return paddings.max() ?? 0
    }

    private static func configuration(pointSize: CGFloat) -> UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .large)
    }

    private static func image(of symbol: SFSymbol, pointSize: CGFloat) -> UIImage? {
        UIImage(systemSymbol: symbol, withConfiguration: configuration(pointSize: pointSize))
    }

    private static func imageHeight(of symbol: SFSymbol, pointSize: CGFloat) -> CGFloat? {
        image(of: symbol, pointSize: pointSize)?.size.height
    }

    /// The padding of one symbol inside its own image frame, found by drawing it and taking its first row whose
    /// alpha reaches `edgeAlpha`.
    @MainActor private static func inkPadding(of symbol: SFSymbol, pointSize: CGFloat) -> CGFloat? {
        let key = Key(symbol: symbol, pointSize: pointSize)
        if let cached = cache[key] { return cached }
        guard let image = image(of: symbol, pointSize: pointSize),
              let padding = firstOpaqueRow(of: image).map({ CGFloat($0) / renderScale }) else { return nil }
        cache[key] = padding
        return padding
    }

    private static func firstOpaqueRow(of image: UIImage) -> Int? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = false
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.withTintColor(.black, renderingMode: .alwaysOriginal).draw(at: .zero)
        }
        guard let cgImage = rendered.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drew = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        return (0..<height).first(where: { row in
            alpha[row * width..<(row + 1) * width].contains(where: { $0 >= edgeAlpha })
        })
    }
}

private extension DynamicTypeSize {
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
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
