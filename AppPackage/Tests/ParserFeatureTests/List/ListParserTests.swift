@testable import AppFeature
import AppModels
import AppTools
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

struct ListParserTests: TestHelper {
    @Test
    func testExample() throws {
        let tuples: [(ListParserTestType, HTMLDocument)] = try ListParserTestType.allCases.compactMap { type in
            (type, try htmlDocument(filename: type.filename))
        }
        #expect(tuples.count == ListParserTestType.allCases.count)

        try tuples.forEach { type, document in
            let galleries = try Parser.parseGalleries(doc: document)
            let uploaders = galleries.compactMap(\.uploader).filter { !$0.isEmpty }
            #expect(galleries.count == type.assertCount, "\(type)")
            if type.hasUploader {
                #expect(uploaders.count == type.assertCount, "\(type)")
            }
        }
    }

    /// A page that yields no galleries and carries an error banner reports the banner's error rather
    /// than rendering as a silent "no results" list.
    @Test
    func testUnparseableListWithErrorBannerThrows() throws {
        let document = try Kanna.HTML(html: """
        <html><body><div class="d"><p>Gallery not found.</p></div></body></html>
        """, encoding: .utf8)

        #expect(throws: AppError.notFound) {
            try Parser.parseGalleries(doc: document)
        }
    }

    /// A structurally valid list page that genuinely has zero rows still parses to an empty list —
    /// only pages carrying an error banner throw.
    @Test
    func testValidEmptyListParsesToEmptyResult() throws {
        let document = try Kanna.HTML(html: """
        <html><body>
        <div class="searchnav">
          <select onchange="document.location='?inline_set=dm_c'">
            <option value="1" selected="selected">Compact</option>
          </select>
        </div>
        <table class="itg glte"></table>
        </body></html>
        """, encoding: .utf8)

        #expect(try Parser.parseGalleries(doc: document).isEmpty)
    }

    @Test
    func testDateSeekNavigation() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try #require(Parser.parseDateSeekNavigation(doc: document, host: Defaults.URL.ehentai))

        #expect(pageNumber.hasNextPage())
        #expect(pageNumber.lastItemTimestamp == "2668517")
        #expect(navigation.newerURL == nil)
        #expect(navigation.olderURL?.absoluteString == "https://e-hentai.org/?next=2668517")
        #expect(DateSeekNavigation.dateFormatter.string(from: navigation.minimumDate) == "2007-03-20")
        #expect(DateSeekNavigation.dateFormatter.string(from: navigation.maximumDate) == "2023-09-08")
    }

    @Test
    func testDateSeekURL() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let navigation = try #require(Parser.parseDateSeekNavigation(doc: document, host: Defaults.URL.ehentai))
        let url = try #require(navigation.seekURL(date: navigation.maximumDate, direction: .older))
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        #expect(queryItems?.first(where: { $0.name == "next" })?.value == "2668517")
        #expect(queryItems?.first(where: { $0.name == "seek" })?.value == "2023-09-08")
        #expect(navigation.seekURL(date: navigation.maximumDate, direction: .newer) == nil)
    }

    @Test
    func testDateSeekNavigationNormalizesExHentaiHost() throws {
        let document = try Kanna.HTML(html: """
        <html>
        <body>
        <script>
        var prevurl="https://e-hentai.org/?prev=123&amp;page=1";
        var nexturl="/?next=456";
        var mindate="2007-03-20";
        var maxdate="2023-09-08";
        </script>
        <div class="searchnav"><a href="https://exhentai.org/?next=456-2668517">Next</a></div>
        </body>
        </html>
        """, encoding: .utf8)

        let navigation = try #require(Parser.parseDateSeekNavigation(doc: document, host: Defaults.URL.exhentai))
        let newerURL = try #require(navigation.newerURL)
        let olderURL = try #require(navigation.olderURL)

        #expect(newerURL.host == "exhentai.org")
        #expect(olderURL.host == "exhentai.org")
        #expect(
            URLComponents(url: newerURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "page" })?
                .value == "1"
        )
        #expect(
            URLComponents(url: olderURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "next" })?
                .value == "456"
        )
    }

    @Test
    func testDateSeekNavigationIsPreservedWithNumericPager() throws {
        let document = try Kanna.HTML(html: """
        <html>
        <body>
        <script>
        var prevurl="https://e-hentai.org/?prev=123";
        var nexturl="https://e-hentai.org/?next=456";
        var mindate="2007-03-20";
        var maxdate="2023-09-08";
        </script>
        <table class="ptt">
          <tr>
            <td><a>1</a></td>
            <td class="ptds">2</td>
            <td><a>3</a></td>
          </tr>
        </table>
        </body>
        </html>
        """, encoding: .utf8)

        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try #require(Parser.parseDateSeekNavigation(doc: document, host: Defaults.URL.ehentai))

        #expect(pageNumber.current == 1)
        #expect(pageNumber.maximum == 2)
        #expect(navigation.newerURL?.absoluteString == "https://e-hentai.org/?prev=123")
        #expect(navigation.olderURL?.absoluteString == "https://e-hentai.org/?next=456")
    }
}
