import AppModels
import Foundation
import Testing
import AppTools
@testable import AppFeature

struct DownloadImageParsingCacheTests: DownloadFeatureTestCase {
    @Test
    func testCachedKokomadePlaceholderStoredUnderNormalImageURLIsRejected() async throws {
        let gid = UUID().uuidString
        try await expectCachedPlaceholderRejected(
            url: try #require(
                URL(string: "https://exhentai.org/fullimg.php?gid=\(gid)&page=1&key=normal-cache-key")
            ),
            placeholderData: try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        )
    }

    @Test
    func testFileBasedEmptyExResponseMapsToAuthenticationRequired() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .exLoginRequired)
        defer { removeTemporaryItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html",
            headers: [
                "Set-Cookie": "\(Defaults.Cookie.yay)=louder; Path=/"
            ]
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedAuthHTMLMarkersMapToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { removeTemporaryItem(at: fileURL) }

        let authHTMLData = Data("""
        <html>
          <body>
            <a href="bounce_login.php">Login</a>
            <img src="/img/kokomade.jpg">
            <p>Access to ExHentai.org is restricted.</p>
          </body>
        </html>
        """.utf8)
        try authHTMLData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

}
