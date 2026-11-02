import AppModels
import Foundation
import Kanna
@testable import ParserFeature
import Testing

struct GalleryCommentParserTests {
    @Test
    func quoteMarkersAndApostrophesReadAsTyped() throws {
        let runs = try parseRuns("&gt; one<br />&gt; two<br />It&#039;s &quot;three&quot;")
        #expect(runs == [Run(type: .plainText, text: "> one\n> two\nIt's \"three\"")])
    }

    @Test
    func strongTextBesideAnImageLosesOnlyItsTags() throws {
        let runs = try parseRuns(
            """
            https://example.com/book<br />If you like please <strong>Support the Artist</strong><br /><br />\
            Thanks<br /><img src="https://ehgt.org/w/cover.webp" />
            """
        )
        #expect(
            runs == [
                Run(
                    type: .plainText,
                    text: "https://example.com/book\nIf you like please Support the Artist\n\nThanks"
                ),
                Run(type: .singleImg, imgURL: URL(string: "https://ehgt.org/w/cover.webp"))
            ]
        )
    }

    @Test(
        arguments: [
            "<strong>word</strong>",
            "<em>word</em>",
            "<u>word</u>",
            "<s>word</s>",
            #"<span style="color:#f00">word</span>"#,
            "<strong><em>word</em></strong>"
        ]
    )
    func inlineFormattingKeepsItsText(markup: String) throws {
        let runs = try parseRuns("before \(markup) after")
        #expect(runs == [Run(type: .plainText, text: "before word after")])
    }

    @Test
    func spaceBetweenFormattedWordsSurvives() throws {
        let runs = try parseRuns("<strong>one</strong> <em>two</em>")
        #expect(runs == [Run(type: .plainText, text: "one two")])
    }

    /// The site escapes what an author types, so escaped markup is the author's own text and must
    /// stay readable as such, and an escaped entity must come out decoded once and no further.
    @Test
    func markupTheAuthorTypedStaysLiteral() throws {
        let runs = try parseRuns("&lt;strong&gt;typed&lt;/strong&gt; &amp;gt; &lt;3 Q&amp;A")
        #expect(runs == [Run(type: .plainText, text: "<strong>typed</strong> &gt; <3 Q&A")])
    }

    @Test
    func linkInsideFormattingSplitsTheTextAroundIt() throws {
        let runs = try parseRuns(
            #"<strong>see <a href="https://example.com/a">this &amp; that</a> now</strong> then"#
        )
        #expect(
            runs == [
                Run(type: .plainText, text: "see"),
                Run(type: .linkedText, text: "this & that", link: URL(string: "https://example.com/a")),
                Run(type: .plainText, text: "now then")
            ]
        )
    }

    @Test
    func repeatedLinksKeepTheirOrderAroundTheirText() throws {
        let link = #"<a href="https://example.com/a">a</a>"#
        let runs = try parseRuns("1.\(link)<br />2.\(link) end")
        let url = URL(string: "https://example.com/a")
        #expect(
            runs == [
                Run(type: .plainText, text: "1."),
                Run(type: .linkedText, text: "a", link: url),
                Run(type: .plainText, text: "2."),
                Run(type: .linkedText, text: "a", link: url),
                Run(type: .plainText, text: "end")
            ]
        )
    }

    @Test
    func adjacentImagesPairUp() throws {
        let runs = try parseRuns(
            """
            <img src="https://example.com/1.png" /><br /><img src="https://example.com/2.png" />\
            <img src="https://example.com/3.png" />
            """
        )
        #expect(
            runs == [
                Run(
                    type: .doubleImg,
                    imgURL: URL(string: "https://example.com/1.png"),
                    secondImgURL: URL(string: "https://example.com/2.png")
                ),
                Run(type: .singleImg, imgURL: URL(string: "https://example.com/3.png"))
            ]
        )
    }

    @Test
    func adjacentLinkedImagesPairUp() throws {
        let runs = try parseRuns(
            """
            <a href="https://example.com/a"><img src="https://example.com/1.png" /></a>\
            <a href="https://example.com/b"><img src="https://example.com/2.png" /></a>
            """
        )
        #expect(
            runs == [
                Run(
                    type: .doubleLinkedImg,
                    link: URL(string: "https://example.com/a"),
                    imgURL: URL(string: "https://example.com/1.png"),
                    secondLink: URL(string: "https://example.com/b"),
                    secondImgURL: URL(string: "https://example.com/2.png")
                )
            ]
        )
    }

    @Test
    func textBetweenImagesKeepsThemApart() throws {
        let runs = try parseRuns(
            #"<img src="https://example.com/1.png" />between<img src="https://example.com/2.png" />"#
        )
        #expect(
            runs == [
                Run(type: .singleImg, imgURL: URL(string: "https://example.com/1.png")),
                Run(type: .plainText, text: "between"),
                Run(type: .singleImg, imgURL: URL(string: "https://example.com/2.png"))
            ]
        )
    }

    @Test
    func anchorWithoutAHrefKeepsItsText() throws {
        let runs = try parseRuns(#"before <a name="top">anchor</a> after"#)
        #expect(runs == [Run(type: .plainText, text: "before anchor after")])
    }

    @Test
    func linkWithoutTextAddsNoRun() throws {
        let runs = try parseRuns(#"<a href="https://example.com/a"> </a>"#)
        #expect(runs.isEmpty)
    }

    @Test
    func nestedDivIsLeftOut() throws {
        let runs = try parseRuns(#"kept<div class="c8">left out <a href="https://example.com/a">a</a></div>"#)
        #expect(runs == [Run(type: .plainText, text: "kept")])
    }

    /// Editing a comment pre-fills the post form from this text, so an escaped entity left in it
    /// would be escaped again by the site when the edit is saved.
    @Test
    func editPrefillCarriesDecodedText() throws {
        let comment = try parseComment("&gt; a &amp; b")
        #expect(comment.plainTextContent == "> a & b")
    }

    @Test
    func parsingLeavesTheDocumentIntact() throws {
        let doc = try document(body: #"text <a href="https://example.com/a">a</a> <div>b</div>"#)
        let first = Parser.parseComments(doc: doc).flatMap(\.contents).map(Run.init)
        let second = Parser.parseComments(doc: doc).flatMap(\.contents).map(Run.init)
        #expect(first.isEmpty == false)
        #expect(first == second)
    }
}

// MARK: Helpers
/// A parsed run without its per-parse `id`, so runs compare by what they show.
private struct Run: Equatable {
    var type: CommentContentType
    var text: String?
    var link: URL?
    var imgURL: URL?
    var secondLink: URL?
    var secondImgURL: URL?
}

private extension Run {
    init(_ content: CommentContent) {
        self.init(
            type: content.type,
            text: content.text,
            link: content.link,
            imgURL: content.imgURL,
            secondLink: content.secondLink,
            secondImgURL: content.secondImgURL
        )
    }
}

private func parseRuns(_ body: String) throws -> [Run] {
    try parseComment(body).contents.map(Run.init)
}

private func parseComment(_ body: String) throws -> GalleryComment {
    try #require(Parser.parseComments(doc: document(body: body)).first)
}

/// A page with one comment, in the structure of a saved gallery detail page.
private func document(body: String) throws -> any HTMLDocument {
    try Kanna.HTML(
        html: """
        <html><body><div id="cdiv" class="gm"><a name="c1"></a><div class="c1"><div class="c2">\
        <div class="c3">Posted on 18 March 2026, 10:20 by: &nbsp; \
        <a href="https://e-hentai.org/uploader/author">author</a></div>\
        <div class="c"></div></div><div class="c6" id="comment_1">\(body)</div>\
        <div class="c7" id="cvotes_1" style="display:none"></div></div></div></body></html>
        """,
        encoding: .utf8
    )
}
