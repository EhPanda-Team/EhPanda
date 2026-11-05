import AppModels
import Foundation
import Kanna
@testable import ParserFeature
import SwiftUI
import Testing
import TestingSupport

struct GalleryCommentParserTests: TestHelper {
    @Test
    func quoteMarkersAndApostrophesReadAsTyped() throws {
        let runs = try parseRuns("&gt; one<br />&gt; two<br />It&#039;s &quot;three&quot;")
        #expect(runs == [Run(type: .plainText, text: "> one\n> two\nIt's \"three\"")])
    }

    @Test
    func strongTextBesideAnImageKeepsItsStyle() throws {
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
                    text: styled("https://example.com/book\nIf you like please ")
                        + styled("Support the Artist", .bold)
                        + styled("\n\nThanks")
                ),
                Run(type: .singleImg, imgURL: URL(string: "https://ehgt.org/w/cover.webp"))
            ]
        )
    }

    @Test(
        arguments: zip(
            [
                "<strong>word</strong>",
                "<b>word</b>",
                "<em>word</em>",
                "<i>word</i>",
                "<del>word</del>",
                "<s>word</s>",
                "<strike>word</strike>",
                "<u>word</u>",
                "<ins>word</ins>",
                #"<span style="text-decoration:underline;">word</span>"#,
                #"<span style="text-decoration:line-through;">word</span>"#,
                #"<span style="color:#f00">word</span>"#,
                "<font>word</font>"
            ],
            [
                AttributeContainer.bold, .bold, .italic, .italic,
                .strikethrough, .strikethrough, .strikethrough,
                .underline, .underline, .underline, .strikethrough,
                .init(), .init()
            ]
        )
    )
    func elementStylesItsText(markup: String, style: AttributeContainer) throws {
        let runs = try parseRuns("before \(markup) after")
        #expect(runs == [Run(type: .plainText, text: styled("before ") + styled("word", style) + styled(" after"))])
    }

    @Test
    func nestedStylesCombine() throws {
        let runs = try parseRuns(
            #"<strong><em><del><span style="text-decoration:underline;">word</span></del></em></strong>"#
        )
        var all = AttributeContainer()
        all.inlinePresentationIntent = [.stronglyEmphasized, .emphasized]
        all.swiftUI.strikethroughStyle = .single
        all.swiftUI.underlineStyle = .single
        #expect(runs == [Run(type: .plainText, text: styled("word", all))])
    }

    @Test
    func styleEndsWithItsElementAndAcrossLineBreaks() throws {
        let runs = try parseRuns("<strong>one<br />two</strong>three")
        #expect(runs == [Run(type: .plainText, text: styled("one\ntwo", .bold) + styled("three"))])
    }

    @Test
    func spaceBetweenStyledWordsSurvivesUnstyled() throws {
        let runs = try parseRuns("<strong>one</strong> <em>two</em>")
        #expect(runs == [Run(type: .plainText, text: styled("one", .bold) + styled(" ") + styled("two", .italic))])
    }

    @Test
    func trimmingKeepsTheStyleOfWhatRemains() throws {
        let runs = try parseRuns("  <strong> word 😀 </strong>  <br />")
        #expect(runs == [Run(type: .plainText, text: styled("word 😀", .bold))])
    }

    @Test
    func invisibleSpaceAtTheEdgesIsTrimmed() throws {
        let runs = try parseRuns("\u{00A0}word\u{200B}")
        #expect(runs == [Run(type: .plainText, text: "word")])
    }

    /// The shape of a comment on the live site: `[u][url]` around each link, with `[s]` beside them.
    @Test
    func underlinedLinksAndStruckTextReadInOrder() throws {
        let runs = try parseRuns(
            """
            one<span style="text-decoration:underline;"><a href="https://example.com/a">title</a></span>two\
            <del>gone</del>
            """
        )
        #expect(
            runs == [
                Run(type: .plainText, text: "one"),
                Run(type: .linkedText, text: styled("title", .underline), link: URL(string: "https://example.com/a")),
                Run(type: .plainText, text: styled("two") + styled("gone", .strikethrough))
            ]
        )
    }

    @Test
    func styleInsideALinkStaysOnItsWords() throws {
        let runs = try parseRuns(#"<a href="https://example.com/a">plain <em>slanted</em></a>"#)
        #expect(
            runs == [
                Run(
                    type: .linkedText,
                    text: styled("plain ") + styled("slanted", .italic),
                    link: URL(string: "https://example.com/a")
                )
            ]
        )
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
                Run(type: .plainText, text: styled("see", .bold)),
                Run(type: .linkedText, text: styled("this & that", .bold), link: URL(string: "https://example.com/a")),
                Run(type: .plainText, text: styled("now", .bold) + styled(" then"))
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

    /// The site follows the author's link with `&nbsp; &nbsp;` and a forum contact link; the name is only the link's
    /// text, as the block list, the menu labels and the own-comment rule compare names exactly.
    @Test
    func theAuthorCarriesNoSpaceFromTheContactLink() throws {
        let contact = #"&nbsp; &nbsp; <a href="https://forums.e-hentai.org/index.php?showuser=1"><img alt="PM" /></a>"#
        let comment = try #require(Parser.parseComments(doc: document(body: "text", afterAuthor: contact)).first)
        #expect(comment.author == "author")
    }

    /// The contact link carries the poster's member ID, which comment blocking matches on (owner msg 1918).
    @Test
    func theMemberIDComesFromTheContactLink() throws {
        let link = "https://forums.e-hentai.org/index.php?showuser=4764920"
        let contact = #"&nbsp; &nbsp; <a href=""# + link + #""><img alt="PM" /></a>"#
        let comment = try #require(Parser.parseComments(doc: document(body: "text", afterAuthor: contact)).first)
        #expect(comment.authorMemberID == "4764920")
        #expect(comment.author == "author")
    }

    /// No contact link, or one whose `showuser` is not a number, gives no member ID; nor does a link in the text.
    @Test(arguments: [
        "",
        #"&nbsp; &nbsp; <a href="https://forums.e-hentai.org/index.php?showuser=abc">PM</a>"#,
        #"&nbsp; &nbsp; <a href="https://forums.e-hentai.org/index.php?showuser=">PM</a>"#,
        #"&nbsp; &nbsp; <a href="https://example.com/index.php?showuser=12">PM</a>"#
    ])
    func aCommentWithoutAContactLinkHasNoMemberID(afterAuthor: String) throws {
        let body = #"see <a href="https://forums.e-hentai.org/index.php?showuser=99">this</a>"#
        let comment = try #require(Parser.parseComments(doc: document(body: body, afterAuthor: afterAuthor)).first)
        #expect(comment.authorMemberID == nil)
    }

    /// Each comment of a saved gallery page gets its own poster's ID.
    @Test
    func everyCommentOfAPageHasItsPostersID() throws {
        let document = try htmlDocument(filename: .galleryDetail)
        let comments = Parser.parseComments(doc: document)
        #expect(comments.count == 10)
        #expect(comments.allSatisfy({ $0.authorMemberID != nil }))
        let first = try #require(comments.first)
        #expect(first.author == "Pokom")
        #expect(first.authorMemberID == "4764920")
        let roobubba = try #require(comments.first(where: { $0.author == "Roobubba" }))
        #expect(roobubba.authorMemberID == "990213")
        #expect(Set(comments.compactMap(\.authorMemberID)).count == 10)
    }
}

