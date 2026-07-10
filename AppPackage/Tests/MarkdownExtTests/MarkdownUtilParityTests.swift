import Testing
import Foundation
import CommonMarkExt

// Wave 0 parity lock for DEP-03 (D-07, D-08, D-09, D-10). These fixtures freeze the *current*
// `MarkdownUtil` behavior — implemented today on top of SwiftCommonMark inside `CommonMarkExt` —
// so the later swift-markdown migration into a `MarkdownExt` module can be proven identical.
//
// The target is named `MarkdownExtTests` up front (D-09: the external swift-markdown product/target
// is `Markdown`, and the app helper module must be `MarkdownExt`, never a conflicting app-owned
// `Markdown`). For Wave 0 it exercises the current `CommonMarkExt.MarkdownUtil`; the migration
// retargets these same fixtures to `MarkdownExt` without changing the expected values below.
//
// Two current limitations are locked *on purpose* (D-07 keeps them until a fixture documents an
// intended fix): traversal only visits top-level `paragraph` blocks, and within a paragraph only
// top-level `.text` inlines are collected — text nested inside emphasis/strong/code/links is not.
@Suite
struct MarkdownUtilParityTests {
    // MARK: parseTexts

    /// A single plain paragraph yields its one text run.
    @Test
    func parseTextsReturnsPlainParagraphText() {
        #expect(MarkdownUtil.parseTexts(markdown: "Hello world") == ["Hello world"])
    }

    /// Each paragraph block contributes a separate entry, in document order.
    @Test
    func parseTextsSplitsMultipleParagraphs() {
        let markdown = "First paragraph.\n\nSecond paragraph."
        #expect(MarkdownUtil.parseTexts(markdown: markdown) == ["First paragraph.", "Second paragraph."])
    }

    /// Locks the current paragraph-only traversal (D-07): headings are not paragraph blocks, so
    /// their text is intentionally not extracted. This documents a known limitation, not a bug fix.
    @Test
    func parseTextsIgnoresNonParagraphBlocks() {
        #expect(MarkdownUtil.parseTexts(markdown: "# Heading").isEmpty)
    }

    /// Locks the current top-level-`.text`-only inline traversal (D-07): text nested inside strong
    /// emphasis is dropped and the surrounding text is returned as separate runs. Known limitation.
    @Test
    func parseTextsCollectsOnlyTopLevelTextInlines() {
        #expect(MarkdownUtil.parseTexts(markdown: "Bold **word** here") == ["Bold ", " here"])
    }

    // MARK: parseLinks

    /// A single inline link yields its destination URL.
    @Test
    func parseLinksReturnsLinkDestination() {
        #expect(MarkdownUtil.parseLinks(markdown: "[EhPanda](https://ehpanda.app)")
            == [URL(string: "https://ehpanda.app")])
    }

    /// Multiple links in one paragraph are returned in document order.
    @Test
    func parseLinksReturnsAllLinksInOrder() {
        let markdown = "See [a](https://a.example) and [b](https://b.example)."
        #expect(MarkdownUtil.parseLinks(markdown: markdown)
            == [URL(string: "https://a.example"), URL(string: "https://b.example")])
    }

    /// Plain text with no links yields an empty result.
    @Test
    func parseLinksReturnsEmptyWhenNoLinks() {
        #expect(MarkdownUtil.parseLinks(markdown: "no links here").isEmpty)
    }

    // MARK: parseImages

    /// An image whose destination is a full, valid URL is accepted and returned.
    @Test
    func parseImagesAcceptsValidDestinationURL() {
        #expect(MarkdownUtil.parseImages(markdown: "![alt](https://example.com/image.png)")
            == [URL(string: "https://example.com/image.png")])
    }

    /// When the destination is not a valid full URL, a title that *is* a full URL is used instead.
    /// This locks the tag-database convention of stashing the real image URL in the image title.
    @Test
    func parseImagesFallsBackToValidTitleURL() {
        let markdown = "![alt](placeholder \"https://example.com/from-title.png\")"
        #expect(MarkdownUtil.parseImages(markdown: markdown)
            == [URL(string: "https://example.com/from-title.png")])
    }

    /// Security lock (T-01-02-01): URL validation is full-string structured validation. A title that
    /// merely *contains* a URL amid other text is rejected — a partial NSDataDetector match is not
    /// enough — so neither the invalid destination nor the impure title is accepted.
    @Test
    func parseImagesRejectsTitleWithSurroundingText() {
        let markdown = "![alt](placeholder \"prefix https://example.com/x.png suffix\")"
        #expect(MarkdownUtil.parseImages(markdown: markdown).isEmpty)
    }

    /// An image with neither a valid destination URL nor a valid title URL yields nothing.
    @Test
    func parseImagesRejectsInvalidDestinationWithoutTitle() {
        #expect(MarkdownUtil.parseImages(markdown: "![alt](placeholder)").isEmpty)
    }
}
