import CoreText
import Foundation
import UIKit

/// How a page's translations are set: the system font, semibold, tagged with the translation's
/// language, so CoreText breaks lines by that language's rules and takes CJK glyphs from the font for
/// its region.
///
/// The text is page content, scaled with the page image, so Dynamic Type does not apply to it, as it
/// does not apply to the image.
struct LiveTextTextStyle: Sendable {
    /// Languages written without spaces between words, where a line may break between any two
    /// characters.
    private static let unspacedLanguageCodes: Set<Locale.LanguageCode> = [
        .chinese, .japanese, .thai, .lao, .khmer, .burmese, .cantonese
    ]

    let language: Locale.Language

    /// Whether the language puts spaces between words, so a word must not be broken across lines.
    var separatesWords: Bool {
        guard let languageCode = language.languageCode else {
            return true
        }
        return !Self.unspacedLanguageCodes.contains(languageCode)
    }

    /// The height of a line, as a multiple of the font size.
    var lineHeightRatio: Double {
        let size = 100.0
        return Double(Self.font(size: size).lineHeight) / size
    }

    func attributedString(_ text: String, fontSize: Double, color: LiveTextColor = .black) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: Self.font(size: fontSize),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                    srgbRed: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: 1
                ),
                NSAttributedString.Key(kCTLanguageAttributeName as String): language.minimalIdentifier
            ]
        )
    }

    private static func font(size: Double) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }
}

/// One translation set in lines, the same way for measuring and for drawing, so what fits when
/// measured is exactly what is drawn.
struct LiveTextTextLayout {
    struct Line {
        let line: CTLine
        /// The line's width without its trailing spaces, which centering ignores.
        let width: Double
        let ascent: Double
        let descent: Double
        let leading: Double

        init(_ line: CTLine) {
            var ascent = CGFloat.zero
            var descent = CGFloat.zero
            var leading = CGFloat.zero
            let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            self.line = line
            self.width = width - CTLineGetTrailingWhitespaceWidth(line)
            self.ascent = ascent
            self.descent = descent
            self.leading = leading
        }

        var height: Double {
            ascent + descent + leading
        }
    }

    let lines: [Line]
    let height: Double
    /// Whether the text did not fit `maximumHeight` and its last line ends in an ellipsis.
    let isTruncated: Bool
    /// Whether some word is wider than a line, so a line would break inside it.
    let breaksWord: Bool

    /// `text` set in lines `width` wide; with a `maximumHeight`, only the lines that fit, the last of
    /// them ending in an ellipsis when text is left over.
    init(
        text: String,
        style: LiveTextTextStyle,
        fontSize: Double,
        width: Double,
        color: LiveTextColor = .black,
        maximumHeight: Double? = nil
    ) {
        let attributed = style.attributedString(text, fontSize: fontSize, color: color)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        var lines = [Line]()
        var lineStarts = [Int]()
        var start = 0
        while start < attributed.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, start, width)
            guard count > 0 else {
                break
            }
            lines.append(Line(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))))
            lineStarts.append(start)
            start += count
        }

        var isTruncated = false
        if let maximumHeight, lines.map(\.height).reduce(0, +) > maximumHeight {
            var keptCount = 0
            var keptHeight = 0.0
            for line in lines {
                guard keptHeight + line.height <= maximumHeight else {
                    break
                }
                keptHeight += line.height
                keptCount += 1
            }
            keptCount = Swift.max(keptCount, 1)
            let lastStart = lineStarts.dropFirst(keptCount - 1).first ?? 0
            let rest = attributed.attributedSubstring(
                from: NSRange(location: lastStart, length: attributed.length - lastStart)
            )
            let ellipsis = style.attributedString("\u{2026}", fontSize: fontSize, color: color)
            let truncated = CTLineCreateTruncatedLine(
                CTLineCreateWithAttributedString(rest),
                width,
                .end,
                CTLineCreateWithAttributedString(ellipsis)
            )
            lines = Array(lines.prefix(keptCount - 1)) + (truncated.map({ [Line($0)] }) ?? [])
            isTruncated = true
        }

        self.lines = lines
        height = lines.map(\.height).reduce(0, +)
        self.isTruncated = isTruncated
        breaksWord = style.separatesWords && text
            .split(whereSeparator: \.isWhitespace)
            .contains(where: { word in
                let line = CTLineCreateWithAttributedString(style.attributedString(String(word), fontSize: fontSize))
                return Line(line).width > width
            })
    }

    /// Draws the lines centered in `area`, in a context whose y axis points down.
    func draw(centeredIn area: CGRect, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        var baseline = area.minY + (area.height - height) / 2
        for line in lines {
            baseline += line.ascent
            context.textPosition = CGPoint(x: area.minX + (area.width - line.width) / 2, y: baseline)
            CTLineDraw(line.line, context)
            baseline += line.descent + line.leading
        }
        context.restoreGState()
    }
}
