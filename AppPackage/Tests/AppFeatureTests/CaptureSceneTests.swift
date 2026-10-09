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
        expectNoDifference(scene.replay, Self.replay(of: fixture))
    }

    @Test
    func aRecordIsNeverReplayed() throws {
        var fixture = try MarketingFixtureBuilder.standard()
        fixture.files.append(.liveTextRecord(Data("{}".utf8)))

        let scene = try makeScene(fixture)

        expectNoDifference(scene.replay, Self.replay(of: try MarketingFixtureBuilder.standard()))
    }

    /// The responses a scene of `fixture` answers: every fetched file at its replay URL.
    private static func replay(of fixture: MarketingFixtureBuilder) -> [String: CaptureReplay.Response] {
        Dictionary(
            uniqueKeysWithValues: fixture.files.compactMap({ file in
                file.url.map({ ($0, CaptureReplay.Response(data: file.data, mimeType: file.mime)) })
            })
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
        #expect(throws: CaptureFailure.unsupportedScenario("slide-menu")) {
            try makeScene(standard, scenarioID: "slide-menu")
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
        expectNoDifference(replay.response(for: URLRequest(url: listed)), response)
        #expect(replay.response(for: URLRequest(url: try #require(URL(string: "\(listed)?x=1")))) == nil)
        #expect(replay.response(for: URLRequest(url: try #require(URL(string: "https://e-hentai.org/api.php")))) == nil)
        #expect(replay.response(for: post) == nil)
        expectNoDifference(replay.answeredURLs, [listed.absoluteString])
        expectNoDifference(
            replay.unknownRequestDescriptions,
            ["GET \(listed)?x=1", "GET https://e-hentai.org/api.php", "POST \(listed)"]
        )
    }

    // MARK: Diagnostics

    @Test
    func homeIsReadyOnlyOnceItsListsAndEveryDeliveredImageAreIn() async throws {
        let fixture = try MarketingFixtureBuilder.standard().addingPreview()
        let scene = try makeScene(fixture)
        let cover = try #require(fixture.files.first(where: { $0.kind == .cover })?.url)
        let preview = try #require(fixture.files.first(where: { $0.kind == .preview })?.url)
        let detailPage = try #require(fixture.files.first(where: { $0.kind == .detail })?.url)
        let loaded = try await loadedState(scene)

        func diagnostics(
            _ state: AppReducer.State,
            answered: Set<String> = [],
            cached: Set<String> = []
        ) -> CaptureDiagnostics {
            CaptureDiagnostics(
                scene: scene,
                state: state,
                rendering: .lightPhone,
                answeredURLs: answered,
                unknownRequests: [],
                isCached: cached.contains
            )
        }

        let empty = diagnostics(AppReducer.State(), cached: [cover])
        let coverMissing = diagnostics(loaded, answered: [cover, detailPage])
        let previewMissing = diagnostics(loaded, answered: [cover, preview, detailPage], cached: [cover])
        let ready = diagnostics(loaded, answered: [cover, preview, detailPage], cached: [cover, preview])

        expectNoDifference(empty.screenID, .home)
        expectNoDifference(empty.galleryIDs, [])
        expectNoDifference(empty.readiness, .loading)
        expectNoDifference(coverMissing.readiness, .loading)
        expectNoDifference(coverMissing.pendingImages, 1)
        expectNoDifference(previewMissing.readiness, .loading)
        expectNoDifference(previewMissing.pendingImages, 1)
        expectNoDifference(
            ready,
            CaptureDiagnostics(
                screenID: .home,
                selectionID: "test-selection",
                setID: "nonexplicit",
                fixtureVersion: try fixture.fixtureVersion(),
                galleryIDs: MarketingFixtureBuilder.allGIDs,
                page: nil,
                readiness: .ready,
                pendingImages: 0,
                unknownRequests: [],
                blockers: [],
                rendering: .lightPhone,
                liveText: nil
            )
        )
    }

    @Test
    func aRefusedRequestOrAFailedLoadFailsTheScreen() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let cover = try #require(scene.replay.first(where: { $0.value.mimeType.hasPrefix("image/") })).key
        var failedToplists = try await loadedState(scene)
        failedToplists.homeState.toplistsLoadingState[ToplistsType.allTime.categoryIndex] = .failed(.notFound)

        let refused = CaptureDiagnostics(
            scene: scene,
            state: try await loadedState(scene),
            rendering: .lightPhone,
            answeredURLs: [cover],
            unknownRequests: ["GET https://e-hentai.org/api.php"],
            isCached: { _ in true }
        )
        let failed = CaptureDiagnostics(
            scene: scene,
            state: failedToplists,
            rendering: .lightPhone,
            answeredURLs: [cover],
            unknownRequests: [],
            isCached: { _ in true }
        )

        expectNoDifference(refused.readiness, .failed)
        expectNoDifference(refused.unknownRequests, ["GET https://e-hentai.org/api.php"])
        expectNoDifference(failed.readiness, .failed)
        expectNoDifference(failed.blockers, ["A Home list failed to load"])
    }

    @Test
    func noScreenIsIdentifiedAwayFromHome() async throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        var state = try await loadedState(scene)
        state.tabBarState.tabBarItemType = .favorites

        let diagnostics = CaptureDiagnostics(
            scene: scene,
            state: state,
            rendering: .lightPhone,
            answeredURLs: [],
            unknownRequests: [],
            isCached: { _ in true }
        )

        #expect(diagnostics.screenID == nil)
        expectNoDifference(diagnostics.galleryIDs, [])
        expectNoDifference(diagnostics.readiness, .loading)
    }

    @Test
    func diagnosticsEncodeAsTheJSONUITestsRead() throws {
        let diagnostics = CaptureDiagnostics(
            screenID: .readingLiveText,
            selectionID: "test-selection",
            setID: "nonexplicit",
            fixtureVersion: "marketing-0123456789abcdef",
            galleryIDs: ["101"],
            page: 4,
            readiness: .failed,
            pendingImages: 0,
            unknownRequests: ["GET https://e-hentai.org/api.php"],
            blockers: ["The image of page 4 is not shown"],
            rendering: .darkPhone,
            liveText: CaptureLiveTextDiagnostics(
                gid: "101",
                page: 4,
                source: .fixture,
                recognitionLanguages: nil,
                groups: LiveTextRecordFile().groups
            )
        )

        expectNoDifference(
            try diagnostics.encodedJSON(),
            #"{"blockers":["The image of page 4 is not shown"],"fixtureVersion":"marketing-0123456789abcdef","#
                + #""galleryIDs":["101"],"liveText":{"gid":"101","groups":[{"blocks":[{"#
                + #""bottomLeft":{"x":0.1,"y":0.25},"bottomRight":{"x":0.4,"y":0.25},"#
                + #""id":"00000000-0000-0000-0000-000000000001","text":"You sent me away,","#
                + #""topLeft":{"x":0.1,"y":0.2},"topRight":{"x":0.4,"y":0.2}}],"#
                + #""id":"00000000-0000-0000-0000-000000000000"}],"page":4,"recognitionLanguages":null,"#
                + #""source":"fixture"},"page":4,"pendingImages":0,"readiness":"failed","#
                + #""rendering":{"appearance":"dark","family":"iphone","language":"en","locale":"en_US","#
                + #""textSize":"large"},"screenID":"reading-live-text","selectionID":"test-selection","#
                + #""setID":"nonexplicit","unknownRequests":["GET https://e-hentai.org/api.php"]}"#
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
            expectNoDifference(state.settingState.setting, CaptureScenePreparation.sceneSetting)
            state.settingState.$setting.withLock({ $0.showNewDawnGreeting.toggle() })
        }
        withDependencies {
            $0.defaultAppStorage = personal
        } operation: {
            @SharedReader(.setting) var setting
            #expect(setting.detectLinksFromClipboard)
            #expect(setting.bypassSNIFiltering == false)
            #expect(setting.readingDirection == Setting().readingDirection)
            expectNoDifference(setting.showNewDawnGreeting, Setting().showNewDawnGreeting)
        }
    }

    @Test
    func sceneSettingsAreTheDefaultsWithTheBypassOnAndThePagingReader() {
        var expected = Setting()
        expected.bypassSNIFiltering = true
        expected.readingDirection = .leftToRight
        expectNoDifference(CaptureScenePreparation.sceneSetting, expected)
    }

    @Test
    func storageResetEmptiesOnlyTheCaptureDirectory() throws {
        let parent = try makeTemporaryDirectory()
        let gallery = parent.appending(path: "Downloads/Gallery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: gallery, withIntermediateDirectories: true)
        try Data("page".utf8).write(to: gallery.appending(path: "1.webp"))
        let root = parent.appending(path: "EhPandaCapture", directoryHint: .isDirectory)
        let staleCache = root.appending(path: "KingfisherCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staleCache, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: staleCache.appending(path: "stale"))

        let storage = try CaptureStorage.reset(at: root)

        expectNoDifference(try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)), [])
        expectNoDifference(try Data(contentsOf: gallery.appending(path: "1.webp")), Data("page".utf8))
        #expect(storage.dataCache.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false)))
        #expect(storage.kingfisherCache.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false)))
        #expect(storage.sdWebImageCache.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false)))
        let defaultRoot = CaptureScenePreparation.defaultStorageRoot.standardizedFileURL.path(percentEncoded: false)
        #expect(defaultRoot.hasPrefix(URL.temporaryDirectory.standardizedFileURL.path(percentEncoded: false)))
        #expect(!defaultRoot.hasPrefix(FileUtil.downloadsDirectoryURL.standardizedFileURL.path(percentEncoded: false)))
    }
}

