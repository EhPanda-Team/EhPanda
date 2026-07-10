import Foundation
import Markdown

/// Markdown parsing helper backed by Apple's `swift-markdown` (`Markdown`).
///
/// This is the single seam that owns the parser dependency: feature modules
/// (`TagTranslationFeature`, `DetailFeature`) consume these functions and never
/// import `Markdown` or touch parser node types directly (D-08, D-09).
///
/// Traversal is deliberately scoped to inline children that sit *directly* under a
/// top-level paragraph block (D-07). Two consequences are intentional and preserved
/// from the previous SwiftCommonMark-backed implementation:
///   1. Non-paragraph blocks (e.g. headings) contribute no text.
///   2. Text nested inside emphasis/strong/code/link inlines is not collected; only
///      the top-level `Text` runs surrounding them are.
/// `swift-markdown`'s `MarkupWalker` descends through the whole tree by default, so
/// the paragraph scope is enforced here by walking children explicitly rather than
/// using a full-descent walker.
public struct MarkdownUtil {
    public static func parseTexts(markdown: String) -> [String] {
        topLevelParagraphInlines(markdown: markdown)
            .compactMap({ $0 as? Text })
            .map(\.string)
    }

    public static func parseLinks(markdown: String) -> [URL] {
        topLevelParagraphInlines(markdown: markdown)
            .compactMap({ $0 as? Link })
            .compactMap(\.destination)
            .compactMap({ URL(string: $0) })
    }

    public static func parseImages(markdown: String) -> [URL] {
        topLevelParagraphInlines(markdown: markdown)
            .compactMap({ $0 as? Image })
            .compactMap { image in
                if let source = image.source, isValidURL(source) {
                    return URL(string: source)
                } else if let title = image.title, isValidURL(title) {
                    return URL(string: title)
                }
                return nil
            }
    }

    /// Inline markup that sits directly under a top-level paragraph block, in document order.
    private static func topLevelParagraphInlines(markdown: String) -> [any Markup] {
        Array(Document(parsing: markdown).children)
            .compactMap({ $0 as? Paragraph })
            .flatMap({ Array($0.children) })
    }

    private static func isValidURL(_ string: String) -> Bool {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ), let match = detector.firstMatch(
            in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)
        ) else { return false }
        return match.range.length == string.utf16.count
    }
}
