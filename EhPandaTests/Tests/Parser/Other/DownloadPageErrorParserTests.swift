//
//  DownloadPageErrorParserTests.swift
//  EhPandaTests
//

import Kanna
import XCTest
@testable import EhPanda

final class DownloadPageErrorParserTests: XCTestCase, TestHelper {
    func testIPBannedPageMapsToIPBanned() throws {
        let document = try htmlDocument(filename: .ipBanned)

        XCTAssertEqual(
            Parser.parseDownloadPageError(doc: document),
            .ipBanned(.minutes(59, seconds: 48))
        )
    }

    func testNormalGalleryDetailPageDoesNotMapToDownloadError() throws {
        let document = try htmlDocument(filename: .galleryDetail)

        XCTAssertNil(Parser.parseDownloadPageError(doc: document))
    }

    func testAuthenticationRequiredMarkersMapToAuthenticationRequired() throws {
        let document = try XCTUnwrap(
            Kanna.HTML(
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
        )

        XCTAssertEqual(
            Parser.parseDownloadPageError(doc: document),
            .authenticationRequired
        )
    }

    func testNotFoundMarkersMapToNotFound() throws {
        let document = try XCTUnwrap(
            Kanna.HTML(
                html: """
                <html><body><h1>Invalid page</h1><p>Gallery not found.</p><p>Key missing.</p><p>Keep trying.</p></body></html>
                """,
                encoding: .utf8
            )
        )

        XCTAssertEqual(Parser.parseDownloadPageError(doc: document), .notFound)
        XCTAssertEqual(Parser.parseDownloadPageError(content: "Gallery not found"), .notFound)
        XCTAssertEqual(Parser.parseDownloadPageError(content: "Keep trying"), .notFound)
    }

    func testGalleryNotAvailableIsNotHardMappedToDownloadError() {
        XCTAssertNil(Parser.parseDownloadPageError(content: "Gallery Not Available"))
    }
}
