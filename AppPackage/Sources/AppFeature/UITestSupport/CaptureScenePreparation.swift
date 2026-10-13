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
import ReadingFeature
import SDWebImage
import Sharing
import Synchronization
import UserDefaultsClient

/// A validated capture scene, ready to install before the app builds its store.
struct CaptureScene: Sendable {
    let configuration: CaptureSceneConfiguration
    let selectionID: String
    let fixtureVersion: String
    /// Responses by exact request URL, one for every asset the fixture fetched.
    let replay: [String: CaptureReplay.Response]
    /// Home's selected galleries, in configured order.
    let homeClient: HomeClient
    /// How the launch reaches the configured screen.
    let route: AppLaunchAutomation.CaptureRoute
    /// The Live Text the reader shows on the flow's Live Text page: the fixture's record for the
    /// reading-live-text screen, the reader's own recognition for a recording, `nil` otherwise.
    let liveText: LiveTextCapture?
    /// The download folders the Downloads screen lists; `nil` for every other screen.
    let downloads: CaptureDownloads?
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

    /// The download root a downloads scene seeds and the capture's download client reads.
    var downloads: URL {
        root.appending(path: "Downloads", directoryHint: .isDirectory)
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
            guard let scenario = CaptureScenario(id: configuration.scenarioID) else {
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
                homeClient: try galleries.homeClient(scene.home),
                route: try galleries.route(to: scenario, flow: scene.flow),
                liveText: try galleries.liveText(for: scenario, flow: scene.flow),
                downloads: try galleries.downloads(for: scenario, entries: scene.downloads)
            )
        }
    }

    /// Installs `scene` into this process: fresh capture-owned storage for the reader cache, both
    /// image libraries' caches and the scene's download folders, the replay with Kingfisher's
    /// session pointed at it, and the isolated dependencies.
    ///
    /// Web images are initialized here, synchronously, instead of at launch finish, so no image
    /// request can start before its session answers from the replay.
    static func install(_ scene: CaptureScene, storageRoot: URL = defaultStorageRoot) throws(CaptureFailure) {
        let storage = try CaptureStorage.reset(at: storageRoot)
        let downloads = try scene.downloads?.seed(into: storage.downloads) ?? .empty
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
            isolate(&$0, scene: scene, storage: storage, libraryClient: libraryClient, downloads: downloads)
        }
        // After isolation, so the reader cache its purge observers guard is the capture's.
        live.initializeWebImage()
    }

    /// Replaces every dependency that reads or writes user data, reaches the network, or varies
    /// between runs. Clients that only present the app, such as the device and haptics clients,
    /// stay live so the scene is the actual app. `downloads` is what the scene's seeded download
    /// folders read back as.
    static func isolate(
        _ dependencies: inout DependencyValues,
        scene: CaptureScene,
        storage: CaptureStorage,
        libraryClient: LibraryClient,
        downloads: CaptureDownloadIndex
    ) {
        dependencies.analyticsClient = .noop
        // The capture's route is the launch's only automation.
        dependencies.appLaunchAutomationClient = AppLaunchAutomationClient(
            current: { [route = scene.route] in AppLaunchAutomation(captureRoute: route) }
        )
        dependencies.clipboardClient = .noop
        dependencies.cookieClient = .noop
        dependencies.dataCache = DataCache(configuration: .init(rootURL: storage.dataCache))
        dependencies.date.now = UITestAutomation.fixedDate
        let appStorage = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock({ $0 = sceneSetting })
        }
        dependencies.defaultAppStorage = appStorage
        dependencies.defaultInMemoryStorage = InMemoryStorage()
        dependencies.dfClient = .noop
        // Never the live client, which would adopt the app's background download session and could
        // fetch outside the replay.
        dependencies.downloadClient = .capture(downloads)
        dependencies.homeClient = scene.homeClient
        dependencies.libraryClient = libraryClient
        dependencies.liveTextCapture = scene.liveText
        dependencies.logsClient = .noop
        dependencies.userDefaultsClient = .noop
        dependencies.uuid = .incrementing
    }

    /// The settings every capture scene runs with: the app's defaults, with the network bypass
    /// on, so the Laboratory shows it enabled (D-15), and the default vertical reader (owner
    /// decision, 2026-10-13). They live only in the capture's in-memory storage, so no person's
    /// settings change.
    static var sceneSetting: Setting {
        var setting = Setting()
        setting.bypassSNIFiltering = true
        return setting
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
            if let url = asset.url {
                responses[url] = .init(data: data, mimeType: asset.mime)
            }
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

    /// The route `scenario` takes. The gallery screens show `flow`'s gallery, built exactly as Home
    /// builds it, so the gallery a capture opens is the one its card shows; the reader opens on a
    /// page whose image the fixture holds, and a Live Text recording opens it as the
    /// reading-live-text screen does.
    func route(
        to scenario: CaptureScenario,
        flow: CaptureSelection.Flow
    ) throws(CaptureFailure) -> AppLaunchAutomation.CaptureRoute {
        switch scenario {
        case .screen(.home):
            .home
        case .screen(.detail):
            .detail(try gallery(flow.gallery))
        case .screen(.comments):
            .comments(try gallery(flow.gallery))
        case .screen(.filters):
            .filters
        case .screen(.reading):
            .reading(try gallery(flow.gallery), page: try readerPage(flow.readerPage, of: flow))
        case .screen(.readingLiveText), .liveTextRecording:
            .readingLiveText(try gallery(flow.gallery), page: try readerPage(flow.liveTextPage, of: flow))
        case .screen(.downloads):
            .downloads
        case .screen(.laboratory):
            .laboratory
        }
    }

    /// The Live Text a launch of `scenario` shows on `flow`'s Live Text page.
    ///
    /// The reading-live-text screen replays the fixture's record of that page once it proves it was
    /// recognized on the page image the fixture holds, in the languages the reader asks for, which
    /// it derives from the gallery's language; a recording lets the reader recognize the page; no
    /// other screen has Live Text.
    func liveText(
        for scenario: CaptureScenario,
        flow: CaptureSelection.Flow
    ) throws(CaptureFailure) -> LiveTextCapture? {
        let page = flow.liveTextPage
        switch scenario {
        case .screen(.readingLiveText):
            let name = "page \(page) of gallery \(flow.gallery)"
            guard let image = asset(.page, of: flow.gallery, index: page) else {
                throw .malformedScene("the fixture holds no image of \(name)")
            }
            guard let recordAsset = asset(.liveText, of: flow.gallery, index: page),
                  let data = files[recordAsset.path]
            else {
                throw .malformedScene("the fixture holds no Live Text record of \(name)")
            }
            let record: CaptureLiveTextRecord
            do {
                record = try JSONDecoder().decode(CaptureLiveTextRecord.self, from: data)
            } catch {
                let reason = CaptureFailure.describe(error)
                throw .malformedScene("the Live Text record of \(name) does not decode: \(reason)")
            }
            let groups = try record.replayGroups(
                gid: flow.gallery,
                page: page,
                pageSHA256: image.sha256,
                recognitionLanguages: try parsedDetail(flow.gallery).detail.language.codes
            )
            return LiveTextCapture(gid: flow.gallery, page: page, source: .replay(groups))
        case .liveTextRecording:
            return LiveTextCapture(gid: flow.gallery, page: page, source: .record)
        case .screen(.home), .screen(.detail), .screen(.comments), .screen(.filters), .screen(.reading),
             .screen(.downloads), .screen(.laboratory):
            return nil
        }
    }

    /// The download folders `scenario` shows: the Downloads screen's galleries in the order it lists
    /// them; no other screen has downloads.
    ///
    /// The screen lists rows by status, then by when their folder last changed, so the entries must
    /// come in status order, and each folder is dated an hour before the one above it.
    func downloads(
        for scenario: CaptureScenario,
        entries: [CaptureSelection.Download]
    ) throws(CaptureFailure) -> CaptureDownloads? {
        guard scenario == .screen(.downloads) else {
            return nil
        }
        let priorities = entries.map(\.status.displayStatus.sortPriority)
        guard priorities == priorities.sorted() else {
            throw .malformedScene("downloads are not listed in the status order the screen shows them in")
        }
        var galleries = [CaptureDownloads.Gallery]()
        for (slot, entry) in entries.enumerated() {
            let modificationDate = UITestAutomation.fixedDate.addingTimeInterval(-3600 * Double(slot))
            galleries.append(try download(entry, modificationDate: modificationDate))
        }
        return CaptureDownloads(galleries: galleries)
    }

    /// The folder `entry`'s download leaves, built as a download builds it from the gallery's detail:
    /// the manifest the download starts with, the cover its URL answers, and the image of every page
    /// the folder holds, all of a complete download and the first `completedPages` of another.
    ///
    /// No capture has a failure to show, so an `error` row cannot be captured.
    private func download(
        _ entry: CaptureSelection.Download,
        modificationDate: Date
    ) throws(CaptureFailure) -> CaptureDownloads.Gallery {
        let gid = entry.gallery
        let gallery = try gallery(gid)
        let detail = try parsedDetail(gid).detail
        let pageCount = detail.pageCount
        guard pageCount > 0 else {
            throw .malformedScene("download \(gid) has no pages")
        }
        let heldPageCount: Int
        switch entry.status {
        case .updateAvailable, .completed:
            guard entry.completedPages == nil else {
                throw .malformedScene("the \(entry.status.rawValue) download \(gid) holds every page, not a count")
            }
            heldPageCount = pageCount
        case .active, .queued, .inactive:
            guard let completedPages = entry.completedPages, (0..<pageCount).contains(completedPages) else {
                let status = entry.status.rawValue
                throw .malformedScene("the \(status) download \(gid) must hold fewer than its \(pageCount) pages")
            }
            heldPageCount = completedPages
        case .error:
            throw .malformedScene("download \(gid) cannot show an error: a capture has no failure to show")
        }
        var pages = [Int: CaptureDownloads.File]()
        for page in 1..<(heldPageCount + 1) {
            guard let image = asset(.page, of: gid, index: page) else {
                throw .malformedScene("the fixture holds no image of page \(page) of download \(gid)")
            }
            pages[page] = try file(image)
        }
        guard
            let coverURL = gallery.coverURL,
            let cover = manifest.assets.first(where: { $0.kind == .cover && $0.url == coverURL.absoluteString })
        else {
            throw .malformedScene("the cover of download \(gid) is not in the fixture")
        }
        return CaptureDownloads.Gallery(
            manifest: DownloadManifest(
                gid: gid,
                host: CaptureScenePreparation.sceneSetting.galleryHost,
                token: gallery.token,
                title: gallery.title,
                jpnTitle: detail.jpnTitle,
                category: gallery.category,
                language: detail.language,
                remoteCoverURL: detail.coverURL ?? gallery.coverURL,
                uploader: detail.uploader,
                tags: gallery.tags,
                postedDate: detail.postedDate,
                rating: detail.rating,
                pages: Dictionary(uniqueKeysWithValues: (1..<(pageCount + 1)).map({ ($0, "") }))
            ),
            folderTitle: detail.trimmedTitle.isEmpty ? gallery.title : detail.trimmedTitle,
            status: entry.status.displayStatus,
            modificationDate: modificationDate,
            cover: try file(cover),
            pages: pages
        )
    }

    /// An asset's bytes, named with the extension the fixture stored them under for their type.
    private func file(_ asset: MarketingCaptureManifest.Asset) throws(CaptureFailure) -> CaptureDownloads.File {
        guard let data = files[asset.path] else {
            throw .missingFile(asset.path)
        }
        return CaptureDownloads.File(data: data, fileExtension: URL(filePath: asset.path).pathExtension)
    }

    private func readerPage(_ page: Int, of flow: CaptureSelection.Flow) throws(CaptureFailure) -> Int {
        guard flow.pages.contains(page), asset(.page, of: flow.gallery, index: page) != nil else {
            throw .malformedScene("the fixture holds no image of page \(page) of gallery \(flow.gallery)")
        }
        return page
    }

    private func gallery(_ gid: String) throws(CaptureFailure) -> Gallery {
        guard
            let galleryURL = selection.galleries.map(\.url).first(where: { Self.gid(of: $0) == gid }),
            let token = galleryURL.pathComponents.dropFirst(3).first
        else {
            throw .malformedScene("gallery \(gid) is not declared by the selection")
        }
        let parsed = try parsedDetail(gid)
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

    /// The detail and state the app's parser reads from gallery `gid`'s saved detail page.
    private func parsedDetail(_ gid: String) throws(CaptureFailure) -> (detail: GalleryDetail, state: GalleryState) {
        guard let page = asset(.detail, of: gid, index: nil), let data = files[page.path] else {
            throw .malformedScene("no saved detail page for gallery \(gid)")
        }
        do {
            return try Parser.parseGalleryDetail(doc: try Kanna.HTML(html: data, encoding: .utf8), gid: gid)
        } catch {
            throw .malformedScene("the saved detail page of gallery \(gid) does not parse")
        }
    }

    /// The fixture's `kind` asset of gallery `gid` at `index`.
    private func asset(
        _ kind: MarketingCaptureManifest.Kind,
        of gid: String,
        index: Int?
    ) -> MarketingCaptureManifest.Asset? {
        manifest.assets.first(where: { $0.kind == kind && $0.gid == gid && $0.index == index })
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

// MARK: Downloads

/// The download folders a downloads scene shows (17-06), validated from the fixture and ready to
/// seed into capture-owned storage.
struct CaptureDownloads: Sendable {
    /// One gallery's folder, as its download leaves it.
    struct Gallery: Sendable {
        /// The manifest the download starts with, every page's hash still blank.
        let manifest: DownloadManifest
        /// The title the folder's name is made from, as a download makes it.
        let folderTitle: String
        /// The status the selection gives the row.
        let status: DownloadDisplayStatus
        let modificationDate: Date
        let cover: File
        /// The image of every page the folder holds, by page number.
        let pages: [Int: File]
    }

    struct File: Sendable {
        let data: Data
        let fileExtension: String
    }

    /// The galleries in the order the Downloads screen lists them.
    let galleries: [Gallery]
}

/// What a capture's download client lists: the seeded folders as the app's own scan reads them.
struct CaptureDownloadIndex: Equatable, Sendable {
    static let empty = Self(downloads: [], folders: [])

    /// The rows the Downloads screen lists, in order.
    let downloads: [DownloadedGallery]
    let folders: [String]
}

extension CaptureDownloads {
    /// Writes each gallery's folder into the default user folder under `root`, a capture-owned
    /// directory, as a download leaves it: the cover, the page files it holds and a manifest that
    /// records each held page's hash as the app computes it from the written file, with every other
    /// page blank. Then reads them back with the app's own scan.
    ///
    /// The manifest is the only record of completeness, as in the app: a row is complete because its
    /// manifest holds every page's hash, and only being downloaded or waiting comes from the
    /// simulated queue, so each row must read back as the status the selection gives it.
    func seed(into root: URL) throws(CaptureFailure) -> CaptureDownloadIndex {
        let store = DownloadStore(rootURL: root)
        let scan: DownloadScanResult
        do {
            for gallery in galleries {
                try write(gallery, store: store)
            }
            scan = try store.scanDownloads()
        } catch {
            throw .storageUnavailable
        }
        let records = Dictionary(grouping: scan.records, by: \.manifest.gid)
        var downloads = [DownloadedGallery]()
        for gallery in galleries {
            downloads.append(try gallery.download(from: records[gallery.manifest.gid] ?? []))
        }
        return CaptureDownloadIndex(downloads: downloads, folders: scan.userFolders)
    }

    private func write(_ gallery: Gallery, store: DownloadStore) throws {
        let manifest = gallery.manifest
        let folderURL = store.folderURL(
            relativePath: Defaults.FilePath.defaultDownloadFolder + "/"
                + store.makeFolderRelativePath(gid: manifest.gid, token: manifest.token, title: gallery.folderTitle)
        )
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let coverPath = store.makeCoverRelativePath(
            gid: manifest.gid,
            token: manifest.token,
            fileExtension: gallery.cover.fileExtension
        )
        try gallery.cover.data.write(to: folderURL.appending(path: coverPath))
        var written = manifest
        for (pageNumber, page) in gallery.pages {
            let pageURL = folderURL.appending(
                path: store.makePageRelativePath(
                    gid: manifest.gid,
                    token: manifest.token,
                    index: pageNumber,
                    fileExtension: page.fileExtension
                )
            )
            try page.data.write(to: pageURL)
            written.pages[pageNumber] = try store.fileHash(at: pageURL)
        }
        try store.writeManifest(written, folderURL: folderURL)
        // Last, as every write above changes it.
        try FileManager.default.setAttributes(
            [.modificationDate: gallery.modificationDate],
            ofItemAtPath: folderURL.path(percentEncoded: false)
        )
    }
}

extension CaptureDownloads.Gallery {
    /// The row the app lists for this gallery's folder, found once among `records`, once it reads back
    /// with every page it holds hashed, a file for each of those pages and nothing more, and its cover.
    func download(from records: [DownloadFolderRecord]) throws(CaptureFailure) -> DownloadedGallery {
        let gid = manifest.gid
        let heldPages = Set(pages.keys)
        guard
            records.count == 1,
            let record = records.first,
            Set(record.manifest.pages.filter({ !$0.value.isEmpty }).keys) == heldPages,
            Set(record.localPageURLs.keys) == heldPages,
            record.localCoverURL != nil
        else {
            throw .malformedScene("the seeded folder of download \(gid) does not read back as written")
        }
        let displayStatus = displayStatus(of: record.manifest)
        guard displayStatus == status else {
            throw .malformedScene("the seeded folder of download \(gid) reads as \(displayStatus), not \(status)")
        }
        return DownloadedGallery(
            manifest: record.manifest,
            folderURL: record.folderURL,
            folderName: record.parentFolderName,
            localCoverURL: record.localCoverURL,
            localPageURLs: record.localPageURLs,
            modificationDate: record.modificationDate,
            displayStatus: displayStatus,
            runProgress: displayStatus == .active ? DownloadRunProgress(creditedPageIndices: heldPages) : nil
        )
    }

    /// The status the app derives for `manifest` while the simulated queue runs or holds this
    /// gallery as its row's status says: completeness comes from the manifest alone.
    private func displayStatus(of manifest: DownloadManifest) -> DownloadDisplayStatus {
        switch status {
        case .active, .queued:
            status
        case .updateAvailable, .error, .inactive, .completed:
            if manifest.isComplete {
                status == .updateAvailable ? .updateAvailable : .completed
            } else {
                .inactive
            }
        }
    }
}

extension CaptureSelection.DownloadStatus {
    var displayStatus: DownloadDisplayStatus {
        switch self {
        case .active:
            .active
        case .queued:
            .queued
        case .updateAvailable:
            .updateAvailable
        case .error:
            .error
        case .inactive:
            .inactive
        case .completed:
            .completed
        }
    }
}

extension DownloadClient {
    /// A capture launch's download client: it lists `index` as the app's index lists scanned folders,
    /// and changes nothing, so a capture never starts, resumes or deletes a download.
    static func capture(_ index: CaptureDownloadIndex) -> Self {
        var client = Self.noop
        client.fetchDownloads = { index.downloads }
        client.fetchDownload = { gid in index.downloads.first(where: { $0.gid == gid }) }
        client.fetchFolders = { index.folders }
        return client
    }
}
#endif
