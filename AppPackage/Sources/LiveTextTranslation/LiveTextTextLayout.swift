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
///
/// Each line takes its own width, so the lines can follow the shape of a balloon, and every line is
/// as tall as the text's tallest glyphs need, so the lines keep one pitch however their scripts mix.
struct LiveTextTextLayout {
    /// Halvings of the search for balanced widths: under a 1/1000 of a line's width.
    private static let balanceSteps = 10
    /// The Unicode blocks of Hangul syllables and jamo.
    private static let hangulBlocks: [ClosedRange<unichar>] = [
        0x1100...0x11FF, 0x3130...0x318F, 0xA960...0xA97F, 0xAC00...0xD7FF
    ]

    struct Line {
        let line: CTLine
        /// The line's width without its trailing spaces, which centering ignores.
        let width: Double

        init(_ line: CTLine) {
            self.line = line
            width = CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line)
        }
    }

    /// The height every line of a text is set in, and where its baseline lies.
    private struct LineMetrics {
        /// The distance from a line's top down to its baseline.
        let ascent: Double
        let height: Double

        /// The metrics of `text` set in one line: those of its tallest glyphs.
        init(_ text: NSAttributedString) {
            var ascent = CGFloat.zero
            var descent = CGFloat.zero
            var leading = CGFloat.zero
            CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), &ascent, &descent, &leading)
            self.ascent = ascent
            height = ascent + descent + leading
        }
    }

    let lines: [Line]
    /// The distance from one line's top to the next one's.
    let lineHeight: Double
    /// Whether the text did not fit `maximumHeight` and its last line ends in an ellipsis.
    let isTruncated: Bool
    /// Whether some line ends inside a word, in a language whose words must not break.
    let breaksWord: Bool
    /// The distance from a line's top down to its baseline.
    private let ascent: Double

    var height: Double {
        Double(lines.count) * lineHeight
    }

    /// `text` set in lines `widths` wide in turn, lines past the last width taking it; with a
    /// `maximumHeight`, only the lines that fit, the last of them ending in an ellipsis when text is
    /// left over.
    init(
        text: String,
        style: LiveTextTextStyle,
        fontSize: Double,
        widths: [Double],
        color: LiveTextColor = .black,
        maximumHeight: Double? = nil
    ) {
        let attributed = style.attributedString(text, fontSize: fontSize, color: color)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let metrics = LineMetrics(attributed)
        let ranges = Self.lineRanges(in: typesetter, of: attributed, widths: widths)
        var lines = ranges.map({ Line(CTTypesetterCreateLine(typesetter, $0)) })

        var isTruncated = false
        if let maximumHeight, Double(lines.count) * metrics.height > maximumHeight {
            var keptCount = 1
            while Double(keptCount + 1) * metrics.height <= maximumHeight {
                keptCount += 1
            }
            let lastStart = ranges.dropFirst(keptCount - 1).first?.location ?? 0
            let rest = attributed.attributedSubstring(
                from: NSRange(location: lastStart, length: attributed.length - lastStart)
            )
            let ellipsis = style.attributedString("\u{2026}", fontSize: fontSize, color: color)
            let truncated = CTLineCreateTruncatedLine(
                CTLineCreateWithAttributedString(rest),
                Self.width(ofLine: keptCount - 1, in: widths),
                .end,
                CTLineCreateWithAttributedString(ellipsis)
            )
            lines = Array(lines.prefix(keptCount - 1)) + (truncated.map({ [Line($0)] }) ?? [])
            isTruncated = true
        }

        self.lines = lines
        lineHeight = metrics.height
        ascent = metrics.ascent
        self.isTruncated = isTruncated
        breaksWord = Self.breaksWord(ranges, of: attributed.string as NSString, style: style)
    }

    /// The height every line of `text` is set in at `fontSize`.
    static func lineHeight(of text: String, style: LiveTextTextStyle, fontSize: Double) -> Double {
        LineMetrics(style.attributedString(text, fontSize: fontSize)).height
    }

    /// `widths` narrowed alike as far as they set `text` in as many lines without breaking a word, so
    /// its lines come out even, as lettering's do, rather than leaving a word or two on the last line.
    static func balancedWidths(
        of text: String,
        style: LiveTextTextStyle,
        fontSize: Double,
        widths: [Double]
    ) -> [Double] {
        let attributed = style.attributedString(text, fontSize: fontSize)
        let characters = attributed.string as NSString
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let count = lineRanges(in: typesetter, of: attributed, widths: widths).count
        guard count > 1 else {
            return widths
        }
        func keepsItsLines(at scale: Double) -> Bool {
            let ranges = lineRanges(in: typesetter, of: attributed, widths: widths.map({ $0 * scale }))
            return ranges.count <= count && !breaksWord(ranges, of: characters, style: style)
        }
        var failing = 0.0
        var fitting = 1.0
        for _ in 0..<balanceSteps {
            let middle = (failing + fitting) / 2
            if keepsItsLines(at: middle) {
                fitting = middle
            } else {
                failing = middle
            }
        }
        return widths.map({ $0 * fitting })
    }

    /// The width line `number` is set in, counting from 0: its own, or past the last, the last.
    private static func width(ofLine number: Int, in widths: [Double]) -> Double {
        widths.dropFirst(number).first ?? widths.last ?? 0
    }

    /// Where each line of `text`, which `typesetter` holds, begins and ends when set `widths` wide.
    ///
    /// Korean keeps its words whole, as Korean is set: CoreText, following Unicode, breaks between any
    /// two Hangul syllables, and `NSParagraphStyle`'s `hangulWordPriority` does not reach a typesetter.
    /// A break between two syllables moves back to the line's last space; a line without one keeps it,
    /// as a word wider than a line has to break.
    private static func lineRanges(
        in typesetter: CTTypesetter,
        of text: NSAttributedString,
        widths: [Double]
    ) -> [CFRange] {
        let characters = text.string as NSString
        var ranges = [CFRange]()
        var start = 0
        while start < characters.length {
            var count = CTTypesetterSuggestLineBreak(typesetter, start, width(ofLine: ranges.count, in: widths))
            guard count > 0 else {
                break
            }
            let end = start + count
            if end < characters.length,
               isHangul(characters.character(at: end - 1)),
               isHangul(characters.character(at: end)),
               let space = (start + 1..<end).last(where: { isWhitespace(characters.character(at: $0)) }) {
                count = space + 1 - start
            }
            ranges.append(CFRange(location: start, length: count))
            start += count
        }
        return ranges
    }

    /// Whether a line of `ranges` ends inside a word of `characters`, between two characters that are
    /// not spaces, in a language whose words must not break.
    private static func breaksWord(_ ranges: [CFRange], of characters: NSString, style: LiveTextTextStyle) -> Bool {
        style.separatesWords && ranges.dropLast().contains { range in
            let end = range.location + range.length
            return !isWhitespace(characters.character(at: end - 1)) && !isWhitespace(characters.character(at: end))
        }
    }

    /// Whether `character` is a Hangul syllable or jamo.
    private static func isHangul(_ character: unichar) -> Bool {
        hangulBlocks.contains(where: { $0.contains(character) })
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        Unicode.Scalar(character).map(CharacterSet.whitespacesAndNewlines.contains) ?? false
    }

    /// Draws the lines centered in `area`, in a context whose y axis points down.
    func draw(centeredIn area: CGRect, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        let top = area.minY + (area.height - height) / 2
        for (number, line) in lines.enumerated() {
            context.textPosition = CGPoint(
                x: area.minX + (area.width - line.width) / 2,
                y: top + Double(number) * lineHeight + ascent
            )
            CTLineDraw(line.line, context)
        }
        context.restoreGState()
    }
}
