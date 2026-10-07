@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import CustomDump
import Foundation
import HomeFeature
import LibraryClient
import Sharing
import Testing

// A capture launch turns two environment keys into a validated, isolated, offline scene. These
// cases drive the pure steps (decode, validate, build, isolate) and never `install`, which changes
// process-wide state that would leak into every other test in the process.
struct CaptureSceneTests {
    // MARK: Configuration

    @Test
    func configurationDecodesBothPurposes() throws {
        let marketing = try CaptureSceneConfiguration(
            json: Data(#"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}"#.utf8)
        )
        let regression = try CaptureSceneConfiguration(
            json: Data(#"{"purpose":"regressionPublic","scenarioID":"home-finite","fixtureID":"home-finite"}"#.utf8)
        )

        expectNoDifference(
            marketing,
            CaptureSceneConfiguration(purpose: .marketingReal, scenarioID: "home", fixtureID: "nonexplicit")
        )
        expectNoDifference(
            regression,
            CaptureSceneConfiguration(purpose: .regressionPublic, scenarioID: "home-finite", fixtureID: "home-finite")
        )
    }

    @Test(arguments: [
        "not JSON",
        "[]",
        #"{"purpose":"marketingReal","scenarioID":"home"}"#,
        #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit","extra":1}"#,
        #"{"purpose":"marketing","scenarioID":"home","fixtureID":"nonexplicit"}"#,
        #"{"purpose":"marketingReal","scenarioID":"Home","fixtureID":"nonexplicit"}"#,
        #"{"purpose":"marketingReal","scenarioID":"","fixtureID":"nonexplicit"}"#,
        #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"1set"}"#,
        #"{"purpose":"marketingReal","scenarioID":1,"fixtureID":"nonexplicit"}"#
    ])
    func aMalformedConfigurationIsRejected(_ json: String) {
        let error = #expect(throws: CaptureFailure.self) {
            try CaptureSceneConfiguration(json: Data(json.utf8))
        }
        guard case .malformedConfiguration = error else {
            Issue.record("Expected a malformed configuration, got \(String(describing: error))")
            return
        }
    }

    // MARK: Launch environment

    @Test
    func anEnvironmentWithoutCaptureKeysKeepsTheUITestRoutes() throws {
        let configuration = try #require(
            try UITestAutomation.resolve(
                environment: ["EHPANDA_UITEST_STUB_NETWORK": "1", "PATH": "/usr/bin"],
                now: Date(timeIntervalSinceReferenceDate: 123)
            )
        )

        #expect(try CaptureScenePreparation.scene(environment: ["PATH": "/usr/bin"]) == nil)
        #expect(configuration.captureScene == nil)
        #expect(configuration.shouldStubNetwork)
    }

