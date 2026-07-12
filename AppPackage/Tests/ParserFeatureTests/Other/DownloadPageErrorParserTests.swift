import TestingSupport
import Kanna
import AppModels
import Testing
import ParserFeature
import NetworkingFeature
@testable import AppFeature

struct DownloadPageErrorParserTests: TestHelper {
    @Test
    func testIPBannedPageMapsToIPBanned() throws {
        let document = try htmlDocument(filename: .ipBanned)

        #expect(
            Parser.parseResponseError(doc: document) == .ipBanned(.minutes(59, seconds: 48))
        )
    }

    @Test
    func testNormalGalleryDetailPageDoesNotMapToDownloadError() throws {
        let document = try htmlDocument(filename: .galleryDetail)

        #expect(Parser.parseResponseError(doc: document) == nil)
    }

    @Test
    func testNormalParserFixturesDoNotMapToResponseError() throws {
        for type in ListParserTestType.allCases {
            let document = try htmlDocument(filename: type.filename)
            #expect(Parser.parseResponseError(doc: document) == nil)
        }

        for filename in [
            HTMLFilename.galleryDetail,
            .galleryDetailWithGreeting,
            .galleryMPVKeys,
            .galleryNormalImageURL,
            .ehSetting
        ] {
            let document = try htmlDocument(filename: filename)
            #expect(Parser.parseResponseError(doc: document) == nil)
        }
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

        #expect(Parser.parseResponseError(doc: document) == .authenticationRequired)
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

        #expect(Parser.parseResponseError(doc: document) == .notFound)
        #expect(Parser.parseResponseError(content: "Gallery not found") == .notFound)
        #expect(Parser.parseResponseError(content: "Keep trying") == .notFound)
    }

    @Test
    func testGalleryNotAvailableIsNotHardMappedToDownloadError() {
        #expect(Parser.parseResponseError(content: "Gallery Not Available") == nil)
    }

    @Test
    func testMapAppErrorUsesResponseErrorFromParserFailure() async throws {
        let document = try htmlDocument(filename: .ipBanned)
        do {
            try await FailingHTMLRequest(document: document).response()
            Issue.record("Expected response parser to map the IP ban failure.")
        } catch {
            #expect(error == .ipBanned(.minutes(59, seconds: 48)))
        }
    }
}

private struct FailingHTMLRequest: Request {
    let document: HTMLDocument

    func response() async throws(AppError) {
        do {
            try parseResponse(doc: document) { _ in
                throw AppError.parseFailed
            }
        } catch {
            throw mapAppError(error: error)
        }
    }
}