/// The app state once Home has shown every list of `scene`, as its fetches leave it.
func loadedState(_ scene: CaptureScene) async throws -> AppReducer.State {
    var state = AppReducer.State()
    let popular = try await scene.homeClient.fetchPopularGalleries(.ehentai, Filter())
    state.homeState.popularGalleries = popular
    state.homeState.currentCardID = popular[HomeReducer.State.initialCardPageIndex].gid
    state.homeState.frontpageGalleries = try await scene.homeClient
        .fetchFrontpageGalleries(.ehentai, Filter())
        .galleries
    for type in ToplistsType.allCases {
        state.homeState.toplistsGalleries[type.categoryIndex] = try await scene.homeClient
            .fetchToplistsGalleries(.ehentai, type.categoryIndex, nil)
            .galleries
        state.homeState.toplistsLoadingState[type.categoryIndex] = .idle
    }
    return state
}

extension MarketingFixtureBuilder {
    /// The standard fixture plus one preview image, a second image beside the shared cover.
    func addingPreview() -> Self {
        var fixture = self
        fixture.files.append(
            FixtureFile(
                kind: .preview,
                gid: "101",
                index: 1,
                url: "https://ehgt.org/m/000101/preview-1.webp",
                path: "assets/101/previews/1.webp",
                mime: "image/webp",
                data: Data("preview".utf8)
            )
        )
        return fixture
    }
}

func makeScene(
    _ fixture: MarketingFixtureBuilder,
    scenarioID: String = "home",
    fixtureID: String = "nonexplicit"
) throws -> CaptureScene {
    try CaptureScenePreparation.scene(
        configuration: .init(purpose: .marketingReal, scenarioID: scenarioID, fixtureID: fixtureID),
        fixture: try CaptureFixture.load(directory: try fixture.write(), purpose: .marketingReal)
    )
}
