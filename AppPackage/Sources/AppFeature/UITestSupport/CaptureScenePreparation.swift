#if DEBUG
import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import CookieClient
import DFClient
import DownloadClient
import Foundation
import HomeFeature
import Kanna
import Kingfisher
import LibraryClient
import LogsClient
import ParserFeature
import SDWebImage
import Sharing
import Synchronization
import UserDefaultsClient

/// A validated capture scene, ready to install before the app builds its store.
struct CaptureScene: Sendable {
    let configuration: CaptureSceneConfiguration
    let selectionID: String
    let fixtureVersion: String
    /// Responses by exact request URL, one for every asset the fixture holds.
    let replay: [String: CaptureReplay.Response]
    /// Home's selected galleries, in configured order.
    let homeClient: HomeClient
}

/// The capture installed into this process: its scene and the replay answering its requests.
struct InstalledCapture: Sendable {
    let scene: CaptureScene
    let replay: CaptureReplay
}

/// The capture-owned directory one capture launch keeps its caches in.
struct CaptureStorage: Equatable, Sendable {
    let root: URL

    var dataCache: URL {
        root.appending(path: "DataCache", directoryHint: .isDirectory)
    }

    var kingfisherCache: URL {
        root.appending(path: "KingfisherCache", directoryHint: .isDirectory)
    }

    var sdWebImageCache: URL {
        root.appending(path: "SDWebImageCache", directoryHint: .isDirectory)
    }

    /// Empties and recreates `root`, so every capture launch starts from the same cold caches.
    ///
    /// Only a capture launch calls this, and only on the capture's own directory: it never holds
    /// a user's library, settings or downloads.
    static func reset(at root: URL) throws(CaptureFailure) -> Self {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
                try fileManager.removeItem(at: root)
            }
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            throw .storageUnavailable
        }
        return Self(root: root)
    }
}

/// Turns `EHPANDA_CAPTURE_CONFIGURATION` and `EHPANDA_CAPTURE_FIXTURES` into an installed,
/// isolated, offline capture scene.
///
/// Everything is validated before anything is installed, and installation happens before the
/// app's first store or shared key exists, so no capture state reaches the user's settings,
/// cookies, caches or downloads, and no request reaches the network.
enum CaptureScenePreparation {
    static let configurationKey = "EHPANDA_CAPTURE_CONFIGURATION"
    static let fixturesKey = "EHPANDA_CAPTURE_FIXTURES"
    static let defaultStorageRoot = URL.temporaryDirectory
        .appending(path: "EhPandaCapture", directoryHint: .isDirectory)

    private static let installation = Mutex<InstalledCapture?>(nil)

    /// The capture ``install(_:storageRoot:)`` installed, or `nil` outside a capture launch.
    static var installed: InstalledCapture? {
        installation.withLock({ $0 })
    }

    /// The scene `environment` requests, or `nil` when it requests none.
    ///
    /// A capture launch takes exactly its two keys: another `EHPANDA_` key would configure a
    /// second stub, fixture or account route beside the capture, so it is refused.
    static func scene(environment: [String: String]) throws(CaptureFailure) -> CaptureScene? {
        let configurationJSON = environment[configurationKey]
        let fixturesPath = environment[fixturesKey]
        guard configurationJSON != nil || fixturesPath != nil else {
            return nil
        }
        let conflictingKeys = environment.keys
            .filter({ $0.hasPrefix("EHPANDA_") && $0 != configurationKey && $0 != fixturesKey })
            .sorted()
        guard conflictingKeys.isEmpty else {
            throw .conflictingLaunchKeys(conflictingKeys)
        }
        guard let configurationJSON else {
            throw .missingConfiguration
        }
        guard let fixturesPath, fixturesPath.hasPrefix("/") else {
            throw .missingFixtureDirectory
        }
        let configuration = try CaptureSceneConfiguration(json: Data(configurationJSON.utf8))
        let fixture = try CaptureFixture.load(
            directory: URL(filePath: fixturesPath, directoryHint: .isDirectory),
            purpose: configuration.purpose
        )
        return try scene(configuration: configuration, fixture: fixture)
    }

