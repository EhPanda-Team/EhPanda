import CoreText
import Foundation
import NaturalLanguage
import UIKit

/// How a page's translations are set: the system font, semibold, tagged with the translation's
/// language, so CoreText breaks lines by that language's rules and takes CJK glyphs from the font for
/// its region.
///
/// The text is page content, scaled with the page image, so Dynamic Type does not apply to it, as it
/// does not apply to the image.
struct LiveTextTextStyle: Sendable {
    /// Languages written without spaces between words.
    private static let unspacedLanguageCodes: Set<Locale.LanguageCode> = [
        .chinese, .japanese, .thai, .lao, .khmer, .burmese, .cantonese
    ]

    let language: Locale.Language

    /// Where a line of `text` should not end, as UTF-16 offsets inside its words.
    ///
    /// In a language that puts spaces between words, a word runs from space to space. Chinese and
    /// Japanese have no spaces, and CoreText breaks them between any two characters, so a tokenizer
    /// finds their words. The other languages written without spaces have none here, as CoreText
    /// finds their words itself.
    func wordInteriors(of text: String) -> IndexSet {
        var interiors = IndexSet()
        if let tokenizingLanguage {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text
            tokenizer.setLanguage(tokenizingLanguage)
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let word = NSRange(range, in: text)
                if word.length > 1 {
                    interiors.insert(integersIn: word.location + 1..<word.location + word.length)
                }
                return true
            }
        } else if separatesWords {
            let units = Array(text.utf16)
            for (offset, (before, after)) in zip(units, units.dropFirst()).enumerated()
            where !Self.isWhitespace(before) && !Self.isWhitespace(after) {
                interiors.insert(offset + 1)
            }
        }
        return interiors
    }

    /// Whether a line may end inside a word where the words do not fit whole, as Chinese and Japanese
    /// are set, between any two characters, rather than the text leave its shape; in a language that
    /// puts spaces between words, a word broken without a hyphen reads as two.
    var breaksWordsToFit: Bool {
        tokenizingLanguage != nil
    }

    /// Whether the language puts spaces between words.
    private var separatesWords: Bool {
        guard let languageCode = language.languageCode else {
            return true
        }
        return !Self.unspacedLanguageCodes.contains(languageCode)
    }

    /// The language a tokenizer finds the translation's words in, for Chinese and Japanese.
    private var tokenizingLanguage: NLLanguage? {
        switch language.languageCode {
        case .japanese:
            .japanese
        case .chinese, .cantonese:
            Locale.Language(identifier: language.maximalIdentifier).script == .hanTraditional
                ? .traditionalChinese
                : .simplifiedChinese
        default:
            nil
        }
    }

    private static func isWhitespace(_ unit: unichar) -> Bool {
        Unicode.Scalar(unit).map(CharacterSet.whitespacesAndNewlines.contains) ?? false
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
    /// How much narrower than a line, in points, CoreText is asked to break it, to find the break
    /// before its last: less than any glyph is wide.
    private static let narrowing = 0.01

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
    /// Whether some line ends inside a word, as only a word wider than its line makes one.
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
        let interiors = style.wordInteriors(of: text)
        let ranges = Self.lineRanges(in: typesetter, of: attributed, widths: widths, keeping: interiors)
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
        breaksWord = Self.brokenWordCount(ranges, at: interiors) > 0
    }

    /// The height every line of `text` is set in at `fontSize`.
    static func lineHeight(of text: String, style: LiveTextTextStyle, fontSize: Double) -> Double {
        LineMetrics(style.attributedString(text, fontSize: fontSize)).height
    }

    /// `widths` narrowed alike as far as they set `text` in as many lines, breaking no more words, so
    /// its lines come out even, as lettering's do, rather than leaving a word or two on the last line.
    static func balancedWidths(
        of text: String,
        style: LiveTextTextStyle,
        fontSize: Double,
        widths: [Double]
    ) -> [Double] {
        let attributed = style.attributedString(text, fontSize: fontSize)
        let interiors = style.wordInteriors(of: text)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let ranges = lineRanges(in: typesetter, of: attributed, widths: widths, keeping: interiors)
        let brokenWords = brokenWordCount(ranges, at: interiors)
        guard ranges.count > 1 else {
            return widths
        }
        func keepsItsLines(at scale: Double) -> Bool {
            let scaled = widths.map({ $0 * scale })
            let narrowed = lineRanges(in: typesetter, of: attributed, widths: scaled, keeping: interiors)
            return narrowed.count <= ranges.count && brokenWordCount(narrowed, at: interiors) <= brokenWords
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

    /// Where each line of `text`, which `typesetter` holds, begins and ends when set `widths` wide,
    /// none ending at one of `interiors`, inside a word.
    ///
    /// Words stay whole as each script is set: CoreText, following Unicode, breaks Chinese and Japanese
    /// between any two characters, and Korean between any two Hangul syllables, as
    /// `NSParagraphStyle`'s `hangulWordPriority` does not reach a typesetter. A break inside a word
    /// moves back to the latest break CoreText allows before it that is not inside one, so CoreText's
    /// own rules, such as never ending a line on an opening bracket, still hold; a line without one
    /// keeps its break, as a word wider than a line has to break.
    private static func lineRanges(
        in typesetter: CTTypesetter,
        of text: NSAttributedString,
        widths: [Double],
        keeping interiors: IndexSet
    ) -> [CFRange] {
        let length = text.length
        var ranges = [CFRange]()
        var start = 0
        while start < length {
            let count = CTTypesetterSuggestLineBreak(typesetter, start, width(ofLine: ranges.count, in: widths))
            guard count > 0 else {
                break
            }
            var kept = count
            while start + kept < length, interiors.contains(start + kept) {
                let line = Line(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: kept)))
                let earlier = CTTypesetterSuggestLineBreak(typesetter, start, line.width - narrowing)
                guard earlier > 0, earlier < kept else {
                    kept = count
                    break
                }
                kept = earlier
            }
            ranges.append(CFRange(location: start, length: kept))
            start += kept
        }
        return ranges
    }

    /// How many lines of `ranges` end at one of `interiors`, inside a word.
    private static func brokenWordCount(_ ranges: [CFRange], at interiors: IndexSet) -> Int {
        ranges.dropLast().count(where: { interiors.contains($0.location + $0.length) })
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
