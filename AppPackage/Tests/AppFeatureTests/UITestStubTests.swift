@testable import AppFeature
import AppModels
import ClipboardClient
import ComposableArchitecture
import CustomDump
import DownloadClient
import Foundation
import SwiftUI
import Testing

struct UITestStubTests {
    @MainActor
    @Test
    func hostedStoreKeepsItsFixturesWhenTheCallingTestScopeChanges() async {
        let store = Store(
            initialState: AppReducer.State(), reducer: AppReducer.init,
            withDependencies: UITestAutomation.configureVisualTestHost
        )

        await withDependencies {
            // A host scene transition can arrive while an unrelated test's dependencies are current.
            // Calling this test value would report the same unimplemented endpoint as the regression.
            $0.downloadClient = DownloadClientKey.testValue
        } operation: {
            await store.send(.onScenePhaseChange(.background)).finish()
        }

        #expect(store.scenePhase == .background)
        #expect(store.hasEnteredBackground)
    }

    @Test
    func visualHostOptInForcesOfflineBootstrap() throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_VISUAL_TEST_HOST": "1"],
                now: Date(timeIntervalSinceReferenceDate: 123)
            )
        )
        #expect(configuration.shouldStubNetwork)
        #expect(configuration.shouldUseVisualTestHost)
    }

    @Test
    func visualHostFlagRequiresAnActualTestProcess() throws {
        let now = Date(timeIntervalSinceReferenceDate: 123)
        #expect(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_VISUAL_TEST_HOST": "1"],
                now: now,
                isTesting: false
            ) == nil
        )
        #expect(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_VISUAL_TEST_HOST": "0"],
                now: now,
                isTesting: true
            ) == nil
        )
    }

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
        try JSONSerialization.data(withJSONObject: Self.savedMetadata)
            .write(to: fixtureDirectory.appending(path: UITestStubURLProtocol.galleryMetadataFixtureName))

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
            Route(url: "https://e-hentai.org/toplist.php?tl=15", body: "front-page", statusCode: 200),
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

        // The configured mode is process-wide, so the `api.php` POST routes share this test's directory
        // rather than racing a parallel test's.
        let gdata = try await post(["method": "gdata", "gidlist": [[1001, "fixture1"]], "namespace": 1], in: session)
        #expect(gdata.statusCode == 200)
        let object = try #require(try JSONSerialization.jsonObject(with: gdata.data) as? [String: Any])
        let entries = try #require(object["gmetadata"] as? [[String: Any]])
        expectNoDifference(entries.map({ $0["title"] as? String }), ["Library Study 01"])

        let rating = try await post(["method": "rategallery", "gid": 1001, "token": "fixture1"], in: session)
        #expect(rating.statusCode == 404)
        #expect(rating.data.isEmpty)
    }

    private static var savedMetadata: [String: Any] {
        ["gmetadata": [
            ["gid": 1001, "token": "fixture1", "title": "Library Study 01", "title_jpn": ""],
            ["gid": 1002, "token": "fixture2", "title": "Library Study 02", "title_jpn": "図書館 02"]
        ]]
    }

    /// List pages enrich their rows through `gdata`, so the stub answers it as the site does: the
    /// saved entry for each matching gid and token, in request order, and the API's error entry for
    /// any other pair. Another `api.php` method still has no fixture.
    @Test
    func galleryMetadataResponseAnswersRequestedPairsInOrder() throws {
        let fixture = try JSONSerialization.data(withJSONObject: Self.savedMetadata)
        let request = try JSONSerialization.data(withJSONObject: [
            "method": "gdata", "namespace": 1,
            "gidlist": [[1002, "fixture2"], [1001, "fixture1"], [1001, "other"], [7, "seven"]]
        ])
        let response = try #require(
            try UITestStubURLProtocol.galleryMetadataResponse(requestBody: request, fixture: fixture)
        )
        let object = try #require(try JSONSerialization.jsonObject(with: response) as? [String: Any])
        let entries = try #require(object["gmetadata"] as? [[String: Any]])
        expectNoDifference(entries.map({ $0["gid"] as? Int }), [1002, 1001, 1001, 7])
        expectNoDifference(entries.map({ $0["title_jpn"] as? String }), ["図書館 02", "", nil, nil])
        expectNoDifference(
            entries.map({ $0["error"] as? String }),
            [nil, nil, "Key missing, or incorrect key provided.", "Key missing, or incorrect key provided."]
        )

        let rating = try JSONSerialization.data(withJSONObject: ["method": "rategallery", "gid": 1001])
        #expect(try UITestStubURLProtocol.galleryMetadataResponse(requestBody: rating, fixture: fixture) == nil)
    }

    private func post(_ body: [String: Any], in session: URLSession) async throws -> (data: Data, statusCode: Int) {
        let url = try #require(URL(string: "https://e-hentai.org/api.php"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        return (data, try #require(response as? HTTPURLResponse).statusCode)
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
            try UITestAutomation.resolve(environment: environment, now: now)
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
            try UITestAutomation.resolve(
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
            try UITestAutomation.resolve(
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
    func pauseRefusalRejectsAnUnrecognizedValue() throws {
        #expect(
            try UITestAutomation.resolve(
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
            try UITestAutomation.resolve(
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
