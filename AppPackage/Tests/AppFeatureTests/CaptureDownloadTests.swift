@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import CustomDump
import DownloadClient
import Foundation
import Kingfisher
import Testing

// A capture of the Downloads screen lists real download folders: the selection's galleries, each
// seeded into capture-owned storage as a download leaves it, with the page files it holds and a
// manifest that records their hashes. These cases seed the folders, read them back with the app's
// own scan and validation, and refuse every selection a folder could not truthfully show.
struct CaptureDownloadTests {
    /// The saved detail page every test gallery shows has this many pages.
    private static let pageCount = 156

    @Test
    func eachDownloadIsSeededAsADownloadLeavesItsFolder() throws {
        let fixture = try Self.fixture()
        let root = try makeTemporaryDirectory().appending(path: "Downloads", directoryHint: .isDirectory)

        let index = try #require(try makeScene(fixture, scenarioID: "downloads").downloads).seed(into: root)

        expectNoDifference(index.downloads.map(\.gid), ["101", "104"])
        expectNoDifference(index.folders, [Defaults.FilePath.defaultDownloadFolder])
        expectNoDifference(index.downloads.map(\.displayStatus), [.active, .completed])
        expectNoDifference(index.downloads.map(\.badge.progress.completedPageCount), [2, Self.pageCount])
        expectNoDifference(index.downloads.map(\.pageCount), [Self.pageCount, Self.pageCount])
        expectNoDifference(index.downloads.map(\.runProgress), [.init(creditedPageIndices: [1, 2]), nil])
        let store = DownloadStore(rootURL: root)
        for download in index.downloads {
            let held = download.gid == "101" ? Set(1...2) : Set(1...Self.pageCount)
            // The app's own check: every recorded hash is the hash of the file beside it.
            #expect(store.validate(download: download, verifiesContentHashes: true) == .valid)
            expectNoDifference(Set(download.manifest.pages.filter({ !$0.value.isEmpty }).keys), held)
            expectNoDifference(Set(download.localPageURLs.keys), held)
            for (pageNumber, url) in download.localPageURLs {
                expectNoDifference(try Data(contentsOf: url), Self.pageData(gid: download.gid, page: pageNumber))
            }
            let coverURL = try #require(download.localCoverURL)
            expectNoDifference(try Data(contentsOf: coverURL), Data("cover".utf8))
            expectNoDifference(download.folderURL.deletingLastPathComponent().lastPathComponent, "Default")
            let prefix = "[\(download.gid)_\(MarketingFixtureBuilder.token)] "
            #expect(download.folderURL.lastPathComponent.hasPrefix(prefix))
        }
        // The folders are dated so the app's own order, by status and then newest first, is the
        // selection's.
        let dates = try index.downloads.map({ try #require($0.lastDownloadedDate) })
        #expect(dates == dates.sorted(by: >))
        let scanned = try store.scanDownloads().records.map(\.manifest).sorted(by: { $0.gid < $1.gid })
        expectNoDifference(scanned, index.downloads.map(\.manifest))
    }

    @Test
    func aQueuedOrStoppedDownloadKeepsItsPagesAndAnUpdatedOneIsComplete() throws {
        let fixture = try Self.fixture(downloads: [
            .init(gallery: "101", status: .queued, completedPages: 0),
            .init(gallery: "104", status: .updateAvailable, completedPages: nil),
            .init(gallery: "105", status: .inactive, completedPages: 3)
        ])
        let root = try makeTemporaryDirectory().appending(path: "Downloads", directoryHint: .isDirectory)

        let index = try #require(try makeScene(fixture, scenarioID: "downloads").downloads).seed(into: root)

        expectNoDifference(index.downloads.map(\.displayStatus), [.queued, .updateAvailable, .inactive])
        expectNoDifference(index.downloads.map(\.badge.progress.completedPageCount), [0, Self.pageCount, 3])
        expectNoDifference(index.downloads.map(\.localPageURLs.count), [0, Self.pageCount, 3])
        #expect(index.downloads.allSatisfy({ $0.runProgress == nil }))
    }

    @Test
    func onlyTheDownloadsScreenHasDownloads() throws {
        // The flow gallery's page is the reader's, so no download holds it here.
        let fixture = try Self.fixture(downloads: [.init(gallery: "104", status: .completed, completedPages: nil)])
            .addingFlowPage()
            .addingLiveTextRecord(LiveTextRecordFile())

        for screen in CaptureScreen.allCases where screen != .downloads {
            #expect(try makeScene(fixture, scenarioID: screen.rawValue).downloads == nil)
        }
    }

    @Test
    func aDownloadAFolderCannotTruthfullyShowIsRefused() throws {
        let missingPage = try Self.fixture(downloads: [.init(gallery: "104", status: .completed, completedPages: nil)])
            .removingPage(Self.pageCount, of: "104")

        #expect(
            throws: CaptureFailure.malformedScene("download 104 cannot show an error: a capture has no failure to show")
        ) {
            try makeScene(
                try Self.fixture(downloads: [.init(gallery: "104", status: .error, completedPages: 1)]),
                scenarioID: "downloads"
            )
        }
        #expect(
            throws: CaptureFailure.malformedScene(
                "downloads are not listed in the status order the screen shows them in"
            )
        ) {
            try makeScene(
                try Self.fixture(downloads: [
                    .init(gallery: "104", status: .completed, completedPages: nil),
                    .init(gallery: "101", status: .active, completedPages: 2)
                ]),
                scenarioID: "downloads"
            )
        }
        #expect(throws: CaptureFailure.malformedScene("the active download 101 must hold fewer than its 156 pages")) {
            try makeScene(
                try Self.fixture(downloads: [.init(gallery: "101", status: .active, completedPages: Self.pageCount)]),
                scenarioID: "downloads"
            )
        }
        #expect(
            throws: CaptureFailure.malformedScene("the completed download 104 holds every page, not a count")
        ) {
            try makeScene(
                try Self.fixture(downloads: [.init(gallery: "104", status: .completed, completedPages: 2)]),
                scenarioID: "downloads"
            )
        }
        #expect(throws: CaptureFailure.malformedScene("the fixture holds no image of page 156 of download 104")) {
            try makeScene(missingPage, scenarioID: "downloads")
        }
    }

    @Test
    func theCaptureClientListsTheSeededFoldersAndChangesNothing() async throws {
        let scene = try makeScene(try Self.fixture(), scenarioID: "downloads")
        let storage = try CaptureStorage.reset(at: makeTemporaryDirectory().appending(path: "EhPandaCapture"))
        let index = try #require(scene.downloads).seed(into: storage.downloads)

        try await withDependencies {
            CaptureScenePreparation.isolate(
                &$0,
                scene: scene,
                storage: storage,
                libraryClient: .noop,
                downloads: index
            )
        } operation: {
            @Dependency(\.downloadClient) var downloadClient
            let downloads = await downloadClient.fetchDownloads()
            let folders = await downloadClient.fetchFolders()
            let completed = await downloadClient.fetchDownload("104")
            let unknown = await downloadClient.fetchDownload("999")
            try await downloadClient.delete("104")

            expectNoDifference(downloads, index.downloads)
            expectNoDifference(folders, [Defaults.FilePath.defaultDownloadFolder])
            expectNoDifference(completed, index.downloads.last)
            #expect(unknown == nil)
            expectNoDifference(try DownloadStore(rootURL: storage.downloads).scanDownloads().records.count, 2)
        }
        let downloadsPath = storage.downloads.standardizedFileURL.path(percentEncoded: false)
        #expect(downloadsPath.hasPrefix(storage.root.standardizedFileURL.path(percentEncoded: false)))
        let appDownloadsPath = FileUtil.downloadsDirectoryURL.standardizedFileURL.path(percentEncoded: false)
        #expect(!downloadsPath.hasPrefix(appDownloadsPath))
    }

    @Test
    func downloadsAreReadyOnceEveryRowShowsItsCover() throws {
        let scene = try makeScene(try Self.fixture(), scenarioID: "downloads")
        let index = try #require(scene.downloads).seed(
            into: try makeTemporaryDirectory().appending(path: "Downloads", directoryHint: .isDirectory)
        )
        var state = AppReducer.State()
        state.tabBarState.tabBarItemType = .downloads
        state.downloadsState.downloads = index.downloads
        state.downloadsState.loadingState = .idle
        let covers = try Set(index.downloads.map({ try #require($0.coverURL).cacheKey }))

        let waiting = CaptureDiagnostics(
            scene: scene,
            state: state,
            rendering: .lightPhone,
            answeredURLs: [],
            unknownRequests: [],
            isCached: { _ in false }
        )
        let shown = CaptureDiagnostics(
            scene: scene,
            state: state,
            rendering: .lightPhone,
            answeredURLs: [],
            unknownRequests: [],
            isCached: covers.contains
        )

        expectNoDifference(waiting.readiness, .loading)
        expectNoDifference(waiting.blockers, ["2 download covers are not shown"])
        expectNoDifference(shown.readiness, .ready)
        expectNoDifference(shown.galleryIDs, ["101", "104"])
        expectNoDifference(
            shown.downloads,
            [
                CaptureDownloadDiagnostics(
                    gid: "101",
                    status: .active,
                    completedPages: 2,
                    pageCount: Self.pageCount,
                    pageFiles: 2
                ),
                CaptureDownloadDiagnostics(
                    gid: "104",
                    status: .completed,
                    completedPages: Self.pageCount,
                    pageCount: Self.pageCount,
                    pageFiles: Self.pageCount
                )
            ]
        )
    }

    @Test
    func eachRowsCoverIsPreloadedUnderTheKeyItsImageAsksFor() throws {
        let scene = try makeScene(try Self.fixture(), scenarioID: "downloads")
        let index = try #require(scene.downloads).seed(
            into: try makeTemporaryDirectory().appending(path: "Downloads", directoryHint: .isDirectory)
        )
        let cache = try ImageCache(name: "preload", cacheDirectoryURL: try makeTemporaryDirectory())

        try index.preloadCovers(into: cache)

        for download in index.downloads {
            // The row's image asks for the cover the row shows: its local file.
            let coverURL = try #require(download.coverURL)
            #expect(coverURL == download.localCoverURL)
            #expect(cache.isCached(forKey: coverURL.cacheKey))
            expectNoDifference(try cache.diskStorage.value(forKey: coverURL.cacheKey), Data("cover".utf8))
        }
    }

    /// The standard fixture with `downloads` selected and the image of every page each of them
    /// could hold.
    private static func fixture(
        downloads: [CaptureSelection.Download] = [
            .init(gallery: "101", status: .active, completedPages: 2),
            .init(gallery: "104", status: .completed, completedPages: nil)
        ]
    ) throws -> MarketingFixtureBuilder {
        var fixture = try MarketingFixtureBuilder.standard()
        fixture.downloads = downloads
        for gid in Set(downloads.map(\.gallery)) {
            fixture.files += (1...pageCount).map { page in
                FixtureFile(
                    kind: .page,
                    gid: gid,
                    index: page,
                    url: "https://abc.hath.network/h/\(gid)/\(page).webp",
                    path: "assets/\(gid)/pages/\(page).webp",
                    mime: "image/webp",
                    data: pageData(gid: gid, page: page)
                )
            }
        }
        return fixture
    }

    private static func pageData(gid: String, page: Int) -> Data {
        Data("page \(page) of \(gid)".utf8)
    }
}

private extension MarketingFixtureBuilder {
    func removingPage(_ page: Int, of gid: String) -> Self {
        var fixture = self
        fixture.files.removeAll(where: { $0.kind == .page && $0.gid == gid && $0.index == page })
        return fixture
    }
}
