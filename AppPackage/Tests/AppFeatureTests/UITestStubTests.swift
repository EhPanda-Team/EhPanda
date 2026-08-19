@testable import AppFeature
import AppModels
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
        #expect(UITestAutomation.shouldDetectClipboardURL(environment: [:]) == false)

        let clipboardURL = try #require(URL(string: "https://e-hentai.org/g/2725078/token/"))
        let fixturePath = "/tmp/EhPanda UI Test Fixtures"
        let environment = [
            "EHPANDA_UITEST_STUB_NETWORK": " 1 ",
            "EHPANDA_UITEST_FIXTURE_DIR": " \(fixturePath) ",
            "EHPANDA_UITEST_CLIPBOARD_URL": " \(clipboardURL.absoluteString) "
        ]
        let configuration = try #require(
            UITestAutomation.resolve(environment: environment, now: now)
        )
        let clipboardClient = try #require(configuration.clipboardClient)

        #expect(configuration.shouldStubNetwork)
        #expect(UITestAutomation.shouldDetectClipboardURL(environment: environment))
        expectNoDifference(
            configuration.fixtureDirectory?.path(percentEncoded: false),
            fixturePath
        )
        expectNoDifference(clipboardClient.url(), clipboardURL)
        #expect(clipboardClient.changeCount() > 0)
    }

    /// The seam opts the configuration in on its own (DEF-15-08), and trims what it is given.
    ///
    /// It has to opt in alone: the two refusal arms are wanted on a device against the REAL library,
    /// so a run that also stubbed the network would have nothing to pause. Whitespace is trimmed for
    /// the same reason every other key trims it — a value typed into a scheme's environment editor
    /// carries whatever spacing came with it.
    ///
    /// Every case here drives `resolve`, never `prepare`: preparing installs process-global
    /// dependency overrides, which would leak out of the case into every other test in the process.
    @Test
    func pauseRefusalUnknownArmOptsInAlone() throws {
        let configuration = try #require(
            UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": " unknown "],
                now: Date(timeIntervalSinceReferenceDate: 123)
            )
        )

        #expect(configuration.pauseRefusal == .unknown)
        #expect(configuration.shouldStubNetwork == false)
        #expect(configuration.clipboardClient == nil)
    }

    /// The other arm, resolved from its exact spelling.
    @Test
    func pauseRefusalNotFoundArmResolves() throws {
        let configuration = try #require(
            UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": "notFound"],
                now: Date(timeIntervalSinceReferenceDate: 123)
            )
        )

        #expect(configuration.pauseRefusal == .notFound)
    }

    /// An unrecognised value is not an override, so alone it opts nothing in at all.
    ///
    /// The same disposition an unknown `EHPANDA_AUTOMATION_TAB` gets. Guessing an arm from a typo
    /// would make a device observation report a refusal nobody asked for.
    @Test
    func pauseRefusalRejectsAnUnrecognizedValue() {
        #expect(
            UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": "nope"],
                now: Date(timeIntervalSinceReferenceDate: 123)
            ) == nil
        )
    }

    /// The other side of that rejection: alongside a key that DOES opt in, an unrecognised value
    /// stays nil rather than falling back to an arm.
    @Test
    func pauseRefusalStaysNilBesideAnotherOptIn() throws {
        let configuration = try #require(
            UITestAutomation.resolve(
                environment: [
                    "EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": "nope",
                    "EHPANDA_UITEST_STUB_NETWORK": "1"
                ],
                now: Date(timeIntervalSinceReferenceDate: 123)
            )
        )

        #expect(configuration.shouldStubNetwork)
        #expect(configuration.pauseRefusal == nil)
    }

    /// The arm names the error the override throws, which is the whole point of the seam: a device
    /// observation of `.notFound` has to be the refusal `togglePause` itself answers, not a stand-in
    /// that renders the same caption.
    @Test
    func pauseRefusalCarriesTheBoundarysOwnError() {
        #expect(UITestAutomation.PauseRefusal.notFound.error == .notFound)
        #expect(UITestAutomation.PauseRefusal.unknown.error == .unknown)
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
