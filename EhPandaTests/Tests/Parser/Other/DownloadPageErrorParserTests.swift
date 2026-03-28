//
//  DownloadPageErrorParserTests.swift
//  EhPandaTests
//

import Kanna
import Testing
@testable import EhPanda

struct DownloadPageErrorParserTests: TestHelper {
    @Test
    func testIPBannedPageMapsToIPBanned() throws {
        let document = try htmlDocument(filename: .ipBanned)

        #expect(
            Parser.parseDownloadPageError(doc: document) == .ipBanned(.minutes(59, seconds: 48))
        )
    }

    @Test
    func testNormalGalleryDetailPageDoesNotMapToDownloadError() throws {
        let document = try htmlDocument(filename: .galleryDetail)

        #expect(Parser.parseDownloadPageError(doc: document) == nil)
    }

    @Test
    func testAuthenticationRequiredMarkersMapToAuthenticationRequired() throws {
        let document = try Kanna.HTML(
            html: """
            <html>
              <body>
                <a href="https://forums.e-hentai.org/index.php?act=Login&CODE=00&return=bounce_login.php"></a>
                <img src="https://exhentai.org/img/kokomade.jpg">
                <p>Access to ExHentai.org is restricted.</p>
              </body>
            </html>
            """,
            encoding: .utf8
        )

        #expect(Parser.parseDownloadPageError(doc: document) == .authenticationRequired)
    }

    @Test
    func testNotFoundMarkersMapToNotFound() throws {
        let document = try Kanna.HTML(
            html: """
            <html><body><h1>Invalid page</h1><p>Gallery not found.</p>
            <p>Key missing.</p><p>Keep trying.</p></body></html>
            """,
            encoding: .utf8
        )

        #expect(Parser.parseDownloadPageError(doc: document) == .notFound)
        #expect(Parser.parseDownloadPageError(content: "Gallery not found") == .notFound)
        #expect(Parser.parseDownloadPageError(content: "Keep trying") == .notFound)
    }

    @Test
    func testGalleryNotAvailableIsNotHardMappedToDownloadError() {
        #expect(Parser.parseDownloadPageError(content: "Gallery Not Available") == nil)
    }
}