    @Test
    func aCaptureLaunchTakesExactlyItsTwoKeys() throws {
        let directory = try MarketingFixtureBuilder.standard().write()
        let configuration = #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}"#
        let complete = [
            CaptureScenePreparation.configurationKey: configuration,
            CaptureScenePreparation.fixturesKey: directory.path(percentEncoded: false)
        ]

        let conflictingKeys = ["EHPANDA_UITEST_STUB_NETWORK", "EHPANDA_VISUAL_TEST_HOST"]
        let conflicting = complete.merging(
            conflictingKeys.map({ ($0, "1") }),
            uniquingKeysWith: { current, _ in current }
        )
        #expect(throws: CaptureFailure.conflictingLaunchKeys(conflictingKeys)) {
            try CaptureScenePreparation.scene(environment: conflicting)
        }
        #expect(throws: CaptureFailure.missingConfiguration) {
            try CaptureScenePreparation.scene(
                environment: [CaptureScenePreparation.fixturesKey: directory.path(percentEncoded: false)]
            )
        }
        #expect(throws: CaptureFailure.missingFixtureDirectory) {
            try CaptureScenePreparation.scene(environment: [CaptureScenePreparation.configurationKey: configuration])
        }
        #expect(throws: CaptureFailure.missingFixtureDirectory) {
            try CaptureScenePreparation.scene(
                environment: [
                    CaptureScenePreparation.configurationKey: configuration,
                    CaptureScenePreparation.fixturesKey: "relative/fixture"
                ]
            )
        }
        #expect(throws: CaptureFailure.missingFixtureDirectory) {
            try CaptureScenePreparation.scene(
                environment: [
                    CaptureScenePreparation.configurationKey: configuration,
                    CaptureScenePreparation.fixturesKey: directory.appending(path: "absent").path(percentEncoded: false)
                ]
            )
        }

        let resolved = try #require(
            try UITestAutomation.resolve(environment: complete, now: Date(timeIntervalSinceReferenceDate: 123))
        )
        let scene = try #require(resolved.captureScene)
        #expect(resolved.shouldStubNetwork == false)
        #expect(resolved.shouldUseVisualTestHost == false)
        expectNoDifference(scene.fixtureVersion, try MarketingFixtureBuilder.standard().fixtureVersion())
    }

    // MARK: Scenes

    @Test
    func homeShowsTheSelectionInItsConfiguredOrder() async throws {
        let fixture = try MarketingFixtureBuilder.standard()
        let scene = try makeScene(fixture)

        let popular = try await scene.homeClient.fetchPopularGalleries(.ehentai, Filter())
        let frontpage = try await scene.homeClient.fetchFrontpageGalleries(.ehentai, Filter())
        var toplists = [Int: [String]]()
        for type in ToplistsType.allCases {
            toplists[type.categoryIndex] = try await scene.homeClient
                .fetchToplistsGalleries(.ehentai, type.categoryIndex, nil)
                .galleries
                .map(\.gid)
        }

        expectNoDifference(popular.map(\.gid), MarketingFixtureBuilder.heroGIDs)
        expectNoDifference(frontpage.galleries.map(\.gid), MarketingFixtureBuilder.frontpageGIDs)
        expectNoDifference(
            toplists,
            Dictionary(
                uniqueKeysWithValues: zip(
                    ToplistsType.allCases.map(\.categoryIndex),
                    MarketingFixtureBuilder.toplistsGIDs.map({ [$0] })
                )
            )
        )
        let cover = try #require(fixture.files.first(where: { $0.kind == .cover }))
        for gallery in popular + frontpage.galleries {
            expectNoDifference(gallery.token, MarketingFixtureBuilder.token)
            expectNoDifference(
                gallery.galleryURL?.absoluteString,
                "https://e-hentai.org/g/\(gallery.gid)/\(MarketingFixtureBuilder.token)/"
            )
            expectNoDifference(gallery.coverURL?.absoluteString, cover.url)
            #expect(!gallery.title.isEmpty)
        }
        await #expect(throws: AppError.notFound) {
            try await scene.homeClient.fetchToplistsGalleries(.ehentai, ToplistsType.yesterday.categoryIndex, 1)
        }
        expectNoDifference(
            scene.replay,
            Dictionary(
                uniqueKeysWithValues: fixture.files.map({ file in
                    (file.url, CaptureReplay.Response(data: file.data, mimeType: file.mime))
                })
            )
        )
    }

    @Test
    func repeatedPreparationIsDeterministic() async throws {
        let directory = try MarketingFixtureBuilder.standard().write()
        let configuration = CaptureSceneConfiguration(
            purpose: .marketingReal,
            scenarioID: "home",
            fixtureID: "nonexplicit"
        )

        let first = try CaptureScenePreparation.scene(
            configuration: configuration,
            fixture: try CaptureFixture.load(directory: directory, purpose: .marketingReal)
        )
        let second = try CaptureScenePreparation.scene(
            configuration: configuration,
            fixture: try CaptureFixture.load(directory: directory, purpose: .marketingReal)
        )

        expectNoDifference(first.fixtureVersion, second.fixtureVersion)
        expectNoDifference(first.replay, second.replay)
        let firstPopular = try await first.homeClient.fetchPopularGalleries(.ehentai, Filter())
        let secondPopular = try await second.homeClient.fetchPopularGalleries(.ehentai, Filter())
        expectNoDifference(firstPopular.map(\.gid), secondPopular.map(\.gid))
        expectNoDifference(firstPopular.map(\.title), secondPopular.map(\.title))
        expectNoDifference(firstPopular.map(\.coverURL), secondPopular.map(\.coverURL))
    }

    @Test
    func aPublicConfigurationValidatesItsFixtureButHasNoSceneYet() throws {
        let fixture = try CaptureFixture.load(directory: try PublicFixtureBuilder().write(), purpose: .regressionPublic)

        #expect(throws: CaptureFailure.unsupportedScenario("home-finite")) {
            try CaptureScenePreparation.scene(
                configuration: .init(purpose: .regressionPublic, scenarioID: "home-finite", fixtureID: "home-finite"),
                fixture: fixture
            )
        }
        #expect(throws: CaptureFailure.unknownFixtureID("comments-finite")) {
            try CaptureScenePreparation.scene(
                configuration: .init(
                    purpose: .regressionPublic,
                    scenarioID: "home-finite",
                    fixtureID: "comments-finite"
                ),
                fixture: fixture
            )
        }
    }

    @Test
    func aSceneThatCannotBeShownAsConfiguredIsRejected() throws {
        let standard = try MarketingFixtureBuilder.standard()
        var startsElsewhere = standard
        startsElsewhere.selectedIndex = 0
        var renamedPeriod = standard
        renamedPeriod.toplistsPeriods = ["yesterday", "pastMonth", "pastYear", "lastWeek"]
        var missingPage = standard
        missingPage.files.removeAll(where: { $0.kind == .detail && $0.gid == "108" })
        var unparsablePage = standard
        unparsablePage.files = standard.files.map { file in
            guard file.kind == .detail, file.gid == "104" else {
                return file
            }
            return FixtureFile(
                kind: file.kind,
                gid: file.gid,
                index: file.index,
                url: file.url,
                path: file.path,
                mime: file.mime,
                data: Data("<html></html>".utf8)
            )
        }
        let elsewhereCover = try MarketingFixtureBuilder.standard(coverURL: "https://ehgt.org/w/00/000/elsewhere.webp")

        #expect(throws: CaptureFailure.unknownFixtureID("explicit")) {
            try makeScene(standard, fixtureID: "explicit")
        }
        #expect(throws: CaptureFailure.unsupportedScenario("detail")) {
            try makeScene(standard, scenarioID: "detail")
        }
        #expect(throws: CaptureFailure.malformedScene("hero selectedIndex must be Home's starting card, 1")) {
            try makeScene(startsElsewhere)
        }
        #expect(
            throws: CaptureFailure.malformedScene(
                #"Toplists periods must be exactly ["yesterday", "pastMonth", "pastYear", "allTime"]"#
            )
        ) {
            try makeScene(renamedPeriod)
        }
        #expect(throws: CaptureFailure.malformedScene("no saved detail page for gallery 108")) {
            try makeScene(missingPage)
        }
        #expect(throws: CaptureFailure.malformedScene("the saved detail page of gallery 104 does not parse")) {
            try makeScene(unparsablePage)
        }
        #expect(throws: CaptureFailure.malformedScene("the cover of gallery 101 is not in the fixture")) {
            try makeScene(elsewhereCover)
        }
    }

    // MARK: Replay

    @Test
    func theReplayAnswersOnlyAGETOfAListedURL() throws {
        let listed = try #require(URL(string: "https://ehgt.org/w/00/000/a.webp"))
        let response = CaptureReplay.Response(data: Data("a".utf8), mimeType: "image/webp")
        let replay = CaptureReplay(responses: [listed.absoluteString: response])
        var post = URLRequest(url: listed)
        post.httpMethod = "POST"

        expectNoDifference(replay.response(for: URLRequest(url: listed)), response)
        #expect(replay.response(for: URLRequest(url: try #require(URL(string: "\(listed)?x=1")))) == nil)
        #expect(replay.response(for: URLRequest(url: try #require(URL(string: "https://e-hentai.org/api.php")))) == nil)
        #expect(replay.response(for: post) == nil)
        expectNoDifference(
            replay.unknownRequestDescriptions,
            ["GET \(listed)?x=1", "GET https://e-hentai.org/api.php", "POST \(listed)"]
        )
    }

    // MARK: Isolation

    @Test
    func theIsolatedStoresKeepPersonalSettingsOutOfTheScene() async throws {
        let personal = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = personal
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock({ $0.detectLinksFromClipboard = true })
        }
        let storage = try CaptureStorage.reset(at: makeTemporaryDirectory().appending(path: "EhPandaCapture"))
        let scene = try makeScene(try MarketingFixtureBuilder.standard())

        try await withDependencies {
            $0.defaultAppStorage = personal
            CaptureScenePreparation.isolate(&$0, scene: scene, storage: storage, libraryClient: .noop)
        } operation: {
            @Dependency(\.date.now) var now
            @Dependency(\.homeClient) var homeClient
            @Dependency(\.uuid) var uuid
            expectNoDifference(now, UITestAutomation.fixedDate)
            expectNoDifference(uuid(), UUID(0))
            let popular = try await homeClient.fetchPopularGalleries(.ehentai, Filter())
            expectNoDifference(popular.map(\.gid), MarketingFixtureBuilder.heroGIDs)

            let state = AppReducer.State()
            #expect(state.settingState.setting == Setting())
            state.settingState.$setting.withLock({ $0.bypassSNIFiltering = true })
        }
        withDependencies {
            $0.defaultAppStorage = personal
        } operation: {
            @SharedReader(.setting) var setting
            #expect(setting.detectLinksFromClipboard)
            #expect(setting.bypassSNIFiltering == false)
        }
    }

    @Test
    func storageResetEmptiesOnlyTheCaptureDirectory() throws {
        let parent = try makeTemporaryDirectory()
        let gallery = parent.appending(path: "Downloads/Gallery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: gallery, withIntermediateDirectories: true)
        try Data("page".utf8).write(to: gallery.appending(path: "1.webp"))
        let root = parent.appending(path: "EhPandaCapture", directoryHint: .isDirectory)
        let staleCache = root.appending(path: "ImageCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staleCache, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: staleCache.appending(path: "stale"))

        let storage = try CaptureStorage.reset(at: root)

        expectNoDifference(try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)), [])
        expectNoDifference(try Data(contentsOf: gallery.appending(path: "1.webp")), Data("page".utf8))
        #expect(storage.dataCache.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false)))
        #expect(storage.imageCache.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false)))
        let defaultRoot = CaptureScenePreparation.defaultStorageRoot.standardizedFileURL.path(percentEncoded: false)
        #expect(defaultRoot.hasPrefix(URL.temporaryDirectory.standardizedFileURL.path(percentEncoded: false)))
        #expect(!defaultRoot.hasPrefix(FileUtil.downloadsDirectoryURL.standardizedFileURL.path(percentEncoded: false)))
    }
}

private func makeScene(
    _ fixture: MarketingFixtureBuilder,
    scenarioID: String = "home",
    fixtureID: String = "nonexplicit"
) throws -> CaptureScene {
    try CaptureScenePreparation.scene(
        configuration: .init(purpose: .marketingReal, scenarioID: scenarioID, fixtureID: fixtureID),
        fixture: try CaptureFixture.load(directory: try fixture.write(), purpose: .marketingReal)
    )
}