    static func scene(
        configuration: CaptureSceneConfiguration,
        fixture: CaptureFixture
    ) throws(CaptureFailure) -> CaptureScene {
        switch fixture.manifest {
        case .regressionPublic(let manifest):
            guard manifest.fixtureIDs.contains(configuration.fixtureID) else {
                throw .unknownFixtureID(configuration.fixtureID)
            }
            // Public fixtures get their native scene dispatcher in 17-11; until then a public
            // configuration validates its fixture and stops here.
            throw .unsupportedScenario(configuration.scenarioID)
        case .marketingReal(let manifest, let selection):
            guard let scene = selection.scenes[configuration.fixtureID] else {
                throw .unknownFixtureID(configuration.fixtureID)
            }
            guard configuration.scenarioID == "home" else {
                throw .unsupportedScenario(configuration.scenarioID)
            }
            let replay = try replayResponses(manifest: manifest, files: fixture.files)
            let galleries = MarketingGalleries(
                manifest: manifest,
                selection: selection,
                files: fixture.files,
                replay: replay
            )
            return CaptureScene(
                configuration: configuration,
                selectionID: selection.selectionID,
                fixtureVersion: manifest.fixtureVersion,
                replay: replay,
                homeClient: try galleries.homeClient(scene.home)
            )
        }
    }

    /// Installs `scene` into this process: fresh capture-owned storage for the reader cache and
    /// both image libraries' caches, the replay with Kingfisher's session pointed at it, and the
    /// isolated dependencies.
    ///
    /// Web images are initialized here, synchronously, instead of at launch finish, so no image
    /// request can start before its session answers from the replay.
    static func install(_ scene: CaptureScene, storageRoot: URL = defaultStorageRoot) throws(CaptureFailure) {
        let storage = try CaptureStorage.reset(at: storageRoot)
        do {
            KingfisherManager.shared.cache = try ImageCache(name: "capture", cacheDirectoryURL: storage.kingfisherCache)
        } catch {
            throw .storageUnavailable
        }
        // Kingfisher keeps its default cache, the user's, alive for the process; this ends its
        // memory and background housekeeping as its deinit would, so a capture never prunes it.
        NotificationCenter.default.removeObserver(ImageCache.default)
        // Before anything creates SDWebImage's shared cache, so it never opens the user's.
        SDImageCache.defaultDiskCacheDirectory = storage.sdWebImageCache.path(percentEncoded: false)
        let replay = CaptureReplay(responses: scene.replay)
        UITestStubURLProtocol.configure(replay: replay)
        URLProtocol.registerClass(UITestStubURLProtocol.self)
        installation.withLock({ $0 = InstalledCapture(scene: scene, replay: replay) })
        let live = LibraryClient.live(configuringImageSessions: { configuration in
            configuration.protocolClasses = [UITestStubURLProtocol.self] + (configuration.protocolClasses ?? [])
        })
        let libraryClient = LibraryClient(
            initializeWebImage: {},
            removeAllCachedImages: live.removeAllCachedImages,
            cachedImage: live.cachedImage,
            cachedImageData: live.cachedImageData,
            removeCachedImage: live.removeCachedImage,
            isCached: live.isCached,
            analyzeImageColors: live.analyzeImageColors,
            calculateWebImageDiskCacheSize: live.calculateWebImageDiskCacheSize
        )
        prepareDependencies {
            isolate(&$0, scene: scene, storage: storage, libraryClient: libraryClient)
        }
        // After isolation, so the reader cache its purge observers guard is the capture's.
        live.initializeWebImage()
    }

    /// Replaces every dependency that reads or writes user data, reaches the network, or varies
    /// between runs. Clients that only present the app, such as the device and haptics clients,
    /// stay live so the scene is the actual app.
    static func isolate(
        _ dependencies: inout DependencyValues,
        scene: CaptureScene,
        storage: CaptureStorage,
        libraryClient: LibraryClient
    ) {
        dependencies.analyticsClient = .noop
        dependencies.appLaunchAutomationClient = .none
        dependencies.clipboardClient = .noop
        dependencies.cookieClient = .noop
        dependencies.dataCache = DataCache(configuration: .init(rootURL: storage.dataCache))
        dependencies.date.now = UITestAutomation.fixedDate
        dependencies.defaultAppStorage = UserDefaults.inMemory
        dependencies.defaultInMemoryStorage = InMemoryStorage()
        dependencies.dfClient = .noop
        // Inert until a downloads scene seeds capture-owned folders: a live client would adopt the
        // app's background download session and could fetch outside the replay.
        dependencies.downloadClient = .noop
        dependencies.homeClient = scene.homeClient
        dependencies.libraryClient = libraryClient
        dependencies.logsClient = .noop
        dependencies.userDefaultsClient = .noop
        dependencies.uuid = .incrementing
    }

