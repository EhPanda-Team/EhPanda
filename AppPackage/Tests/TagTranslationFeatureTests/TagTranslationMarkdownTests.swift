import Testing
import Foundation
import AppModels
@testable import TagTranslationFeature

// Wave 0 parity lock for DEP-03 at the feature boundary (D-07, D-08, D-10). `TagTranslation`'s
// markdown-derived computed properties are the app-level consumers of `MarkdownUtil`; these fixtures
// freeze their current output so the later swift-markdown migration is proven end to end, not just
// at the parser seam. Values echo the parser's current paragraph-only / top-level-text-only behavior.
@Suite
struct TagTranslationMarkdownTests {
    private func tag(
        value: String,
        description: String? = nil,
        linksString: String? = nil
    ) -> TagTranslation {
        TagTranslation(
            namespace: .female,
            key: "example",
            value: value,
            description: description,
            linksString: linksString
        )
    }

    /// A plain value round-trips through `parseTexts`, so `displayValue`/`valuePlainText` echo it.
    @Test
    func plainValueYieldsDisplayAndPlainText() {
        let translation = tag(value: "lolicon")
        #expect(translation.valuePlainText == "lolicon")
        #expect(translation.displayValue == "lolicon")
        #expect(translation.valueImageURL == nil)
    }

    /// When the value carries an image, `valueImageURL` returns the first parsed image URL and
    /// `valuePlainText` is nil (an image-only paragraph has no top-level text run), so `displayValue`
    /// falls back to the raw markdown value.
    @Test
    func imageValueExposesImageURLAndFallsBackToRawDisplay() {
        let markdown = "![cover](https://example.com/tag.png)"
        let translation = tag(value: markdown)
        #expect(translation.valueImageURL == URL(string: "https://example.com/tag.png"))
        #expect(translation.valuePlainText == nil)
        #expect(translation.displayValue == markdown)
    }

    /// `descriptionPlainText` replaces backticks with spaces before parsing (so inline code becomes
    /// plain text) and joins the paragraph text runs. This locks that transformation exactly.
    @Test
    func descriptionPlainTextStripsBackticksAndJoins() {
        let translation = tag(value: "v", description: "use `code` inline")
        #expect(translation.descriptionPlainText == "use  code  inline")
    }

    /// A nil description yields nil plain text and no image URLs.
    @Test
    func nilDescriptionYieldsNilPlainTextAndNoImages() {
        let translation = tag(value: "v")
        #expect(translation.descriptionPlainText == nil)
        #expect(translation.descriptionImageURLs.isEmpty)
    }

    /// Description images are parsed via `parseImages`, returning every valid image URL.
    @Test
    func descriptionImageURLsReturnsParsedImages() {
        let description = "![a](https://example.com/a.png) ![b](https://example.com/b.png)"
        let translation = tag(value: "v", description: description)
        #expect(translation.descriptionImageURLs
            == [URL(string: "https://example.com/a.png"), URL(string: "https://example.com/b.png")])
    }

    /// `links` parses the links string; a nil links string yields an empty array.
    @Test
    func linksParsesLinksStringAndDefaultsToEmpty() {
        let withLinks = tag(value: "v", linksString: "[wiki](https://example.com/wiki)")
        #expect(withLinks.links == [URL(string: "https://example.com/wiki")])
        #expect(tag(value: "v").links.isEmpty)
    }
}
