//
//  ListParserTests.swift
//  EhPandaTests
//

import Foundation
import Kanna
import Testing
@testable import EhPanda

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

    @Test
    func testDateSeekNavigation() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try #require(pageNumber.dateSeekNavigation)
        let minimumDate = try #require(navigation.minimumDate)
        let maximumDate = try #require(navigation.maximumDate)

        #expect(pageNumber.hasNextPage())
        #expect(pageNumber.lastItemTimestamp == "2668517")
        #expect(navigation.previousURL == nil)
        #expect(navigation.nextURL?.absoluteString == "https://e-hentai.org/?next=2668517")
        #expect(Self.dateFormatter.string(from: minimumDate) == "2007-03-20")
        #expect(Self.dateFormatter.string(from: maximumDate) == "2023-09-08")
    }

    @Test
    func testDateSeekURL() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try #require(pageNumber.dateSeekNavigation)
        let maximumDate = try #require(navigation.maximumDate)
        let url = try #require(navigation.seekURL(date: maximumDate, direction: .older))
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        #expect(queryItems?.first(where: { $0.name == "next" })?.value == "2668517")
        #expect(queryItems?.first(where: { $0.name == "seek" })?.value == "2023-09-08")
        #expect(navigation.seekURL(date: maximumDate, direction: .newer) == nil)
    }

    @Test
    func testDateSeekNavigationNormalizesExHentaiHost() throws {
        let originalHost: String? = UserDefaultsUtil.value(forKey: .galleryHost)
        UserDefaults.standard.set(GalleryHost.exhentai.rawValue, forKey: AppUserDefaults.galleryHost.rawValue)
        defer {
            if let originalHost {
                UserDefaults.standard.set(originalHost, forKey: AppUserDefaults.galleryHost.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: AppUserDefaults.galleryHost.rawValue)
            }
        }

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

        let navigation = try #require(Parser.parsePageNum(doc: document).dateSeekNavigation)
        let previousURL = try #require(navigation.previousURL)
        let nextURL = try #require(navigation.nextURL)

        #expect(previousURL.host == "exhentai.org")
        #expect(nextURL.host == "exhentai.org")
        #expect(
            URLComponents(url: previousURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "page" })?
                .value == "1"
        )
        #expect(
            URLComponents(url: nextURL, resolvingAgainstBaseURL: false)?
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
        let navigation = try #require(pageNumber.dateSeekNavigation)

        #expect(pageNumber.current == 1)
        #expect(pageNumber.maximum == 2)
        #expect(navigation.previousURL?.absoluteString == "https://e-hentai.org/?prev=123")
        #expect(navigation.nextURL?.absoluteString == "https://e-hentai.org/?next=456")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