    private static func replayResponses(
        manifest: MarketingCaptureManifest,
        files: [String: Data]
    ) throws(CaptureFailure) -> [String: CaptureReplay.Response] {
        var responses = [String: CaptureReplay.Response]()
        for asset in manifest.assets {
            guard let data = files[asset.path] else {
                throw .missingFile(asset.path)
            }
            responses[asset.url] = .init(data: data, mimeType: asset.mime)
        }
        return responses
    }
}

/// The galleries a marketing scene shows, built from the fixture's saved detail pages with the
/// app's own parser.
private struct MarketingGalleries {
    let manifest: MarketingCaptureManifest
    let selection: CaptureSelection
    let files: [String: Data]
    let replay: [String: CaptureReplay.Response]

    /// Home's client for `home`: each section in its configured order, unchanged by any filter.
    func homeClient(_ home: CaptureSelection.Home) throws(CaptureFailure) -> HomeClient {
        // Home has no way yet to start on another card, so any other selection could not be
        // shown as configured.
        let initialCard = HomeReducer.State.initialCardPageIndex
        guard home.hero.selectedIndex == initialCard else {
            throw .malformedScene("hero selectedIndex must be Home's starting card, \(initialCard)")
        }
        let periods = ToplistsType.allCases.map(Self.selectionKey)
        guard Set(home.toplists.keys) == Set(periods) else {
            throw .malformedScene("Toplists periods must be exactly \(periods)")
        }
        let hero = try home.hero.galleries.map(gallery)
        let frontpage = try home.frontpage.map(gallery)
        var toplistsByIndex = [Int: [Gallery]]()
        for type in ToplistsType.allCases {
            toplistsByIndex[type.categoryIndex] = try home.toplists[Self.selectionKey(for: type), default: []]
                .map(gallery)
        }
        let toplists = toplistsByIndex
        return HomeClient(
            fetchPopularGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in hero },
            fetchFrontpageGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in
                (pageNumber: PageNumber(), galleries: frontpage)
            },
            fetchToplistsGalleries: { (_: GalleryHost, catIndex: Int, pageNum: Int?) async throws(AppError) in
                // Home loads only each period's first page.
                guard pageNum == nil, let galleries = toplists[catIndex] else {
                    throw .notFound
                }
                return (pageNumber: PageNumber(), galleries: galleries)
            }
        )
    }

    private func gallery(_ gid: String) throws(CaptureFailure) -> Gallery {
        guard
            let galleryURL = selection.galleries.map(\.url).first(where: { Self.gid(of: $0) == gid }),
            let token = galleryURL.pathComponents.dropFirst(3).first
        else {
            throw .malformedScene("gallery \(gid) is not declared by the selection")
        }
        guard
            let page = manifest.assets.first(where: { $0.kind == .detail && $0.gid == gid }),
            let data = files[page.path]
        else {
            throw .malformedScene("no saved detail page for gallery \(gid)")
        }
        let parsed: (detail: GalleryDetail, state: GalleryState)
        do {
            parsed = try Parser.parseGalleryDetail(doc: try Kanna.HTML(html: data, encoding: .utf8), gid: gid)
        } catch {
            throw .malformedScene("the saved detail page of gallery \(gid) does not parse")
        }
        guard let coverURL = parsed.detail.coverURL, replay[coverURL.absoluteString] != nil else {
            throw .malformedScene("the cover of gallery \(gid) is not in the fixture")
        }
        return Gallery(
            gid: gid,
            token: token,
            title: parsed.detail.title,
            rating: parsed.detail.rating,
            tags: parsed.state.tags,
            category: parsed.detail.category,
            uploader: parsed.detail.uploader,
            pageCount: parsed.detail.pageCount,
            postedDate: parsed.detail.postedDate,
            coverURL: coverURL,
            galleryURL: galleryURL
        )
    }

    /// The gid of a canonical gallery URL, `https://e-hentai.org/g/<gid>/<token>/`.
    private static func gid(of url: URL) -> String? {
        let components = url.pathComponents
        guard components.count == 4, components.starts(with: ["/", "g"]) else {
            return nil
        }
        return components.dropFirst(2).first
    }

    /// The selection's name for each Toplists period. Exhaustive, so a new period cannot be
    /// silently left out of a capture.
    private static func selectionKey(for type: ToplistsType) -> String {
        switch type {
        case .yesterday:
            "yesterday"
        case .pastMonth:
            "pastMonth"
        case .pastYear:
            "pastYear"
        case .allTime:
            "allTime"
        }
    }
}
#endif