// MARK: Helpers
/// A parsed run without its per-parse `id`, so runs compare by what they show.
private struct Run: Equatable {
    var type: CommentContentType
    var text: AttributedString?
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

private extension AttributeContainer {
    static let bold = {
        var container = AttributeContainer()
        container.inlinePresentationIntent = .stronglyEmphasized
        return container
    }()
    static let italic = {
        var container = AttributeContainer()
        container.inlinePresentationIntent = .emphasized
        return container
    }()
    static let underline = {
        var container = AttributeContainer()
        container.swiftUI.underlineStyle = .single
        return container
    }()
    static let strikethrough = {
        var container = AttributeContainer()
        container.swiftUI.strikethroughStyle = .single
        return container
    }()
}

private func styled(_ text: String, _ style: AttributeContainer = .init()) -> AttributedString {
    AttributedString(text, attributes: style)
}

private func parseRuns(_ body: String) throws -> [Run] {
    try parseComment(body).contents.map(Run.init)
}

private func parseComment(_ body: String) throws -> GalleryComment {
    try #require(Parser.parseComments(doc: document(body: body)).first)
}

/// A page with one comment, in the structure of a saved gallery detail page.
private func document(body: String, afterAuthor: String = "") throws -> any HTMLDocument {
    try Kanna.HTML(
        html: """
        <html><body><div id="cdiv" class="gm"><a name="c1"></a><div class="c1"><div class="c2">\
        <div class="c3">Posted on 18 March 2026, 10:20 by: &nbsp; \
        <a href="https://e-hentai.org/uploader/author">author</a>\(afterAuthor)</div>\
        <div class="c"></div></div><div class="c6" id="comment_1">\(body)</div>\
        <div class="c7" id="cvotes_1" style="display:none"></div></div></div></body></html>
        """,
        encoding: .utf8
    )
}
