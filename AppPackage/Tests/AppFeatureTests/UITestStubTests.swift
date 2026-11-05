@testable import AppFeature
import AppModels
import ClipboardClient
import ComposableArchitecture
import CustomDump
import DownloadClient
import Foundation
import Sharing
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

        // The host is preset past the age wall, so the phase report reached the store's client.
        #expect(store.isUnlocked)
        #expect(store.recordedScenePhase == nil)
        #expect(store.scenePhase == .background)
        #expect(store.hasEnteredBackground)
    }

    // MARK: First-launch preset

    @Test(arguments: [
        ["EHPANDA_UITEST_STUB_NETWORK": "1"],
        ["EHPANDA_VISUAL_TEST_HOST": "1"],
        ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_FIRST_LAUNCH": "Analytics"],
        ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_FIRST_LAUNCH": "nope"],
        ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_FIRST_LAUNCH": ""]
    ])
    func anAutomatedLaunchIsPresetPastTheFirstLaunch(environment: [String: String]) throws {
        let configuration = try #require(
            try UITestAutomation.resolve(environment: environment, now: .now, isTesting: true)
        )
        #expect(configuration.firstLaunchPreset == .answered)
    }

    @Test(arguments: ["show", " show\n"])
    func showAsksForTheRealFirstLaunch(value: String) throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_FIRST_LAUNCH": value],
                now: .now
            )
        )
        #expect(configuration.firstLaunchPreset == .cleared)
    }

    @Test(arguments: ["analytics", " analytics\n"])
    func analyticsOpensTheLaunchOnTheAnalyticsChoice(value: String) throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_FIRST_LAUNCH": value],
                now: .now
            )
        )
        #expect(configuration.firstLaunchPreset == .ageConfirmed)
    }

    // A launch that only overrides a client runs the real app on the user's data, answers included.
    @Test(arguments: [
        ["EHPANDA_UITEST_CLIPBOARD_URL": "https://e-hentai.org/g/1/token/"],
        ["EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": "notFound"],
        ["EHPANDA_UITEST_CLIPBOARD_URL": "https://e-hentai.org/g/1/token/", "EHPANDA_UITEST_FIRST_LAUNCH": "show"]
    ])
    func aClientOverrideAloneGetsNoPreset(environment: [String: String]) throws {
        let configuration = try #require(try UITestAutomation.resolve(environment: environment, now: .now))
        #expect(configuration.firstLaunchPreset == nil)
    }

    @Test(arguments: [[:], ["EHPANDA_UITEST_FIRST_LAUNCH": "show"]])
    func noAutomationKeyMeansNoPreset(environment: [String: String]) throws {
        #expect(try UITestAutomation.resolve(environment: environment, now: .now) == nil)
        #expect(UITestAutomation.firstLaunchPreset(environment: environment, isAutomatedLaunch: false) == nil)
    }

    @Test
    func aCaptureLaunchIsPreset() {
        #expect(UITestAutomation.firstLaunchPreset(environment: [:], isAutomatedLaunch: true) == .answered)
        #expect(
            UITestAutomation.firstLaunchPreset(
                environment: ["EHPANDA_UITEST_FIRST_LAUNCH": "show"], isAutomatedLaunch: true
            ) == .cleared
        )
    }

    @Test
    func thePresetWritesBothAnswersAndShowClearsThem() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.setting) var setting
            UITestAutomation.applyFirstLaunchPreset(.answered)
            #expect(setting.ageDeclarationVersion == AgeDeclaration.currentVersion)
            #expect(setting.analyticsLevel == .minimal)

            UITestAutomation.applyFirstLaunchPreset(.cleared)
            #expect(setting.ageDeclarationVersion == nil)
            #expect(setting.analyticsLevel == nil)

            $setting.withLock({ $0.analyticsLevel = .full })
            UITestAutomation.applyFirstLaunchPreset(.ageConfirmed)
            #expect(setting.ageDeclarationVersion == AgeDeclaration.currentVersion)
            #expect(setting.analyticsLevel == nil)

            $setting.withLock({ $0.analyticsLevel = .full })
            UITestAutomation.applyFirstLaunchPreset(nil)
            #expect(setting.analyticsLevel == .full)
        }
    }

    // MARK: Stubbed-launch storage, request log and reader keys

    @Test(arguments: [
        BlockListCase(
            value: #"[{"memberID":"1","name":"A"},{"memberID":"2","name":"B"}]"#,
            expected: [.init(memberID: "1", name: "A"), .init(memberID: "2", name: "B")]
        ),
        BlockListCase(value: nil, expected: []),
        BlockListCase(value: "not json", expected: []),
        BlockListCase(value: #"{"A": "B"}"#, expected: []),
        // The name-keyed list from before the member ID (owner msg 1918) is malformed now.
        BlockListCase(value: #"["A","B"]"#, expected: []),
        BlockListCase(value: #"[{"memberID":"1","name":"A"},{"name":"B"}]"#, expected: []),
        BlockListCase(
            value: #"[{"memberID":"1","name":"A"},{"memberID":"","name":"B"},{"memberID":"1","name":"C"}]"#,
            expected: [.init(memberID: "1", name: "A")]
        )
    ])
    func everyStubbedLaunchStartsFromTheBlockListItNames(_ blockList: BlockListCase) throws {
        var environment = ["EHPANDA_UITEST_STUB_NETWORK": "1"]
        environment["EHPANDA_UITEST_BLOCKED_USERS"] = blockList.value
        let configuration = try #require(try UITestAutomation.resolve(environment: environment, now: .now))
        expectNoDifference(configuration.storagePreset?.blockedCommentUsers, blockList.expected)
    }

    @Test
    func theDisplayNameKeyNamesTheSignedInUser() throws {
        let named = try #require(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_STUB_NETWORK": "1", "EHPANDA_UITEST_DISPLAY_NAME": " X "],
                now: .now
            )
        )
        #expect(named.storagePreset?.displayName == "X")

        let unnamed = try #require(
            try UITestAutomation.resolve(environment: ["EHPANDA_UITEST_STUB_NETWORK": "1"], now: .now)
        )
        #expect(unnamed.storagePreset == UITestAutomation.StoragePreset(blockedCommentUsers: [], displayName: nil))
    }

    @Test
    func theStoragePresetReplacesTheBlockListAndTheDisplayName() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.blockedCommentUsers) var blockedUsers
            @Shared(.user) var user
            $blockedUsers.withLock({ $0 = [.init(memberID: "9", name: "Earlier")] })
            $user.withLock({ $0.displayName = "Earlier" })

            let preset: [BlockedCommentUser] = [.init(memberID: "1", name: "A"), .init(memberID: "2", name: "B")]
            UITestAutomation.StoragePreset(blockedCommentUsers: preset, displayName: "X").apply()
            expectNoDifference(blockedUsers, preset)
            expectNoDifference(user.displayName, "X")

            UITestAutomation.StoragePreset(blockedCommentUsers: [], displayName: nil).apply()
            expectNoDifference(blockedUsers, [])
            expectNoDifference(user.displayName, nil)
        }
    }

    @Test
    func theRequestLogKeyNamesTheFile() throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: [
                    "EHPANDA_UITEST_STUB_NETWORK": "1",
                    "EHPANDA_UITEST_REQUEST_LOG": " /tmp/EhPanda UI Test/requests.log "
                ],
                now: .now
            )
        )
        expectNoDifference(
            configuration.requestLogURL?.path(percentEncoded: false),
            "/tmp/EhPanda UI Test/requests.log"
        )
    }

    @Test
    func aRequestThroughTheStubAppendsOneLine() async throws {
        let log = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).log")
        // The log is process-wide, so a parallel test's requests can land in it too; this test's own requests go
        // to a host no other test uses, and only its lines are counted.
        let host = "request-log-\(UUID().uuidString.lowercased()).invalid"
        UITestStubURLProtocol.configure(requestLog: log)
        defer {
            UITestStubURLProtocol.configure(requestLog: nil)
            do {
                try FileManager.default.removeItem(at: log)
            } catch {
                Issue.record(error)
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        _ = try await session.data(from: try #require(URL(string: "https://\(host)/g/1/token/?p=2")))
        var request = URLRequest(url: try #require(URL(string: "https://\(host)/api.php")))
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        _ = try await session.data(for: request)

        let lines = try String(contentsOf: log, encoding: .utf8)
            .split(separator: "\n")
            .filter({ $0.contains(host) })
        expectNoDifference(lines, ["GET \(host) /g/1/token/", "POST \(host) /api.php"])
    }

    @Test(arguments: [
        DropIdleCase(value: "1", expected: true),
        DropIdleCase(value: " 1 ", expected: true),
        DropIdleCase(value: "0", expected: false),
        DropIdleCase(value: nil, expected: false)
    ])
    func dropInitialIdleAsksTheReaderToDropItsFirstIdleReport(_ dropIdle: DropIdleCase) throws {
        var environment = ["EHPANDA_UITEST_STUB_NETWORK": "1"]
        environment["EHPANDA_UITEST_DROP_INITIAL_IDLE"] = dropIdle.value
        let configuration = try #require(try UITestAutomation.resolve(environment: environment, now: .now))
        #expect(configuration.dropsReaderInitialIdleReport == dropIdle.expected)
    }

    /// The keys change only a stubbed launch: alone they opt nothing in, and beside a key that overrides a client
    /// only, the real app runs on the user's data with nothing written and nothing logged.
    @Test
    func thePhaseLaunchKeysNeedAStubbedLaunch() throws {
        let keys = [
            "EHPANDA_UITEST_FIRST_LAUNCH": "analytics",
            "EHPANDA_UITEST_REQUEST_LOG": "/tmp/requests.log",
            "EHPANDA_UITEST_BLOCKED_USERS": #"[{"memberID":"1","name":"A"}]"#,
            "EHPANDA_UITEST_DISPLAY_NAME": "X",
            "EHPANDA_UITEST_DROP_INITIAL_IDLE": "1"
        ]
        #expect(try UITestAutomation.resolve(environment: keys, now: .now) == nil)

        let clientOnly = try #require(
            try UITestAutomation.resolve(
                environment: keys.merging(["EHPANDA_UITEST_FORCE_PAUSE_REFUSAL": "notFound"], uniquingKeysWith: { $1 }),
                now: .now
            )
        )
        #expect(clientOnly.firstLaunchPreset == nil)
        #expect(clientOnly.storagePreset == nil)
        #expect(clientOnly.requestLogURL == nil)
        #expect(!clientOnly.dropsReaderInitialIdleReport)
    }

    /// A hosted visual test renders into storage of its own, made fresh for each store, so its block list is
    /// already empty and no stored name carries over; the storage preset is for the simulator's shared storage.
    @Test
    func aVisualHostWritesNoStoragePreset() throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: [
                    "EHPANDA_VISUAL_TEST_HOST": "1",
                    "EHPANDA_UITEST_BLOCKED_USERS": #"[{"memberID":"1","name":"A"}]"#
                ],
                now: .now,
                isTesting: true
            )
        )
        #expect(configuration.storagePreset == nil)
    }

    @MainActor
    @Test
    func aVisualHostShownTheFirstLaunchStartsLocked() {
        let store = Store(initialState: AppReducer.State(), reducer: AppReducer.init) {
            UITestAutomation.configureVisualTestHost(&$0, firstLaunch: .cleared)
        }
        #expect(!store.isUnlocked)
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

struct BlockListCase: Sendable, CustomTestStringConvertible {
    let value: String?
    let expected: [BlockedCommentUser]

    var testDescription: String { value ?? "absent" }
}

struct DropIdleCase: Sendable, CustomTestStringConvertible {
    let value: String?
    let expected: Bool

    var testDescription: String { value.map({ "\"\($0)\"" }) ?? "absent" }
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
