@testable import AppFeature
import CustomDump
import Foundation
import Testing

struct UITestStubTests {
    @Test
    func fixtureRoutesStayHermetic() async throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        defer {
            UITestStubURLProtocol.configure(fixtureDirectory: nil)
            do {
                try FileManager.default.removeItem(at: fixtureDirectory)
            } catch {
                Issue.record(error)
            }
        }

        let fixtures = [
            Fixture(name: "GalleryDetail.html", body: "gallery"),
            Fixture(name: "GalleryDetailAlt.html", body: "alternate"),
            Fixture(name: "GallerySinglePage.html", body: "single-page"),
            Fixture(name: "FrontPageList.html", body: "front-page")
        ]
        for fixture in fixtures {
            try Data(fixture.body.utf8)
                .write(to: fixtureDirectory.appending(path: fixture.name))
        }

        UITestStubURLProtocol.configure(fixtureDirectory: fixtureDirectory)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let routes = [
            Route(url: "https://e-hentai.org/g/2725078/token/", body: "gallery", statusCode: 200),
            Route(url: "https://e-hentai.org/g/2930572/token/", body: "alternate", statusCode: 200),
            Route(url: "https://e-hentai.org/s/page-token/2725078-4", body: "single-page", statusCode: 200),
            Route(url: "https://e-hentai.org/?f_search=test", body: "front-page", statusCode: 200),
            Route(url: "https://e-hentai.org/api.php", body: "", statusCode: 404)
        ]
        for route in routes {
            let url = try #require(URL(string: route.url))
            let (data, response) = try await session.data(from: url)
            let httpResponse = try #require(response as? HTTPURLResponse)
            let body = try #require(String(data: data, encoding: .utf8))

            expectNoDifference(body, route.body)
            #expect(httpResponse.statusCode == route.statusCode)
        }
    }

    @Test
    func environmentResolutionIsOptInAndBuildsClipboardOverride() throws {
        let now = Date(timeIntervalSinceReferenceDate: 123)
        #expect(UITestAutomation.prepare(environment: [:], now: now) == nil)

        let clipboardURL = try #require(URL(string: "https://e-hentai.org/g/2725078/token/"))
        let fixturePath = "/tmp/EhPanda UI Test Fixtures"
        let configuration = try #require(UITestAutomation.resolve(
            environment: [
                "EHPANDA_UITEST_STUB_NETWORK": " 1 ",
                "EHPANDA_UITEST_FIXTURE_DIR": " \(fixturePath) ",
                "EHPANDA_UITEST_CLIPBOARD_URL": " \(clipboardURL.absoluteString) "
            ],
            now: now
        ))
        let clipboardClient = try #require(configuration.clipboardClient)

        #expect(configuration.shouldStubNetwork)
        expectNoDifference(
            configuration.fixtureDirectory?.path(percentEncoded: false),
            fixturePath
        )
        expectNoDifference(clipboardClient.url(), clipboardURL)
        #expect(clipboardClient.changeCount() > 0)
    }
}

private struct Fixture: Sendable {
    let name: String
    let body: String
}

private struct Route: Sendable {
    let url: String
    let body: String
    let statusCode: Int
}
