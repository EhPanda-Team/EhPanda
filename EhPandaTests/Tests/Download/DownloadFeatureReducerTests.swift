//
//  DownloadFeatureReducerTests.swift
//  EhPandaTests
//

import CoreData
import ComposableArchitecture
import Kingfisher
import UIKit
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadFeatureReducerTests: TestHelper {
    @Test
    func testQuickSearchWordUsesNameWhenContentIsEmpty() {
        let word = QuickSearchWord(name: "artist:hossy", content: "")

        #expect(word.effectiveSearchText == "artist:hossy")
    }

    @Test
    func testPauseKeepsActiveDownloadPausedWhenDeferredSchedulingRuns() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration)
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 7
        )

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.testingScheduleNextIfNeeded()
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }

        try await Task.sleep(for: .milliseconds(100))

        let stored = await manager.testingFetchDownload(gid: gid)
        let activeGalleryID = await manager.testingActiveGalleryID()
        #expect(stored?.status == .paused)
        #expect(stored?.badge == .paused(7, 26))
        #expect(activeGalleryID == nil)
    }

    @Test
    func testPauseUsesTemporaryWorkingSetProgressWhenCancelling() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 1)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.testingScheduleNextIfNeeded()
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .paused)
        #expect(stored?.completedPageCount == 2)
        #expect(stored?.badge == .paused(2, 2))
    }

    @Test
    func testReconcileDownloadsNormalizesLegacyFailedStatusToNeedsAttention() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration)
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 0,
            pageCount: 18
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .partial)
        #expect(stored?.badge == .partial(0, 18))
    }

    @Test
    func testReconcileDownloadsClearsCancellationLikeGalleryError() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 3)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration)
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: 4,
            pageCount: 18,
            lastError: .init(
                code: .fileOperationFailed,
                message: "The operation could not be completed. (Swift.CancellationError error 1.)"
            )
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.lastError == nil)
        #expect(stored?.status == .partial)
    }

    @Test
    func testLoadInspectionFiltersCancellationFailuresIntoPendingPages() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 4)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try storage.writeFailedPages(
            .init(
                pages: [
                    .init(
                        index: 2,
                        relativePath: "pages/0002.jpg",
                        failure: .init(
                            code: .fileOperationFailed,
                            message: "The operation could not be completed. (Swift.CancellationError error 1.)"
                        )
                    )
                ]
            ),
            folderURL: temporaryFolderURL
        )

        let result = await manager.loadInspection(gid: gid)
        guard case .success(let inspection) = result else {
            Issue.record("Expected inspection to load successfully, got \(result)")
            return
        }

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .pending)
        #expect((try? storage.readFailedPages(folderURL: temporaryFolderURL).pages.isEmpty) ?? true)
    }

    @Test
    func testDownloadsFilterMatchesKeywordAndStatus() {
        let activeDownload = sampleDownload(
            gid: "101",
            title: "Alpha Archive",
            status: .downloading,
            completedPageCount: 2
        )
        let completedDownload = sampleDownload(
            gid: "202",
            title: "Beta Collection",
            status: .completed
        )

        var state = DownloadsReducer.State()
        state.downloads = [activeDownload, completedDownload]
        state.filter = .active
        state.keyword = "alpha"

        #expect(state.filteredDownloads == [activeDownload])
    }

    @Test
    func testQueuedRetryWorkAppearsAsActiveDownloadBadge() {
        let queuedRedownload = sampleDownload(
            gid: "303",
            title: "Gamma Archive",
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        #expect(queuedRedownload.pendingOperation == .redownload)
        #expect(queuedRedownload.badge == .queued)
        #expect(queuedRedownload.matches(filter: .active))
    }

    @Test
    func testQueuedRepairWorkAppearsAsActiveDownloadBadge() {
        let queuedRepair = sampleDownload(
            gid: "404",
            title: "Broken Archive",
            status: .missingFiles,
            completedPageCount: 3,
            pendingOperation: .repair
        )

        #expect(queuedRepair.pendingOperation == .repair)
        #expect(queuedRepair.badge == .queued)
        #expect(queuedRepair.matches(filter: .active))
    }

    @Test
    func testQueuedUpdateWorkAppearsAsActiveDownloadBadge() {
        let queuedUpdate = sampleDownload(
            gid: "414",
            title: "Updated Archive",
            status: .updateAvailable,
            completedPageCount: 12,
            latestRemoteVersionSignature: "hash:v2",
            pendingOperation: .update
        )

        #expect(queuedUpdate.pendingOperation == .update)
        #expect(queuedUpdate.badge == .queued)
        #expect(queuedUpdate.matches(filter: .active))
        #expect(queuedUpdate.matches(filter: .update) == false)
    }

    @Test
    func testQueuedResumedUpdateDoesNotPretendToBeInitialWork() {
        let resumedUpdate = sampleDownload(
            gid: "415",
            title: "Resumed Update",
            status: .queued,
            pageCount: 26,
            completedPageCount: 7,
            latestRemoteVersionSignature: "hash:v2"
        )

        #expect(resumedUpdate.pendingOperation == nil)
        #expect(resumedUpdate.isQueuedWorkItem)
        #expect(resumedUpdate.badge == .queued)
        #expect(resumedUpdate.matches(filter: .active))
    }

    @Test
    func testPausedDownloadAppearsAsActiveBadge() {
        let pausedDownload = sampleDownload(
            gid: "455",
            title: "Paused Archive",
            status: .paused,
            pageCount: 12,
            completedPageCount: 4
        )

        #expect(pausedDownload.badge == .paused(4, 12))
        #expect(pausedDownload.matches(filter: .active))
    }

    @Test
    func testActiveDownloadsDoNotExposeUpdateActions() {
        let downloadingUpdate = sampleDownload(
            gid: "456",
            title: "Downloading Update",
            status: .downloading,
            completedPageCount: 5,
            latestRemoteVersionSignature: "hash:v2"
        )
        let pausedUpdate = sampleDownload(
            gid: "457",
            title: "Paused Update",
            status: .paused,
            completedPageCount: 5,
            latestRemoteVersionSignature: "hash:v2"
        )
        let completedUpdate = sampleDownload(
            gid: "458",
            title: "Completed Update",
            status: .completed,
            latestRemoteVersionSignature: "hash:v2"
        )

        #expect(downloadingUpdate.canTriggerUpdate == false)
        #expect(pausedUpdate.canTriggerUpdate == false)
        #expect(completedUpdate.canTriggerUpdate)
    }

    @Test
    func testDownloadsFilterMatchesGalleryFilterCriteria() {
        let qualifyingDownload = sampleDownload(
            gid: "466",
            title: "Chinese Archive",
            status: .completed,
            pageCount: 28
        )
        let filteredOutDownload = sampleDownload(
            gid: "477",
            title: "Low Rated Archive",
            status: .completed,
            pageCount: 8
        )

        var state = DownloadsReducer.State()
        state.downloads = [
            qualifyingDownload,
            filteredOutDownload
        ]
        state.galleryFilter.minimumRatingActivated = true
        state.galleryFilter.minimumRating = 4
        state.galleryFilter.pageRangeActivated = true
        state.galleryFilter.pageLowerBound = "20"
        state.galleryFilter.pageUpperBound = "40"

        #expect(state.filteredDownloads == [qualifyingDownload])
    }

    @Test
    func testDownloadsFilterExcludesSelectedCategoriesLikeSearchFilter() {
        let nonHDownload = sampleDownload(
            gid: "478",
            title: "Healthy Archive",
            status: .completed,
            category: .nonH
        )
        let mangaDownload = sampleDownload(
            gid: "479",
            title: "Comic Archive",
            status: .completed,
            category: .manga
        )

        var state = DownloadsReducer.State()
        state.downloads = [nonHDownload, mangaDownload]
        state.galleryFilter.excludedCategories = [.nonH]

        #expect(state.filteredDownloads == [mangaDownload])
    }

    @Test
    func testPartialDownloadBadgeUsesNeedsAttentionCopy() {
        let partialDownload = sampleDownload(
            gid: "480",
            title: "Incomplete Archive",
            status: .partial,
            pageCount: 12,
            completedPageCount: 5
        )

        #expect(partialDownload.badge.text == "Needs Attention 5/12")
        #expect(DownloadListFilter.failed.title == "Needs Attention")
    }

    @Test
    func testQueuedRedownloadDoesNotLeakIntoCompletedFilter() {
        let queuedRedownload = sampleDownload(
            gid: "505",
            title: "Delta Archive",
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        #expect(queuedRedownload.matches(filter: .completed) == false)
        #expect(queuedRedownload.matches(filter: .update) == false)
    }

    @Test
    func testQueuedRepairDoesNotLeakIntoFailedFilter() {
        let queuedRepair = sampleDownload(
            gid: "606",
            title: "Repair Archive",
            status: .missingFiles,
            completedPageCount: 3,
            pendingOperation: .repair
        )
        let missingFilesWithoutQueuedWork = sampleDownload(
            gid: "607",
            title: "Actually Missing",
            status: .missingFiles,
            pageCount: 4,
            completedPageCount: 0
        )

        #expect(queuedRepair.matches(filter: .failed) == false)
        #expect(queuedRepair.matches(filter: .update) == false)
        #expect(missingFilesWithoutQueuedWork.badge == .missingFiles)
        #expect(missingFilesWithoutQueuedWork.matches(filter: .failed))
    }

    @Test
    func testQueuedRedownloadKeepsQueuedSortPriority() {
        let completedDownload = sampleDownload(
            gid: "707",
            title: "Completed Archive",
            status: .completed,
            lastDownloadedAt: .distantFuture
        )

        let queuedRedownload = sampleDownload(
            gid: "808",
            title: "Queued Archive",
            status: .completed,
            completedPageCount: 12,
            lastDownloadedAt: .distantPast,
            pendingOperation: .redownload
        )

        let sortedDownloads = [completedDownload, queuedRedownload].sorted { lhs, rhs in
            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }
            return (lhs.lastDownloadedAt ?? .distantPast) > (rhs.lastDownloadedAt ?? .distantPast)
        }

        #expect(queuedRedownload.sortPriority == 1)
        #expect(completedDownload.sortPriority == 7)
        #expect(sortedDownloads.map(\.gid) == [queuedRedownload.gid, completedDownload.gid])
    }

    @Test
    func testInProgressDownloadPrefersTemporaryCoverURL() throws {
        let gid = "811"
        let download = sampleDownload(
            gid: gid,
            title: "Temporary Cover Archive",
            status: .downloading,
            completedPageCount: 3
        )

        let rootURL = try #require(
            FileUtil.downloadsDirectoryURL,
            "Downloads directory is unavailable in the test environment."
        )

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        try? FileManager.default.removeItem(at: temporaryFolderURL)
        defer { try? FileManager.default.removeItem(at: temporaryFolderURL) }

        try FileManager.default.createDirectory(
            at: temporaryFolderURL,
            withIntermediateDirectories: true
        )
        let temporaryCoverURL = temporaryFolderURL.appendingPathComponent("cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: temporaryCoverURL, options: .atomic)

        #expect(download.resolvedCoverURL(rootURL: rootURL) == temporaryCoverURL)
    }

    @Test
    func testQueuedDownloadPreservesTemporaryWorkingSet() {
        let queuedDownload = sampleDownload(
            gid: "809",
            title: "Queued Archive",
            status: .queued,
            completedPageCount: 3
        )

        #expect(queuedDownload.shouldPreserveTemporaryWorkingSet)
    }

    @Test
    func testActiveDownloadDoesNotNormalizeWhileTaskIsStillRunning() {
        let activeDownload = sampleDownload(
            gid: "810",
            title: "Running Archive",
            status: .downloading,
            completedPageCount: 3
        )

        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: activeDownload.gid,
                hasActiveTask: true
            ) == false
        )
        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: nil,
                hasActiveTask: false
            )
        )
        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: "another-gid",
                hasActiveTask: true
            )
        )
    }

    @Test
    func testAppLaunchAutomationResolveParsesGalleryURLAndCookies() {
        let automation = AppLaunchAutomation.resolve(environment: [
            "EHPANDA_AUTOMATION_TAB": "downloads",
            "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID": "1394965",
            "EHPANDA_AUTOMATION_GALLERY_URL": "https://e-hentai.org/g/1394965/56c35114b6/",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "4172984",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "pass-hash",
            "EHPANDA_AUTOMATION_IGNEOUS": "igneous-value"
        ])

        #expect(automation?.initialTab == .downloads)
        #expect(automation?.autoDownloadGID == "1394965")
        #expect(
            automation?.galleryURL == URL(string: "https://e-hentai.org/g/1394965/56c35114b6/")
        )
        #expect(automation?.loginCookies?.memberID == "4172984")
        #expect(automation?.loginCookies?.passHash == "pass-hash")
        #expect(automation?.loginCookies?.igneous == "igneous-value")
    }

    @Test
    func testImportAutomationCookiesClearsStaleIgneousAndUsesSessionCookies() {
        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        defer { cookieClient.clearAll() }

        cookieClient.setOrEditCookie(
            for: Defaults.URL.exhentai,
            key: Defaults.Cookie.igneous,
            value: "stale-igneous"
        )

        cookieClient.importAutomationCookies(
            memberID: "4172984",
            passHash: "pass-hash",
            igneous: nil
        )

        let exCookies = HTTPCookieStorage.shared.cookies(for: Defaults.URL.exhentai) ?? []
        let memberCookie = exCookies.first { $0.name == Defaults.Cookie.ipbMemberId }
        let passHashCookie = exCookies.first { $0.name == Defaults.Cookie.ipbPassHash }
        let igneousCookie = exCookies.first { $0.name == Defaults.Cookie.igneous }

        #expect(memberCookie?.value == "4172984")
        #expect(passHashCookie?.value == "pass-hash")
        #expect(memberCookie?.isSessionOnly == true)
        #expect(passHashCookie?.isSessionOnly == true)
        #expect(igneousCookie == nil)
        #expect(cookieClient.didLogin)
        #expect(cookieClient.shouldFetchIgneous)
    }

    @MainActor
    @Test
    func testRunLaunchAutomationFallsBackToInitialTabWhenGalleryURLIsUnhandleable() async {
        setenv("EHPANDA_AUTOMATION_TAB", "downloads", 1)
        setenv("EHPANDA_AUTOMATION_GALLERY_URL", "https://example.com/not-a-gallery", 1)
        defer {
            unsetenv("EHPANDA_AUTOMATION_TAB")
            unsetenv("EHPANDA_AUTOMATION_GALLERY_URL")
        }

        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.cookieClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.urlClient = .init(
                checkIfHandleable: { _ in false },
                checkIfMPVURL: { _ in false },
                parseGalleryID: { _ in .init() }
            )
        }

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType, .downloads) {
            $0.tabBarState.tabBarItemType = .downloads
        }
    }

    @MainActor
    @Test
    func testDatabasePreparationImportsAutomationCookiesBeforeLoadingSettings() async {
        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        setenv("EHPANDA_AUTOMATION_IPB_MEMBER_ID", "4172984", 1)
        setenv("EHPANDA_AUTOMATION_IPB_PASS_HASH", "pass-hash", 1)
        defer {
            cookieClient.clearAll()
            unsetenv("EHPANDA_AUTOMATION_IPB_MEMBER_ID")
            unsetenv("EHPANDA_AUTOMATION_IPB_PASS_HASH")
        }

        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.cookieClient = cookieClient
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.uiApplicationClient = .noop
            $0.userDefaultsClient = .noop
            $0.appDelegateClient = .noop
            $0.libraryClient = .noop
            $0.loggerClient = .noop
            $0.fileClient = .noop
            $0.dfClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.appDelegate(.migration(.onDatabasePreparationSuccess)))
        await store.receive(\.appDelegate.removeExpiredImageURLs)
        #expect(cookieClient.didLogin)
        await store.receive(\.setting.loadUserSettings)
    }

    @MainActor
    @Test
    func testLoadUserSettingsDefersExLaunchAutomationUntilIgneousArrives() async throws {
        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        cookieClient.importAutomationCookies(
            memberID: "4172984",
            passHash: "pass-hash",
            igneous: nil
        )
        setenv("EHPANDA_AUTOMATION_GALLERY_URL", "https://exhentai.org/g/1394965/56c35114b6/", 1)
        defer {
            cookieClient.clearAll()
            unsetenv("EHPANDA_AUTOMATION_GALLERY_URL")
        }

        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.cookieClient = cookieClient
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.uiApplicationClient = .noop
            $0.userDefaultsClient = .noop
            $0.appDelegateClient = .noop
            $0.libraryClient = .noop
            $0.loggerClient = .noop
            $0.fileClient = .noop
            $0.dfClient = .noop
            $0.urlClient = .init(
                checkIfHandleable: { _ in false },
                checkIfMPVURL: { _ in false },
                parseGalleryID: { _ in .init() }
            )
        }
        store.exhaustivity = .off

        await store.send(.setting(.loadUserSettingsDone))
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isWaitingForIgneousBeforeLaunchAutomation)

        let response = try #require(HTTPURLResponse(
            url: Defaults.URL.exhentai,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Set-Cookie": "\(Defaults.Cookie.igneous)=test-igneous"
            ]
        ))
        await store.send(.setting(.fetchIgneousDone(.success(response))))
        await store.receive(\.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
            $0.isWaitingForIgneousBeforeLaunchAutomation = false
        }
    }

    @MainActor
    @Test
    func testLoadUserSettingsKeepsExLaunchAutomationDeferredWhenIgneousFetchFails() async {
        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        cookieClient.importAutomationCookies(
            memberID: "4172984",
            passHash: "pass-hash",
            igneous: nil
        )
        setenv("EHPANDA_AUTOMATION_GALLERY_URL", "https://exhentai.org/g/1394965/56c35114b6/", 1)
        defer {
            cookieClient.clearAll()
            unsetenv("EHPANDA_AUTOMATION_GALLERY_URL")
        }

        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.cookieClient = cookieClient
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.uiApplicationClient = .noop
            $0.userDefaultsClient = .noop
            $0.appDelegateClient = .noop
            $0.libraryClient = .noop
            $0.loggerClient = .noop
            $0.fileClient = .noop
            $0.dfClient = .noop
            $0.urlClient = .init(
                checkIfHandleable: { _ in false },
                checkIfMPVURL: { _ in false },
                parseGalleryID: { _ in .init() }
            )
        }
        store.exhaustivity = .off

        await store.send(.setting(.loadUserSettingsDone))
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isWaitingForIgneousBeforeLaunchAutomation)

        await store.send(.setting(.fetchIgneousDone(.failure(.networkingFailed))))
        await store.receive(\.setting.account.loadCookies)
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isWaitingForIgneousBeforeLaunchAutomation)
    }

    @MainActor
    @Test
    func testDownloadsReducerKeepsIdleStateForEmptyLibrary() async {
        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
        }

        await store.send(.fetchDownloadsDone([])) {
            $0.loadingState = .idle
        }

        #expect(store.state.downloads == [])
    }

    @MainActor
    @Test
    func testDownloadsReducerSeedsOnlineDetailStateFromDownload() async {
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        }
        store.exhaustivity = .off

        await store.send(.setNavigation(.detail(download.gid)))

        #expect(store.state.route == .detail(download.gid))
        #expect(store.state.detailState.wrappedValue?.gid == download.gid)
        #expect(store.state.detailState.wrappedValue?.gallery.id == download.gid)
        #expect(store.state.detailState.wrappedValue?.downloadBadge == .downloaded)
        #expect(store.state.detailState.wrappedValue?.shouldCheckForRemoteUpdates == true)
    }

    @MainActor
    @Test
    func testDownloadsReducerUpdateActionUsesDownloadClientRetry() async {
        let retried = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .updateAvailable,
            latestRemoteVersionSignature: "hash:v2"
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { gid, mode in
                    if mode == .update {
                        retried.value.append(gid)
                    }
                    return .success(())
                },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.updateDownload(download.gid))
        await store.receive(\.updateDownloadDone)

        #expect(retried.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerDeleteActionUsesDownloadClientDelete() async {
        let deleted = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "654321",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { gid in
                    deleted.value.append(gid)
                    return .success(())
                },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.deleteDownload(download.gid))
        await store.receive(\.deleteDownloadDone)

        #expect(deleted.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerTogglePauseActionUsesDownloadClientPause() async {
        let toggled = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "987654",
            title: "Downloading Gallery",
            status: .downloading,
            completedPageCount: 9
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { gid in
                    toggled.value.append(gid)
                    return .success(())
                },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone)

        #expect(toggled.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerLoadsInspection() async {
        let download = sampleDownload(
            gid: "246810",
            title: "Inspector Gallery",
            status: .failed,
            completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)

        let store = TestStore(initialState: .init(gid: download.gid)) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(inspection) }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadInspection)
        await store.receive(\.loadInspectionDone) {
            $0.inspection = inspection
            $0.stableInspection = inspection
            $0.loadingState = .idle
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerRetryPageUsesDownloadClientRetryPages() async {
        await confirmation(expectedCount: 1) { confirm in
            let retried = UncheckedBox<[Int]>([])
            let download = sampleDownload(
                gid: "112233",
                title: "Retry Page Gallery",
                status: .failed,
                completedPageCount: 1
            )
            var initialState = DownloadInspectorReducer.State(gid: download.gid)
            initialState.inspection = sampleInspection(download: download)
            initialState.loadingState = .idle

            let store = TestStore(initialState: initialState) {
                DownloadInspectorReducer()
            } withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in
                            continuation.finish()
                        }
                    },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in nil },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    updateRemoteSignature: { _, _ in .none },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    retryPages: { _, pageIndices in
                        retried.value = pageIndices
                        confirm()
                        return .success(())
                    },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) },
                    loadInspection: { _ in
                        guard let inspection = initialState.inspection else {
                            return .failure(.notFound)
                        }
                        return .success(inspection)
                    }
                )
            }
            store.exhaustivity = .off

            await store.send(.retryPage(2))
            #expect(retried.value == [2])
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerRetryFailedPagesMarksFailedPagesPending() async {
        let retried = UncheckedBox<[Int]>([])
        let download = sampleDownload(
            gid: "112235",
            title: "Retry Failed Pages Gallery",
            status: .partial,
            completedPageCount: 1
        )
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = sampleInspection(download: download)
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, pageIndices in
                    retried.value = pageIndices
                    return .success(())
                },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in
                    guard let inspection = initialState.inspection else {
                        return .failure(.notFound)
                    }
                    return .success(inspection)
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.retryFailedPages) {
            guard let inspection = $0.inspection else { return }
            $0.inspection = .init(
                download: inspection.download,
                coverURL: inspection.coverURL,
                pages: [
                    .init(
                        index: 1,
                        status: .downloaded,
                        relativePath: "pages/0001.jpg",
                        fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"),
                        failure: nil
                    ),
                    .init(
                        index: 2,
                        status: .pending,
                        relativePath: "pages/0002.jpg",
                        fileURL: nil,
                        failure: nil
                    )
                ]
            )
        }

        #expect(retried.value == [2])
    }

    @MainActor
    @Test
    func testDownloadInspectorKeepsRetriedPagesPendingWhileRetryWorkRemainsActive() async {
        let download = sampleDownload(
            gid: "112236",
            title: "Retry Pending Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let refreshedInspection = sampleInspection(download: download)

        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = sampleInspection(download: download)
        initialState.stableInspection = sampleInspection(download: download)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(refreshedInspection) }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(refreshedInspection))) {
            $0.inspection = .init(
                download: download,
                coverURL: refreshedInspection.coverURL,
                pages: [
                    refreshedInspection.pages[0],
                    .init(
                        index: 2,
                        status: .pending,
                        relativePath: "pages/0002.jpg",
                        fileURL: nil,
                        failure: nil
                    )
                ]
            )
            $0.loadingState = .idle
            $0.retryingPageIndices = [2]
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorClearsRetryingPagesAfterRetrySettlesWithFailure() async {
        let initialDownload = sampleDownload(
            gid: "112237",
            title: "Retry Failure Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let settledDownload = sampleDownload(
            gid: "112237",
            title: "Retry Failure Gallery",
            status: .partial,
            completedPageCount: 1,
            lastError: .init(code: .networkingFailed, message: "Network Error")
        )
        let settledInspection = sampleInspection(download: settledDownload)

        var initialState = DownloadInspectorReducer.State(gid: initialDownload.gid)
        initialState.inspection = sampleInspection(download: initialDownload)
        initialState.stableInspection = sampleInspection(download: initialDownload)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(settledInspection) }
            )
        }
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(settledInspection))) {
            $0.inspection = settledInspection
            $0.stableInspection = settledInspection
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorRestoresStableInspectionWhenRetryReloadFails() async {
        let download = sampleDownload(
            gid: "112238",
            title: "Retry Reload Failure Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let stableInspection = sampleInspection(download: download)

        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = .init(
            download: download,
            coverURL: stableInspection.coverURL,
            pages: [
                stableInspection.pages[0],
                .init(
                    index: 2,
                    status: .pending,
                    relativePath: "pages/0002.jpg",
                    fileURL: nil,
                    failure: nil
                )
            ]
        )
        initialState.stableInspection = stableInspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .failure(.networkingFailed) }
            )
        }
        store.exhaustivity = .off

        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .failure(.networkingFailed))) {
            $0.inspection = stableInspection
            $0.loadingState = .failed(.networkingFailed)
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorSkipsReloadWhenObservedDownloadDidNotChange() async {
        let download = sampleDownload(
            gid: "112244",
            title: "Stable Inspector Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let loadInspectionCount = UncheckedBox(0)

        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in
                    loadInspectionCount.value += 1
                    return .success(inspection)
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.observeDownloadsDone([download]))
        #expect(loadInspectionCount.value == 0)
    }

    @MainActor
    @Test
    func testDownloadInspectorIgnoresStaleInspectionResponses() async {
        let originalDownload = sampleDownload(
            gid: "112245",
            title: "Stale Inspector Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let refreshedDownload = sampleDownload(
            gid: "112245",
            title: "Stale Inspector Gallery",
            status: .partial,
            completedPageCount: 2
        )
        let staleInspection = sampleInspection(download: originalDownload)
        let refreshedInspection = sampleInspection(download: refreshedDownload)

        let firstRequestID = UUID()
        let secondRequestID = UUID()
        var initialState = DownloadInspectorReducer.State(gid: originalDownload.gid)
        initialState.loadingState = .loading
        initialState.inspectionRequestID = secondRequestID

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        }
        store.exhaustivity = .off

        await store.send(.loadInspectionDone(firstRequestID, .success(staleInspection)))
        #expect(store.state.inspection == nil)

        await store.send(.loadInspectionDone(secondRequestID, .success(refreshedInspection))) {
            $0.inspection = refreshedInspection
            $0.stableInspection = refreshedInspection
            $0.loadingState = .idle
        }
    }

    @Test
    func testDownloadManagerLoadInspectionUsesTemporaryFailedPagesSnapshot() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try JSONEncoder().encode(
            DownloadFailedPagesSnapshot(
                pages: [
                    .init(
                        index: 2,
                        relativePath: "pages/0002.jpg",
                        failure: .init(code: .networkingFailed, message: "Network Error")
                    )
                ]
            )
        )
        .write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadFailedPages),
            options: .atomic
        )

        let result = await manager.loadInspection(gid: gid)
        let inspection = try result.get()

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .failed)
        #expect(inspection.pages[1].failure?.code == .networkingFailed)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsPrefersCompletedFolderForCompletedDownload() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 11)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 2,
            pageCount: 2
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        let completedPageURL = completedFolderURL.appendingPathComponent("pages/0001.jpg")
        try Data([0x01]).write(to: completedPageURL, options: .atomic)
        try Data([0x02]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let temporaryPageURL = temporaryFolderURL.appendingPathComponent("pages/0001.jpg")
        try Data([0x02]).write(to: temporaryPageURL, options: .atomic)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedPageURL)
        #expect(pageURLs[1] != temporaryPageURL)
        #expect(pageURLs[3] == nil)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsMergesReadableCompletedPagesWithTemporaryPages() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 12)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 2,
            pageCount: 2
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: completedFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x09]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let temporaryPageURL = temporaryFolderURL.appendingPathComponent("pages/0002.jpg")
        try Data([0x02]).write(to: temporaryPageURL, options: .atomic)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent("pages/0001.jpg"))
        #expect(pageURLs[2] == temporaryPageURL)
    }

    @Test
    func testRepairSeedRejectsOldCompletedVersionWhenGalleryUpdatedButPageCountMatches() async throws {
        let gid = "repair-seed-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        let existingDownload = sampleDownload(
            gid: gid,
            title: "Mixed Version",
            status: .missingFiles,
            pageCount: 2,
            completedPageCount: 2,
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v2"
        )
        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Mixed Version", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let oldManifest = try sampleManifest(
            gid: gid,
            title: "Mixed Version",
            pageCount: 2,
            versionSignature: "hash:v1"
        )
        try JSONEncoder().encode(oldManifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: completedFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let payload = DownloadRequestPayload(
            gallery: Gallery(
                gid: gid,
                token: "token",
                title: "Mixed Version",
                rating: 4,
                tags: [],
                category: .doujinshi,
                uploader: "Uploader",
                pageCount: 2,
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid,
                title: "Mixed Version",
                jpnTitle: nil,
                isFavorited: false,
                visibility: .yes,
                rating: 4,
                userRating: 0,
                ratingCount: 1,
                category: .doujinshi,
                language: .japanese,
                uploader: "Uploader",
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0,
                pageCount: 2,
                sizeCount: 1,
                sizeType: "MB",
                torrentCount: 0
            ),
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            options: .init(),
            mode: .repair
        )

        let workingSeed = try await manager.testingPrepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            versionSignature: "hash:v2"
        )

        #expect(workingSeed.manifest == nil)
        #expect(workingSeed.existingPages.isEmpty)
        #expect(workingSeed.coverRelativePath == nil)
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent("pages/0001.jpg").path
            ) == false
        )
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent("pages/0002.jpg").path
            ) == false
        )
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsMarksCompletedDownloadMissingFilesWhenZeroBytePageIsFound() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 13)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 2,
            pageCount: 2
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        let emptyPageURL = completedFolderURL.appendingPathComponent("pages/0001.jpg")
        try Data().write(to: emptyPageURL, options: .atomic)
        let goodPageURL = completedFolderURL.appendingPathComponent("pages/0002.jpg")
        try Data([0x02]).write(to: goodPageURL, options: .atomic)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(pageURLs[1] == nil)
        #expect(pageURLs[2] == goodPageURL)
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
        #expect(stored?.status == .missingFiles)
        #expect(stored?.completedPageCount == 1)
    }

    @MainActor
    @Test
    func testImageClientFetchImageUsesStableAliasCacheKey() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let stableCacheKey = try #require(url.stableImageCacheKey)
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemRed.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.pngData())

        KingfisherManager.shared.cache.store(image, original: imageData, forKey: stableCacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: stableCacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
        }

        let result = await ImageClient.live.fetchImage(url: url)
        let fetchedImage = try result.get()

        #expect(fetchedImage.size == image.size)
    }

    @Test
    func testRetryPagesQueuesWorkWhenAnotherDownloadIsActive() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL,
            withIntermediateDirectories: true
        )
        try storage.writeFailedPages(
            .init(
                pages: [
                    .init(
                        index: 2,
                        relativePath: "pages/0002.jpg",
                        failure: .init(code: .networkingFailed, message: "Network Error")
                    )
                ]
            ),
            folderURL: temporaryFolderURL
        )

        let blockingTask = Task<Void, Never> {
            _ = try? await Task.sleep(for: .seconds(60))
        }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "other-active-download", task: blockingTask)

        let result = await manager.retryPages(gid: gid, pageIndices: [2])

        guard case .success = result else {
            Issue.record("Retry pages should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .queued)
        #expect(stored?.badge == .queued)
        #expect(stored?.pendingOperation == nil)
        #expect(stored?.lastError == nil)

        let resumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
        #expect(resumeState.pageSelection == [2])
        #expect(FileManager.default.fileExists(
            atPath: temporaryFolderURL
                .appendingPathComponent(Defaults.FilePath.downloadFailedPages)
                .path
        ) == false)
    }

    @Test
    func testCancelQueuedRepairRestoresReadableCountAndClearsPendingOperation() async throws {
        let container = try makeInMemoryContainer()

        let gid = "cancel-repair-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .missingFiles,
            completedPageCount: 0,
            pageCount: 2,
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v1",
            pendingOperation: .repair
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: completedFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        let result = await manager.togglePause(gid: gid)
        guard case .success = result else {
            Issue.record("Cancelling queued repair should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .missingFiles)
        #expect(stored?.completedPageCount == 1)
        #expect(stored?.pendingOperation == nil)
    }

    @Test
    func testRetryPagesUsesMinimalSourceResolutionAndSkipsWhenNoPendingPages() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 200)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let recorder = RequestRecorder()
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let gidInt = try #require(Int(gid))
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": gidInt,
                "token": "token",
                "current_gid": gidInt,
                "current_key": "updated-key",
                "parent_gid": gidInt,
                "parent_key": "token",
                "first_gid": gidInt,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.host == "api.e-hentai.org" {
                recorder.recordMetadata()
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    metadataResponse
                )
            }

            if url.path.contains("/g/\(gid)/token") {
                let pageNumber = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "p" })?
                    .value
                    .flatMap(Int.init)
                if let pageNumber {
                    recorder.recordPreview(pageNumber)
                } else {
                    recorder.recordDetail()
                }
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    detailHTML
                )
            }

            if url.path.contains("/mpv/\(gid)/token") {
                recorder.recordMPV()
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let method = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                if method?["method"] as? String == "gdata" {
                    recorder.recordMetadata()
                    return (
                        try #require(HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )),
                        metadataResponse
                    )
                }

                recorder.recordImageDispatch()
                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    responseData
                )
            }

            if url.host == "example.com" {
                recorder.recordImageDownload()
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )),
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let scaffoldDownload = sampleDownload(
            gid: gid,
            title: "Pause Race",
            status: .partial,
            pageCount: 156,
            completedPageCount: 155
        )
        let (payload, versionSignature) = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload,
            mode: .redownload,
            pageSelection: [pageIndex]
        )
        recorder.reset()

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let pageCount = payload.galleryDetail.pageCount
        let manifest = try sampleManifest(
            gid: gid,
            title: "Pause Race",
            pageCount: pageCount,
            versionSignature: versionSignature
        )
        func writeTemporaryWorkingSet(missing pageToOmit: Int?) throws {
            try? FileManager.default.removeItem(at: temporaryFolderURL)
            try FileManager.default.createDirectory(
                at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(manifest).write(
                to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
                options: .atomic
            )
            try Data([0x00]).write(
                to: temporaryFolderURL.appendingPathComponent("cover.jpg"),
                options: .atomic
            )
            for index in 1...pageCount where index != pageToOmit {
                try Data([UInt8(index % 255)]).write(
                    to: temporaryFolderURL.appendingPathComponent(
                        "pages/\(String(format: "%04d", index)).jpg"
                    ),
                    options: .atomic
                )
            }
            try storage.writeResumeState(
                .init(
                    mode: .redownload,
                    versionSignature: versionSignature,
                    pageCount: pageCount,
                    downloadOptions: .init(),
                    pageSelection: [pageIndex]
                ),
                folderURL: temporaryFolderURL
            )
        }

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: pageCount - 1,
            pageCount: pageCount,
            remoteVersionSignature: versionSignature,
            latestRemoteVersionSignature: versionSignature
        )

        try writeTemporaryWorkingSet(missing: pageIndex)
        await manager.testingProcessDownload(gid: gid)

        let firstRunSnapshot = recorder.snapshot()
        #expect(firstRunSnapshot.previewPageNumbers == [1])

        recorder.reset()
        try clearPersistedDownloads(in: container)
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: pageCount,
            pageCount: pageCount,
            remoteVersionSignature: versionSignature,
            latestRemoteVersionSignature: versionSignature
        )

        try writeTemporaryWorkingSet(missing: nil)
        await manager.testingProcessDownload(gid: gid)

        let secondRunSnapshot = recorder.snapshot()
        #expect(secondRunSnapshot.previewPageNumbers.isEmpty)
        #expect(secondRunSnapshot.mpvRequests == 0)
        #expect(secondRunSnapshot.imageDispatchRequests == 0)
    }

    @Test
    func testRetryPagesFallsBackToFullUpdateWhenGalleryHasUpdate() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = try #require(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueingManager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let immediateManager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let gidInt = try #require(Int(gid))
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": gidInt,
                "token": "token",
                "current_gid": gidInt,
                "current_key": "updated-key",
                "parent_gid": gidInt,
                "parent_key": "token",
                "first_gid": gidInt,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        try #require(HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )),
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    responseData
                )
            }

            if url.host == "example.com" {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )),
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let scaffoldDownload = sampleDownload(
            gid: gid,
            title: "Pause Race",
            status: .partial,
            pageCount: 156,
            completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: ""
        )
        let (payload, updatedVersionSignature) = try await queueingManager.testingFetchLatestPayload(
            for: scaffoldDownload,
            mode: .update
        )

        let pageCount = payload.galleryDetail.pageCount
        #expect(pageCount > pageIndex)
        #expect(pageCount > 5)
        let oldCount = pageCount - 5
        #expect(oldCount != pageCount)
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)

        // Queued update path: retryPages should queue a full update and keep no page-selection state.
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: oldCount - 1,
            pageCount: oldCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: updatedVersionSignature
        )

        let queuedCandidate = await queueingManager.testingFetchDownload(gid: gid)
        #expect(queuedCandidate?.hasUpdate == true)

        let blockerTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        await queueingManager.testingInstallActiveTask(gid: "blocker", task: blockerTask)
        defer { blockerTask.cancel() }

        let retryResult = await queueingManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = retryResult else {
            Issue.record("retryPages should succeed, got \(retryResult)")
            return
        }

        let queued = await queueingManager.testingFetchDownload(gid: gid)
        #expect(queued?.status == .partial)
        #expect(queued?.pendingOperation == .update)
        #expect(queued?.lastError == nil)
        if FileManager.default.fileExists(atPath: temporaryFolderURL.path) {
            let queuedResumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
            #expect(queuedResumeState.mode == .update)
            #expect(queuedResumeState.pageSelection == nil)
            #expect(queuedResumeState.pageSelection != [pageIndex])
        }

        try clearPersistedDownloads(in: container)
        try? storage.removeTemporaryFolder(gid: gid)

        // Immediate update path: retryPages should normalize the working set to full-update semantics.
        let manifest = try sampleManifest(
            gid: gid,
            title: "Pause Race",
            pageCount: pageCount,
            versionSignature: updatedVersionSignature
        )
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(manifest).write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: temporaryFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        for index in 1...pageCount where index != pageIndex {
            try Data([UInt8(index % 255)]).write(
                to: temporaryFolderURL.appendingPathComponent(
                    "pages/\(String(format: "%04d", index)).jpg"
                ),
                options: .atomic
            )
        }
        try storage.writeResumeState(
            .init(
                mode: .update,
                versionSignature: updatedVersionSignature,
                pageCount: pageCount,
                downloadOptions: .init(),
                pageSelection: [pageIndex]
            ),
            folderURL: temporaryFolderURL
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: oldCount - 1,
            pageCount: oldCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: updatedVersionSignature
        )

        let immediateBlockerTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        await immediateManager.testingInstallActiveTask(gid: gid, task: immediateBlockerTask)
        defer { immediateBlockerTask.cancel() }

        let immediateRetryResult = await immediateManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = immediateRetryResult else {
            Issue.record("Immediate retryPages should succeed, got \(immediateRetryResult)")
            return
        }

        let resumedState = try storage.readResumeState(folderURL: temporaryFolderURL)
        #expect(resumedState.mode == .update)
        #expect(resumedState.versionSignature == updatedVersionSignature)
        #expect(resumedState.pageCount == pageCount)
        #expect(resumedState.pageSelection == nil)
        #expect(resumedState.pageSelection != [pageIndex])
        let resumedDownload = await immediateManager.testingFetchDownload(gid: gid)
        #expect(resumedDownload?.status == .downloading)
        #expect(resumedDownload?.pendingOperation == nil)
        #expect(resumedDownload?.lastError == nil)
    }

    @Test
    func testProcessDownloadClearsStalePageSelectionWhenLatestPayloadRevealsUpdate() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 401)
        let pageIndex = 42
        let oldVersionSignature = try #require(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        var allowedImageURLs = Set<String>()
        let gidInt = try #require(Int(gid))
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": gidInt,
                "token": "token",
                "current_gid": gidInt,
                "current_key": "updated-key",
                "parent_gid": gidInt,
                "parent_key": "token",
                "first_gid": gidInt,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        try #require(HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )),
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    responseData
                )
            }

            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )),
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let scaffoldDownload = sampleDownload(
            gid: gid,
            title: "Pause Race",
            status: .partial,
            pageCount: 156,
            completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        let (latestPayload, updatedVersionSignature) = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload,
            mode: .redownload,
            pageSelection: [pageIndex]
        )
        if let coverURL = latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL {
            allowedImageURLs.insert(coverURL.absoluteString)
        }

        let updatedPageCount = latestPayload.galleryDetail.pageCount
        #expect(updatedPageCount > pageIndex)
        #expect(updatedPageCount > 5)
        let oldPageCount = updatedPageCount - 5
        #expect(oldPageCount != updatedPageCount)

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: oldPageCount - 1,
            pageCount: oldPageCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )

        let beforeProcess = await manager.testingFetchDownload(gid: gid)
        #expect(beforeProcess?.hasUpdate ?? true == false)

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let staleManifest = try sampleManifest(
            gid: gid,
            title: "Pause Race",
            pageCount: oldPageCount,
            versionSignature: oldVersionSignature
        )
        try JSONEncoder().encode(staleManifest).write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: temporaryFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([UInt8(pageIndex % 255)]).write(
            to: temporaryFolderURL.appendingPathComponent(
                "pages/\(String(format: "%04d", pageIndex)).jpg"
            ),
            options: .atomic
        )
        try storage.writeResumeState(
            .init(
                mode: .redownload,
                versionSignature: oldVersionSignature,
                pageCount: oldPageCount,
                downloadOptions: .init(),
                pageSelection: [pageIndex]
            ),
            folderURL: temporaryFolderURL
        )

        await manager.testingProcessDownload(gid: gid)

        let completedDownload = await manager.testingFetchDownload(gid: gid)
        let unwrappedCompletedDownload = try #require(completedDownload)
        #expect(unwrappedCompletedDownload.status == .completed)
        #expect(unwrappedCompletedDownload.pageCount == updatedPageCount)
        #expect(unwrappedCompletedDownload.completedPageCount == updatedPageCount)
        #expect(unwrappedCompletedDownload.remoteVersionSignature == updatedVersionSignature)
        #expect(unwrappedCompletedDownload.latestRemoteVersionSignature == updatedVersionSignature)

        let completedFolderURL = storage.folderURL(relativePath: unwrappedCompletedDownload.folderRelativePath)
        let completedManifest = try storage.readManifest(folderURL: completedFolderURL)
        #expect(completedManifest.versionSignature == updatedVersionSignature)
        #expect(completedManifest.pageCount == updatedPageCount)
        #expect(completedManifest.pages.count == updatedPageCount)
        #expect(
            FileManager.default.fileExists(
                atPath: completedFolderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )

        let completedResumeState = try storage.readResumeState(folderURL: completedFolderURL)
        #expect(completedResumeState.mode == .redownload)
        #expect(completedResumeState.versionSignature == updatedVersionSignature)
        #expect(completedResumeState.pageCount == updatedPageCount)
        #expect(completedResumeState.pageSelection == nil)
        #expect(FileManager.default.fileExists(atPath: temporaryFolderURL.path) == false)
    }

    @MainActor
    @Test
    func testProcessDownloadClearsRemoteAssetCacheAfterSuccessfulDownload() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 402)
        let pageIndex = 42
        let oldVersionSignature = try #require(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let currentPageImageURL = try #require(
            URL(string: "https://example.com/image-\(pageIndex).jpg")
        )
        let staleStoredPageURL = try #require(
            URL(string: "https://example.com/stale-image-\(gid)-1.jpg")
        )
        let plainPreviewURL = try #require(
            URL(string: "https://ehgt.org/preview/\(gid)/1.webp")
        )
        let combinedPreviewURL = URLUtil.combinedPreviewURL(
            plainURL: plainPreviewURL,
            width: "200",
            height: "300",
            offset: "40"
        )
        var allowedImageURLs = Set<String>()
        let gidInt = try #require(Int(gid))
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": gidInt,
                "token": "token",
                "current_gid": gidInt,
                "current_key": "updated-key",
                "parent_gid": gidInt,
                "parent_key": "token",
                "first_gid": gidInt,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        try #require(HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )),
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": currentPageImageURL.absoluteString
                ])
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    responseData
                )
            }

            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )),
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let scaffoldDownload = sampleDownload(
            gid: gid,
            title: "Pause Race",
            status: .partial,
            pageCount: 156,
            completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        let (latestPayload, _) = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload,
            mode: .redownload,
            pageSelection: [pageIndex]
        )
        let coverURL = try #require(latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL)
        allowedImageURLs.insert(coverURL.absoluteString)

        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let cachedImageData = try #require(cachedImage.jpegData(compressionQuality: 1))

        let cachedURLs = combinedPreviewURL.previewCacheCleanupURLs()
            + [currentPageImageURL, staleStoredPageURL, coverURL]
        let cachedKeys = Set(cachedURLs.flatMap { $0.imageCacheKeys(includeStableAlias: true) })
        for cacheKey in cachedKeys {
            KingfisherManager.shared.cache.storeToDisk(cachedImageData, forKey: cacheKey)
        }
        defer {
            cachedKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) }
        }

        await waitUntilCacheReady(for: cachedKeys)

        let updatedPageCount = latestPayload.galleryDetail.pageCount
        let oldPageCount = updatedPageCount - 5
        #expect(updatedPageCount > pageIndex)
        #expect(oldPageCount > 0)

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: oldPageCount - 1,
            pageCount: oldPageCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        try insertPersistedGalleryState(
            in: container,
            gid: gid,
            previewURLs: [1: combinedPreviewURL],
            imageURLs: [1: staleStoredPageURL]
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let staleManifest = try sampleManifest(
            gid: gid,
            title: "Pause Race",
            pageCount: oldPageCount,
            versionSignature: oldVersionSignature
        )
        try JSONEncoder().encode(staleManifest).write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: temporaryFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([UInt8(pageIndex % 255)]).write(
            to: temporaryFolderURL.appendingPathComponent(
                "pages/\(String(format: "%04d", pageIndex)).jpg"
            ),
            options: .atomic
        )
        try storage.writeResumeState(
            .init(
                mode: .redownload,
                versionSignature: oldVersionSignature,
                pageCount: oldPageCount,
                downloadOptions: .init(),
                pageSelection: [pageIndex]
            ),
            folderURL: temporaryFolderURL
        )

        await manager.testingProcessDownload(gid: gid)

        let completedDownload = await manager.testingFetchDownload(gid: gid)
        #expect(completedDownload?.status == .completed)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while cachedKeys.contains(where: { KingfisherManager.shared.cache.isCached(forKey: $0) }),
              clock.now < deadline
        {
            try? await Task.sleep(for: .milliseconds(10))
        }

        for cacheKey in cachedKeys {
            #expect(
                KingfisherManager.shared.cache.isCached(forKey: cacheKey) == false,
                "Expected cache key to be removed after successful download: \(cacheKey)"
            )
        }
    }

    @MainActor
    @Test
    func testDownloadsReducerRefreshesWithoutResumingQueueAfterPauseFailure() async {
        let download = sampleDownload(
            gid: "987655",
            title: "Queued Gallery",
            status: .queued,
            completedPageCount: 3
        )
        let reconcileCount = UncheckedBox(0)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { _ in nil },
                reconcileDownloads: {
                    reconcileCount.value += 1
                },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .failure(.networkingFailed) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone)
        await store.finish()

        #expect(reconcileCount.value == 1)
    }

    @MainActor
    @Test
    func testDownloadsReducerRefreshDownloadsUsesClientRefresh() async {
        let refreshCount = UncheckedBox(0)
        let reconcileCount = UncheckedBox(0)

        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                reconcileDownloads: {
                    reconcileCount.value += 1
                },
                refreshDownloads: {
                    refreshCount.value += 1
                },
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }

        await store.send(.refreshDownloads)
        await store.receive(\.refreshDownloadsDone)

        #expect(refreshCount.value == 1)
        #expect(reconcileCount.value == 0)
    }

    @MainActor
    @Test
    func testDownloadsReducerBootstrapUsesClientRefresh() async {
        let refreshCount = UncheckedBox(0)
        let reconcileCount = UncheckedBox(0)

        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                reconcileDownloads: {
                    reconcileCount.value += 1
                },
                refreshDownloads: {
                    refreshCount.value += 1
                },
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }

        await store.send(.bootstrapDownloads)
        await store.receive(\.refreshDownloadsDone)

        #expect(refreshCount.value == 1)
        #expect(reconcileCount.value == 0)
    }

    @MainActor
    @Test
    func testDetailReducerStartDownloadEnqueuesGalleryWithSnapshotOptions() async throws {
        let capturedPayload = UncheckedBox<DownloadRequestPayload?>(nil)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot(
            threadMode: .quadruple,
            allowCellular: false,
            autoRetryFailedPages: false
        )
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.galleryPreviewURLs = [
            1: try #require(URL(string: "https://example.com/1.jpg"))
        ]
        initialState.previewConfig = .large(rows: 2)

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .queued) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { payload in
                    capturedPayload.value = payload
                    return .success(())
                },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.startDownload(options))
        await store.skipReceivedActions(strict: false)

        #expect(capturedPayload.value?.gallery.gid == gallery.gid)
        #expect(capturedPayload.value?.galleryDetail == detail)
        #expect(capturedPayload.value?.previewConfig == .large(rows: 2))
        #expect(capturedPayload.value?.options == options)
        #expect(capturedPayload.value?.mode == .initial)
        #expect(store.state.downloadBadge == .queued)
    }

    @MainActor
    @Test
    func testDetailReducerStartDownloadUnlocksActionsAfterQueueing() async throws {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot()
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.galleryPreviewURLs = [
            1: try #require(URL(string: "https://example.com/1.jpg"))
        ]

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .queued) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.startDownload(options)) {
            $0.isPreparingDownload = true
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.startDownloadDone) {
            $0.isPreparingDownload = false
            $0.downloadBadge = .queued
            $0.hasLoadedDownloadBadge = true
        }
        await store.receive(\.fetchDownloadBadge)
        await store.receive(\.fetchDownloadBadgeDone, .queued) {
            $0.downloadBadge = .queued
            $0.hasLoadedDownloadBadge = true
        }
    }

    @MainActor
    @Test
    func testDetailReducerLaunchAutomationWaitsForResolvedDownloadBadge() async throws {
        let capturedPayload = UncheckedBox<DownloadRequestPayload?>(nil)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot()
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.galleryPreviewURLs = [
            1: try #require(URL(string: "https://example.com/1.jpg"))
        ]

        setenv("EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID", gallery.gid, 1)
        defer { unsetenv("EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID") }

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .queued) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { payload in
                    capturedPayload.value = payload
                    return .success(())
                },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.runLaunchAutomationIfNeeded(options))
        #expect(capturedPayload.value == nil)
        #expect(store.state.didRunLaunchAutomation == false)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded(options)) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.startDownload, options)
        await store.skipReceivedActions(strict: false)

        #expect(capturedPayload.value?.gallery.gid == gallery.gid)
    }

    @MainActor
    @Test
    func testDetailReducerLaunchAutomationDoesNotRedownloadWhenBadgeIsResolved() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot()
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        setenv("EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID", gallery.gid, 1)
        defer { unsetenv("EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID") }

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(.downloaded)) {
            $0.downloadBadge = .downloaded
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded(options)) {
            $0.didRunLaunchAutomation = true
        }
    }

    @MainActor
    @Test
    func testDetailReducerIgnoresStartDownloadWhilePreparing() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let enqueueCount = UncheckedBox(0)
        let options = DownloadOptionsSnapshot()

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.isPreparingDownload = true

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in
                    enqueueCount.value += 1
                    return .success(())
                },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }

        await store.send(.startDownload(options))

        #expect(enqueueCount.value == 0)
        #expect(store.state.isPreparingDownload)
        #expect(store.state.downloadBadge == .none)
    }

    @MainActor
    @Test
    func testDetailReducerTogglesPauseForActiveDownload() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let togglePauseCount = UncheckedBox(0)

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.downloadBadge = .downloading(7, 26)

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .paused(7, 26)) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in
                    togglePauseCount.value += 1
                    return .success(())
                },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause) {
            $0.isPreparingDownload = true
        }
        await store.receive(\.toggleDownloadPauseDone) {
            $0.isPreparingDownload = false
            $0.downloadBadge = .paused(7, 26)
            $0.hasLoadedDownloadBadge = true
        }
        await store.receive(\.fetchDownloadBadge)
        await store.receive(\.fetchDownloadBadgeDone, .paused(7, 26)) {
            $0.downloadBadge = .paused(7, 26)
            $0.hasLoadedDownloadBadge = true
        }

        #expect(togglePauseCount.value == 1)
        #expect(store.state.downloadBadge == .paused(7, 26))
        #expect(store.state.isPreparingDownload == false)
    }

    @MainActor
    @Test
    func testDetailReducerObservesDownloadBadgeTransitions() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let continuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let stream = AsyncStream<[DownloadedGallery]> { continuation in
            continuationBox.value = continuation
        }

        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: { stream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .none) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.onAppear(gallery.gid, false)) {
            $0.gid = gallery.gid
            $0.showsNewDawnGreeting = false
            $0.hasLoadedDownloadBadge = false
            $0.didRunLaunchAutomation = false
        }
        await store.skipReceivedActions(strict: false)

        continuationBox.value?.yield([
            sampleDownload(gid: gallery.gid, title: gallery.title, status: .queued)
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = .queued
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.yield([
            sampleDownload(
                gid: gallery.gid,
                title: gallery.title,
                status: .downloading,
                pageCount: 26,
                completedPageCount: 7
            )
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = .downloading(7, 26)
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.yield([
            sampleDownload(
                gid: gallery.gid,
                title: gallery.title,
                status: .completed,
                pageCount: 26,
                completedPageCount: 26
            )
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = .downloaded
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.finish()
    }

    @MainActor
    @Test
    func testDetailReducerOpenReadingUsesLocalManifestWhenAvailable() async throws {
        let download = sampleDownload(
            gid: "888",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        var initialState = DetailReducer.State(download: download)
        initialState.galleryDetail = sampleGalleryDetail(gid: download.gid, title: download.title)

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .downloaded) })
                },
                updateRemoteSignature: { _, _ in .downloaded },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { gid in
                    gid == download.gid
                    ? .success((download, manifest))
                    : .failure(.notFound)
                }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.openReading)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.readingState.contentSource == .local(download, manifest))
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

    @MainActor
    @Test
    func testDetailReducerOpenReadingFallsBackToRemoteWhenManifestUnavailable() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.openReading)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.readingState.contentSource == .remote)
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

    @MainActor
    @Test
    func testPreviewsReducerOpenReadingUsesLocalManifestWhenAvailable() async throws {
        let download = sampleDownload(
            gid: "991",
            title: "Preview Download",
            status: .completed,
            pageCount: 2,
            completedPageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        var initialState = PreviewsReducer.State()
        initialState.gallery = download.gallery

        let store = TestStore(initialState: initialState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { gid in
                    gid == download.gid
                    ? .success((download, manifest))
                    : .failure(.notFound)
                }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.openReading(1))
        await store.skipReceivedActions(strict: false)

        if case .local(let actualDownload, let actualManifest) = store.state.readingState.contentSource {
            #expect(actualDownload == download)
            #expect(actualManifest == manifest)
        } else {
            Issue.record("Expected previews to open local reading content.")
        }
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

    @MainActor
    @Test
    func testPreviewsReducerClearsLocalPreviewURLsWhenObservedDownloadDisappears() async {
        let gallery = sampleGallery()
        let localURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery
        initialState.localPreviewURLs = [1: localURL]

        let store = TestStore(initialState: initialState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.observeDownloadsDone([]))
        await store.receive(\.loadLocalPreviewURLs)
        let requestID = store.state.localPreviewRequestID
        await store.receive(\.loadLocalPreviewURLsDone) {
            $0.localPreviewURLs = [:]
        }
        #expect(store.state.localPreviewRequestID == requestID)
    }

    @MainActor
    @Test
    func testPreviewsReducerRemoteFallbackKeepsExistingLocalPreviewPages() async {
        let gallery = sampleGallery()
        let localURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery
        initialState.localPreviewURLs = [1: localURL]

        let store = TestStore(initialState: initialState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.openReading(1))
        await store.receive(\.openReadingDone)
        guard case .reading = store.state.route else {
            Issue.record("Expected previews route to enter reading")
            return
        }
        #expect(store.state.readingState.contentSource == .remote)
        #expect(store.state.readingState.localPageURLs == [1: localURL])
    }

    @MainActor
    @Test
    func testDetailReducerDownloadedContextStoresVersionMetadataResult() async {
        let download = sampleDownload(
            gid: "889",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let detail = sampleGalleryDetail(gid: download.gid, title: download.title)
        var initialState = DetailReducer.State(download: download)
        initialState.galleryDetail = detail
        let metadata = DownloadVersionMetadata(
            gid: detail.gid,
            token: download.token,
            currentGID: "990",
            currentKey: "chain-key",
            parentGID: download.gid,
            parentKey: download.token,
            firstGID: download.gid,
            firstKey: download.token
        )

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        }

        await store.send(
            .fetchVersionMetadataDone(.success(metadata))
        ) {
            $0.galleryVersionMetadata = metadata
        }
    }

    @MainActor
    @Test
    func testReadingReducerRemoteSourceLoadsLocalPagesAndSkipsRemoteFetchForDownloadedPage() async throws {
        let gallery = sampleGallery()
        let localPageURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        let remotePageURL = try #require(URL(string: "https://example.com/pages/0001.jpg"))
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.imageURLs = [1: remotePageURL]

        let store = TestStore(
            initialState: initialState
        ) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.yield([])
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    gid == gallery.gid ? .success([1: localPageURL]) : .failure(.notFound)
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.loadLocalPageURLs(gallery.gid))
        let requestID = store.state.localPageRequestID
        await store.receive(\.loadLocalPageURLsDone) {
            $0.localPageURLs = [1: localPageURL]
        }
        #expect(store.state.localPageRequestID == requestID)

        #expect(store.state.localPageURLs[1] == localPageURL)

        await store.send(.fetchImageURLs(1)) {
            $0.imageURLLoadingStates[1] = .idle
        }
    }

    @MainActor
    @Test
    func testReadingReducerOnWebImageSucceededCapturesCachedPageIntoDownloadProgress() async throws {
        let capturedCalls = UncheckedBox([(String, Int, URL?)]())
        let gallery = sampleGallery()
        let remotePageURL = try #require(URL(string: "https://example.com/pages/0001.jpg"))
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.imageURLs = [1: remotePageURL]

        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                captureCachedPage: { gid, index, imageURL in
                    capturedCalls.value.append((gid, index, imageURL))
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.onWebImageSucceeded(1)) {
            $0.imageURLLoadingStates[1] = .idle
            $0.webImageLoadSuccessIndices.insert(1)
        }
        await store.receive(\.captureCachedPage)

        #expect(capturedCalls.value.count == 1)
        #expect(capturedCalls.value.first?.0 == gallery.gid)
        #expect(capturedCalls.value.first?.1 == 1)
        #expect(capturedCalls.value.first?.2 == remotePageURL)
    }

    @MainActor
    @Test
    func testReadingReducerOnWebImageSucceededDoesNotCaptureAlreadyLocalPage() async {
        let capturedCalls = UncheckedBox([(String, Int, URL?)]())
        let gallery = sampleGallery()
        let localPageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("0001.jpg")
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.localPageURLs = [1: localPageURL]

        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                captureCachedPage: { gid, index, imageURL in
                    capturedCalls.value.append((gid, index, imageURL))
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.onWebImageSucceeded(1)) {
            $0.imageURLLoadingStates[1] = .idle
            $0.webImageLoadSuccessIndices.insert(1)
        }
        await store.finish()

        #expect(capturedCalls.value.isEmpty)
    }

    @MainActor
    @Test
    func testReadingReducerLocalSourceLoadsOfflineImagesWithoutNetwork() async throws {
        let download = sampleDownload(
            gid: "777",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        let folderURL = try prepareLocalDownloadFiles(download: download, manifest: manifest)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let store = TestStore(
            initialState: ReadingReducer.State(contentSource: .local(download, manifest))
        ) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDatabaseInfos(download.gid))
        #expect(store.state.gallery.id == download.gid)
        #expect(store.state.imageURLs[1] == folderURL.appendingPathComponent("pages/0001.jpg"))
        #expect(store.state.imageURLs[2] == folderURL.appendingPathComponent("pages/0002.jpg"))

        await store.send(.fetchImageURLs(1)) {
            $0.imageURLLoadingStates[1] = .idle
        }
        await store.send(.reloadAllWebImages)

        #expect(store.state.imageURLs[1] == folderURL.appendingPathComponent("pages/0001.jpg"))
        #expect(store.state.imageURLs[2] == folderURL.appendingPathComponent("pages/0002.jpg"))
    }

    @MainActor
    @Test
    func testDownloadManagerCaptureCachedPageRestoresTemporaryPageAndUpdatesCompletedCount() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 27)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 0,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )

        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 1))
        let cacheKey = try #require(imageURL.stableImageCacheKey)
        KingfisherManager.shared.cache.store(image, original: imageData, forKey: cacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: cacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: imageURL.absoluteString)
        }

        await manager.captureCachedPage(
            gid: gid,
            index: 1,
            imageURL: imageURL
        )

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.completedPageCount == 1)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
        #expect(pageURLs[1] == temporaryFolderURL.appendingPathComponent("pages/0001.jpg"))
    }

    @MainActor
    @Test
    func testDownloadManagerCaptureCachedPageRepairsCompletedDownloadWithLatestRemoteImage() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 28)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .missingFiles,
            completedPageCount: 1,
            pageCount: 2,
            lastError: .init(code: .fileOperationFailed, message: "Page 1 is missing.")
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 1))
        let cacheKey = try #require(imageURL.stableImageCacheKey)
        KingfisherManager.shared.cache.store(image, original: imageData, forKey: cacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: cacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: imageURL.absoluteString)
        }

        await manager.captureCachedPage(
            gid: gid,
            index: 1,
            imageURL: imageURL
        )

        let stored = await manager.testingFetchDownload(gid: gid)
        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.status == .completed)
        #expect(stored?.completedPageCount == 2)
        #expect(stored?.lastError == nil)
        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent("pages/0001.jpg"))
    }

    @MainActor
    @Test
    func testDownloadManagerReconcileNormalizesFailedDownloadBeforeTempCleanup() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 31)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 0,
            pageCount: 2,
            lastError: .init(code: .networkingFailed, message: "Network Error")
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        let localPages = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.status == .partial)
        #expect(stored?.completedPageCount == 1)
        #expect(FileManager.default.fileExists(atPath: temporaryFolderURL.path))
        #expect(localPages[1] == temporaryFolderURL.appendingPathComponent("pages/0001.jpg"))
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureDoesNotMarkUpdateAvailableWhenStoredChainAndLatestHashAreDifferentKinds() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 101)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "chain:\(gid):token"
        )

        let badge = await manager.updateRemoteSignature(gid: gid, latestSignature: "hash:new")
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "chain:\(gid):token")
        #expect(stored?.latestRemoteVersionSignature == "hash:new")
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureDoesNotMarkUpdateAvailableWhenStoredHashAndLatestNonOriginalChainAreDifferentKinds() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 102)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "hash:old"
        )

        let badge = await manager.updateRemoteSignature(
            gid: gid,
            latestSignature: "chain:othergid:othertoken"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "hash:old")
        #expect(stored?.latestRemoteVersionSignature == "chain:othergid:othertoken")
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureCanonicalizesStoredHashToOriginalChainWithoutMarkingUpdate() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 103)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "hash:old"
        )

        let badge = await manager.updateRemoteSignature(
            gid: gid,
            latestSignature: "chain:\(gid):token"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "chain:\(gid):token")
        #expect(stored?.latestRemoteVersionSignature == "chain:\(gid):token")
    }

    @MainActor
    @Test
    func testDetailReducerDoesNotRequestVersionMetadataForUndownloadedGallery() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        var galleryState = GalleryState(gid: gallery.gid)
        galleryState.previewURLs = [1: try #require(URL(string: "https://example.com/1t.jpg"))]
        galleryState.previewConfig = .normal(rows: 4)

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .none) })
                },
                updateRemoteSignature: { _, _ in
                    updateCheckCount.value += 1
                    return .none
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(
            .fetchGalleryDetailDone(
                .success((detail, galleryState, "", nil))
            )
        )
        await store.skipReceivedActions(strict: false)

        #expect(updateCheckCount.value == 0)
        #expect(store.state.galleryVersionMetadata == nil)
        #expect(store.state.shouldCheckForRemoteUpdates == false)
    }

    @MainActor
    @Test
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesAfterDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = try sampleGalleryState(gid: gallery.gid)
        let sessionID = UUID().uuidString
        try installGalleryVersionMetadataStub(for: gallery, sessionID: sessionID)
        defer { uninstallSharedSessionStub(sessionID: sessionID) }

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .none) })
                },
                updateRemoteSignature: { _, _ in
                    updateCheckCount.value += 1
                    return .downloaded
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchGalleryDetailDone(.success((detail, galleryState, "", nil))))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 0)

        await store.send(.fetchDownloadBadgeDone(.downloaded))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )

        #expect(updateCheckCount.value == 1)
        #expect(store.state.shouldCheckForRemoteUpdates)
        #expect(store.state.didRequestVersionMetadata)
        #expect(store.state.galleryVersionMetadata != nil)
    }

    @MainActor
    @Test
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesBeforeDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = try sampleGalleryState(gid: gallery.gid)
        let sessionID = UUID().uuidString
        try installGalleryVersionMetadataStub(for: gallery, sessionID: sessionID)
        defer { uninstallSharedSessionStub(sessionID: sessionID) }

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .downloaded) })
                },
                updateRemoteSignature: { _, _ in
                    updateCheckCount.value += 1
                    return .downloaded
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(.downloaded))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 0)

        await store.send(.fetchGalleryDetailDone(.success((detail, galleryState, "", nil))))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )

        #expect(updateCheckCount.value == 1)
        #expect(store.state.shouldCheckForRemoteUpdates)
        #expect(store.state.didRequestVersionMetadata)
        #expect(store.state.galleryVersionMetadata != nil)
    }

    @MainActor
    @Test
    func testDetailReducerObserveDownloadDoneAlsoTriggersMetadataCheckWithoutDuplicateRequests() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let sessionID = UUID().uuidString
        try installGalleryVersionMetadataStub(for: gallery, sessionID: sessionID)
        defer { uninstallSharedSessionStub(sessionID: sessionID) }

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in
                    updateCheckCount.value += 1
                    return .downloaded
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.observeDownloadDone(.downloaded))
        await drainDetailMetadataEffects(
            store,
            condition: { updateCheckCount.value == 1 }
        )
        #expect(updateCheckCount.value == 1)

        await store.send(.observeDownloadDone(.downloaded))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 1)
    }

    @MainActor
    @Test
    func testDetailReducerRemoteUpdateFlagDoesNotStayStickyWhenBadgeReturnsToNone() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let sessionID = UUID().uuidString
        try installGalleryVersionMetadataStub(for: gallery, sessionID: sessionID)
        defer { uninstallSharedSessionStub(sessionID: sessionID) }

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in
                    updateCheckCount.value += 1
                    return .downloaded
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(.downloaded))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )
        #expect(updateCheckCount.value == 1)
        #expect(store.state.shouldCheckForRemoteUpdates)
        #expect(store.state.didRequestVersionMetadata)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.downloadBadge = .none
            $0.hasLoadedDownloadBadge = true
            $0.shouldCheckForRemoteUpdates = false
            $0.didRequestVersionMetadata = false
            $0.galleryVersionMetadata = nil
        }
        await store.skipReceivedActions(strict: false)

        #expect(store.state.shouldCheckForRemoteUpdates == false)
        #expect(store.state.didRequestVersionMetadata == false)
        #expect(store.state.galleryVersionMetadata == nil)
    }

    @MainActor
    @Test
    func testDetailReducerDeleteDownloadResetsDownloadContext() async {
        let download = sampleDownload(
            gid: "7733",
            title: "Reset Context",
            status: .completed
        )
        var initialState = DetailReducer.State(download: download)
        initialState.galleryVersionMetadata = sampleVersionMetadata(
            gid: download.gid,
            token: download.token
        )
        initialState.didRequestVersionMetadata = true

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .none) })
                },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in .success([:]) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.deleteDownloadDone(.success(()))) {
            $0.galleryVersionMetadata = nil
            $0.didRequestVersionMetadata = false
            $0.isDownloadContext = false
            $0.shouldCheckForRemoteUpdates = false
        }
        await store.skipReceivedActions(strict: false)

        #expect(store.state.isDownloadContext == false)
        #expect(store.state.shouldCheckForRemoteUpdates == false)
        #expect(store.state.didRequestVersionMetadata == false)
        #expect(store.state.galleryVersionMetadata == nil)
    }

    @Test
    func testFileBasedQuotaImageMapsToQuotaExceeded() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedQuotaImageRequiresKnown509Signature() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        var data = try Data(contentsOf: fileURL)
        data[0] = 0
        try data.write(to: fileURL, options: .atomic)
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: data.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == nil)
    }

    @Test
    func testFileBasedBinaryKokomadeImageMapsToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gif")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imageData = try #require(Data(base64Encoded: "R0lGODlhAQABAIABAP///wAAACwAAAAAAQABAAACAkQBADs="))
        try imageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let kokomadeURL = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
        let response = try makeResponse(
            url: kokomadeURL,
            contentType: "image/gif",
            contentLength: imageData.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedQuotaImageFingerprintMapsToQuotaExceededEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try #require(URL(string: "https://ehgt.org/h/normal-image-cache-key/1"))
        let response = try makeResponse(
            url: normalImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: normalImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedKokomadeImageFingerprintMapsToAuthenticationRequiredEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(resource: "Kokomade", pathExtension: "jpg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try #require(URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1&key=normal-cache-key"))
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: try makeResponse(
                url: normalImageURL,
                contentType: "image/jpeg",
                contentLength: 144844
            ),
            requestURL: normalImageURL
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedTextImageLimitMapsToQuotaExceeded() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let htmlData = try #require("""
        <html><body>You have exceeded your image viewing limits</body></html>
        """.data(using: .utf8))
        try htmlData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let quotaURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: quotaURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaURL
        )

        #expect(error == .quotaExceeded)
    }

    @MainActor
    @Test
    func testCachedQuotaPlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 32)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        let normalImageURL = try #require(
            URL(string: "https://ehgt.org/h/quota-placeholder-cache-\(gid)/1")
        )
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: [1: normalImageURL])

        let placeholderURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: placeholderURL) }
        let placeholderData = try Data(contentsOf: placeholderURL)
        let cacheKeys = normalImageURL.imageCacheKeys(includeStableAlias: true)
        for cacheKey in cacheKeys {
            KingfisherManager.shared.cache.storeToDisk(placeholderData, forKey: cacheKey)
        }
        defer {
            cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) }
        }
        await waitUntilCacheReady(for: cacheKeys)

        let payload = DownloadRequestPayload(
            gallery: Gallery(
                gid: gid,
                token: "token",
                title: "Quota Placeholder",
                rating: 4,
                tags: [],
                category: .doujinshi,
                uploader: "Uploader",
                pageCount: 1,
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: try #require(URL(string: "https://e-hentai.org/g/\(gid)/token"))
            ),
            galleryDetail: GalleryDetail(
                gid: gid,
                title: "Quota Placeholder",
                jpnTitle: nil,
                isFavorited: false,
                visibility: .yes,
                rating: 4,
                userRating: 0,
                ratingCount: 0,
                category: .doujinshi,
                language: .japanese,
                uploader: "Uploader",
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0,
                pageCount: 1,
                sizeCount: 12,
                sizeType: "MB",
                torrentCount: 0
            ),
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            options: DownloadOptionsSnapshot(),
            mode: .initial
        )

        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let restoredPageURL = storage.temporaryFolderURL(gid: gid)
            .appendingPathComponent("pages/0001.gif")

        #expect(restoredCount == 0)
        #expect(FileManager.default.fileExists(atPath: restoredPageURL.path) == false)
    }

    @MainActor
    @Test
    func testCachedKokomadePlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 33)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        let normalImageURL = try #require(URL(string: "https://exhentai.org/fullimg.php?gid=\(gid)&page=1&key=normal-cache-key"))
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: [1: normalImageURL])

        let imageData = try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        let cacheKeys = normalImageURL.imageCacheKeys(includeStableAlias: true)
        for cacheKey in cacheKeys {
            KingfisherManager.shared.cache.storeToDisk(imageData, forKey: cacheKey)
        }
        defer {
            cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) }
        }
        await waitUntilCacheReady(for: cacheKeys)

        let payload = DownloadRequestPayload(
            gallery: Gallery(
                gid: gid,
                token: "token",
                title: "Auth Placeholder",
                rating: 4,
                tags: [],
                category: .doujinshi,
                uploader: "Uploader",
                pageCount: 1,
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: try #require(URL(string: "https://exhentai.org/g/\(gid)/token"))
            ),
            galleryDetail: GalleryDetail(
                gid: gid,
                title: "Auth Placeholder",
                jpnTitle: nil,
                isFavorited: false,
                visibility: .yes,
                rating: 4,
                userRating: 0,
                ratingCount: 0,
                category: .doujinshi,
                language: .japanese,
                uploader: "Uploader",
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0,
                pageCount: 1,
                sizeCount: 12,
                sizeType: "MB",
                torrentCount: 0
            ),
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .exhentai,
            options: DownloadOptionsSnapshot(),
            mode: .initial
        )

        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let restoredPageURL = storage.temporaryFolderURL(gid: gid)
            .appendingPathComponent("pages/0001.jpg")

        #expect(restoredCount == 0)
        #expect(FileManager.default.fileExists(atPath: restoredPageURL.path) == false)
    }

    @Test
    func testFileBasedEmptyExResponseMapsToAuthenticationRequired() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .exLoginRequired)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        defer { cookieClient.clearAll() }
        cookieClient.setOrEditCookie(
            for: Defaults.URL.exhentai,
            key: Defaults.Cookie.yay,
            value: "louder"
        )

        let manager = makeTestingDownloadManager()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
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
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let authHTMLData = try #require("""
        <html>
          <body>
            <a href="bounce_login.php">Login</a>
            <img src="/img/kokomade.jpg">
            <p>Access to ExHentai.org is restricted.</p>
          </body>
        </html>
        """.data(using: .utf8))
        try authHTMLData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedInvalidPageMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let invalidPageData = try #require("""
        <html><body><h1>Invalid page</h1><p>Gallery not found</p></body></html>
        """.data(using: .utf8))
        try invalidPageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: galleryURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedKeepTryingMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let keepTryingData = try #require(
            "<html><body><h1>Keep trying</h1></body></html>".data(using: .utf8)
        )
        try keepTryingData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let pageURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: pageURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: pageURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedHTTP404MapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try Data("Not here".utf8).write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let notFoundURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: notFoundURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: notFoundURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBased404GalleryNotAvailableFallsBackToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let galleryNotAvailableData = try #require("""
        <html>
          <head><title>Gallery Not Available</title></head>
          <body><h1>Gallery Not Available</h1></body>
        </html>
        """.data(using: .utf8))
        try galleryNotAvailableData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: galleryURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedHTMLBanPageStillParsesThroughParserInsteadOfParseFailed() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .ipBanned)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let bannedURL = try #require(URL(string: "https://example.com/banned"))
        let response = try makeResponse(
            url: bannedURL,
            contentType: "text/html; charset=utf-8"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: bannedURL
        )

        #expect(error != .parseFailed)
        guard case .ipBanned = error else {
            Issue.record("Expected ipBanned, got \(String(describing: error))")
            return
        }
    }

    @Test
    func testIpBannedDoesNotRetryImmediately() async throws {
        let sessionID = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let manager = DownloadManager(
            storage: DownloadFileStorage(
                rootURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true),
                fileManager: .default
            ),
            urlSession: URLSession(configuration: configuration)
        )
        let recorder = RequestRecorder()
        let ipBannedHTML = try fixtureData(resource: HTMLFilename.ipBanned.rawValue, pathExtension: "html")
        let fallbackBannedURL = try #require(URL(string: "https://example.com/banned"))
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            recorder.recordDetail()
            return (
                try #require(HTTPURLResponse(
                    url: request.url ?? fallbackBannedURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html; charset=utf-8"]
                )),
                ipBannedHTML
            )
        }
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let download = sampleDownload(
            gid: "123456",
            title: "Banned Gallery",
            status: .partial
        )

        do {
            _ = try await manager.testingFetchLatestPayload(
                for: download,
                mode: .redownload
            )
            Issue.record("Expected ipBanned error")
        } catch let error as AppError {
            guard case .ipBanned = error else {
                Issue.record("Expected ipBanned, got \(error)")
                return
            }
        }

        #expect(recorder.snapshot().detailRequests == 1)
    }

    @MainActor
    @Test
    func testReadingReducerLocalSourceWithoutGalleryStateDoesNotStayLoading() async throws {
        let download = sampleDownload(
            gid: "700001",
            title: "Offline Gallery",
            status: .completed,
            pageCount: 2,
            completedPageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        let store = TestStore(
            initialState: ReadingReducer.State(contentSource: .local(download, manifest))
        ) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off
        let folderURL = download.folderURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(download.folderRelativePath, isDirectory: true)

        await store.send(.fetchDatabaseInfos(download.gid)) {
            $0.gallery = download.gallery
            $0.galleryDetail = GalleryDetail(
                gid: download.gid,
                title: download.title,
                jpnTitle: download.jpnTitle,
                isFavorited: false,
                visibility: .yes,
                rating: download.rating,
                userRating: 0,
                ratingCount: 0,
                category: download.category,
                language: manifest.language,
                uploader: download.uploader ?? "",
                postedDate: download.postedDate,
                coverURL: download.coverURL,
                favoritedCount: 0,
                pageCount: download.pageCount,
                sizeCount: 0,
                sizeType: "",
                torrentCount: 0
            )
            $0.localPageURLs = [
                1: folderURL.appendingPathComponent("pages/0001.jpg"),
                2: folderURL.appendingPathComponent("pages/0002.jpg")
            ]
            $0.previewConfig = .normal(rows: 4)
            $0.previewURLs = $0.localPageURLs
            $0.thumbnailURLs = $0.localPageURLs
            $0.imageURLs = $0.localPageURLs
            $0.originalImageURLs = $0.localPageURLs
            $0.databaseLoadingState = .idle
        }
        await store.finish()

        #expect(store.state.databaseLoadingState == .idle)
        #expect(store.state.readingProgress == 0)
    }

    @MainActor
    @Test
    func testReadingReducerDoesNotReloadLocalPagesWhenOnlyOtherGalleryChanges() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(
            gid: gallery.gid,
            title: gallery.title,
            status: .completed
        )
        let otherDownload = sampleDownload(
            gid: "900001",
            title: "Other Gallery",
            status: .queued
        )
        let updatedOtherDownload = sampleDownload(
            gid: otherDownload.gid,
            title: otherDownload.title,
            status: .downloading,
            pageCount: 12,
            completedPageCount: 4
        )
        let continuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let stream = AsyncStream<[DownloadedGallery]> { continuation in
            continuationBox.value = continuation
        }
        let loadCount = UncheckedBox(0)

        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery

        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: { stream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    #expect(gid == gallery.gid)
                    loadCount.value += 1
                    return .success([:])
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.observeDownloads(gallery.gid))

        continuationBox.value?.yield([relevantDownload, otherDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPageURLs, gallery.gid)
        await store.receive(\.loadLocalPageURLsDone)
        #expect(loadCount.value == 1)

        continuationBox.value?.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))

        #expect(loadCount.value == 1)

        continuationBox.value?.finish()
        await store.finish()
    }

    @MainActor
    @Test
    func testPreviewsReducerDoesNotReloadLocalPreviewsWhenOnlyOtherGalleryChanges() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(
            gid: gallery.gid,
            title: gallery.title,
            status: .completed
        )
        let otherDownload = sampleDownload(
            gid: "900002",
            title: "Other Preview Gallery",
            status: .queued
        )
        let updatedOtherDownload = sampleDownload(
            gid: otherDownload.gid,
            title: otherDownload.title,
            status: .paused,
            pageCount: 12,
            completedPageCount: 2
        )
        let continuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let stream = AsyncStream<[DownloadedGallery]> { continuation in
            continuationBox.value = continuation
        }
        let loadCount = UncheckedBox(0)

        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery

        let store = TestStore(initialState: initialState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: { stream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    #expect(gid == gallery.gid)
                    loadCount.value += 1
                    return .success([:])
                }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.observeDownloads(gallery.gid))

        continuationBox.value?.yield([relevantDownload, otherDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPreviewURLs, gallery.gid)
        await store.receive(\.loadLocalPreviewURLsDone)
        #expect(loadCount.value == 1)

        continuationBox.value?.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))

        #expect(loadCount.value == 1)

        continuationBox.value?.finish()
        await store.finish()
    }

    @MainActor
    @Test
    func testReadingAndPreviewsStillEmitOneFinalRefreshWhenRelevantDownloadDisappears() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(
            gid: gallery.gid,
            title: gallery.title,
            status: .completed
        )

        let readingContinuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let readingStream = AsyncStream<[DownloadedGallery]> { continuation in
            readingContinuationBox.value = continuation
        }
        let readingLoadCount = UncheckedBox(0)
        var readingState = ReadingReducer.State(contentSource: .remote)
        readingState.gallery = gallery

        let readingStore = TestStore(initialState: readingState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: { readingStream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in
                    readingLoadCount.value += 1
                    return .success([:])
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        readingStore.exhaustivity = .off

        await readingStore.send(.observeDownloads(gallery.gid))
        readingContinuationBox.value?.yield([relevantDownload])
        await readingStore.receive(\.observeDownloadsDone, [relevantDownload])
        await readingStore.receive(\.loadLocalPageURLs, gallery.gid)
        await readingStore.receive(\.loadLocalPageURLsDone)

        readingContinuationBox.value?.yield([])
        await readingStore.receive(\.observeDownloadsDone, [])
        await readingStore.receive(\.loadLocalPageURLs, gallery.gid)
        await readingStore.receive(\.loadLocalPageURLsDone)

        #expect(readingLoadCount.value == 2)
        readingContinuationBox.value?.finish()
        await readingStore.finish()

        let previewsContinuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let previewsStream = AsyncStream<[DownloadedGallery]> { continuation in
            previewsContinuationBox.value = continuation
        }
        let previewsLoadCount = UncheckedBox(0)
        var previewsState = PreviewsReducer.State()
        previewsState.gallery = gallery

        let previewsStore = TestStore(initialState: previewsState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: { previewsStream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { _ in
                    previewsLoadCount.value += 1
                    return .success([:])
                }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        previewsStore.exhaustivity = .off

        await previewsStore.send(.observeDownloads(gallery.gid))
        previewsContinuationBox.value?.yield([relevantDownload])
        await previewsStore.receive(\.observeDownloadsDone, [relevantDownload])
        await previewsStore.receive(\.loadLocalPreviewURLs, gallery.gid)
        await previewsStore.receive(\.loadLocalPreviewURLsDone)

        previewsContinuationBox.value?.yield([])
        await previewsStore.receive(\.observeDownloadsDone, [])
        await previewsStore.receive(\.loadLocalPreviewURLs, gallery.gid)
        await previewsStore.receive(\.loadLocalPreviewURLsDone)

        #expect(previewsLoadCount.value == 2)
        previewsContinuationBox.value?.finish()
        await previewsStore.finish()
    }

    @MainActor
    @Test
    func testDownloadInspectorClearsInspectionWhenObservedDownloadDisappears() async {
        let download = sampleDownload(
            gid: "9988",
            title: "Observed Archive",
            status: .completed
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.yield([download])
                        continuation.yield([])
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(inspection) }
            )
        }
        store.exhaustivity = .off

        await store.send(.observeDownloads)
        await store.receive(\.observeDownloadsDone, [download])
        await store.receive(\.observeDownloadsDone, []) {
            $0.inspection = nil
            $0.stableInspection = nil
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadManagerBatchesObserverUpdatesDuringCachedPageRestore() async throws {
        let container = try makeInMemoryContainer()

        let pageCount = 20
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            persistenceContainer: container
        )
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 0,
            pageCount: pageCount
        )

        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(cachedImage.jpegData(compressionQuality: 1))
        let imageURLs = try Dictionary(uniqueKeysWithValues: (1...pageCount).map { index in
            (index, try #require(URL(string: "https://example.com/pages/\(gid)-\(index).jpg")))
        })
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: imageURLs)
        let cacheKeys = Set(imageURLs.values.flatMap { $0.imageCacheKeys(includeStableAlias: true) })
        for cacheKey in cacheKeys {
            KingfisherManager.shared.cache.storeToDisk(imageData, forKey: cacheKey)
        }
        defer {
            cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) }
        }
        await waitUntilCacheReady(for: cacheKeys)

        let observationStream = await manager.observeDownloads()
        let emissionTask = Task<Int, Never> {
            var emissionCount = 0
            for await downloads in observationStream {
                guard let relevantDownload = downloads.first(where: { $0.gid == gid }) else { continue }
                emissionCount += 1
                if relevantDownload.completedPageCount == pageCount {
                    break
                }
            }
            return emissionCount
        }

        let payload = DownloadRequestPayload(
            gallery: Gallery(
                gid: gid,
                token: "token",
                title: "Cached Restore Gallery",
                rating: 4,
                tags: [],
                category: .doujinshi,
                uploader: "Uploader",
                pageCount: pageCount,
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: try #require(URL(string: "https://e-hentai.org/g/\(gid)/token"))
            ),
            galleryDetail: GalleryDetail(
                gid: gid,
                title: "Cached Restore Gallery",
                jpnTitle: nil,
                isFavorited: false,
                visibility: .yes,
                rating: 4,
                userRating: 0,
                ratingCount: 0,
                category: .doujinshi,
                language: .japanese,
                uploader: "Uploader",
                postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0,
                pageCount: pageCount,
                sizeCount: 12,
                sizeType: "MB",
                torrentCount: 0
            ),
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            options: DownloadOptionsSnapshot(),
            mode: .initial
        )

        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let emissionCount = try await waitForTaskValue(
            emissionTask,
            timeout: .seconds(2),
            description: "observer updates for cached page restore"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(restoredCount == pageCount)
        #expect(stored?.completedPageCount == pageCount)
        #expect(emissionCount < pageCount)
        #expect(emissionCount <= 1 + Int(ceil(Double(pageCount) / 8.0)))
    }
}

private extension DownloadFeatureReducerTests {
    func waitUntilCacheReady<Keys: Sequence>(
        for keys: Keys,
        timeout: Duration = .seconds(1)
    ) async where Keys.Element == String {
        let cacheKeys = Array(keys)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !cacheKeys.allSatisfy({ KingfisherManager.shared.cache.isCached(forKey: $0) }),
              clock.now < deadline
        {
            try? await clock.sleep(until: clock.now.advanced(by: .milliseconds(10)), tolerance: .zero)
        }

        let missingKeys = cacheKeys.filter { !KingfisherManager.shared.cache.isCached(forKey: $0) }
        #expect(
            missingKeys.isEmpty,
            "Timed out waiting for Kingfisher cache visibility for keys: \(missingKeys)"
        )
    }

    func waitForTaskValue<T>(
        _ task: Task<T, Never>,
        timeout: Duration = .seconds(1),
        description: String
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                task.cancel()
                throw NSError(
                    domain: "DownloadFeatureReducerTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(description)"]
                )
            }

            let value = try await group.next()
            group.cancelAll()
            return try #require(value, "Expected one task group result for \(description).")
        }
    }

    @MainActor
    func drainDetailMetadataEffects(
        _ store: TestStoreOf<DetailReducer>,
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() && clock.now < deadline {
            await store.skipReceivedActions(strict: false)
            try? await Task.sleep(for: .milliseconds(10))
        }
        await store.skipReceivedActions(strict: false)
    }

    func sampleGalleryState(gid: String) throws -> GalleryState {
        var galleryState = GalleryState(gid: gid)
        galleryState.previewURLs = [1: try #require(URL(string: "https://example.com/1t.jpg"))]
        galleryState.previewConfig = .normal(rows: 4)
        return galleryState
    }

    func sampleVersionMetadata(gid: String, token: String) -> DownloadVersionMetadata {
        DownloadVersionMetadata(
            gid: gid,
            token: token,
            currentGID: gid,
            currentKey: "updated-key",
            parentGID: gid,
            parentKey: token,
            firstGID: gid,
            firstKey: token
        )
    }

    func makeTestingDownloadManager() -> DownloadManager {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
    }

    func makeResponse(
        url: URL,
        statusCode: Int = 200,
        contentType: String,
        contentLength: Int? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        var headerFields = headers
        headerFields["Content-Type"] = contentType
        if let contentLength {
            headerFields["Content-Length"] = "\(contentLength)"
        }
        return try #require(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        ))
    }

    func writeFixtureToTemporaryFile(filename: HTMLFilename) throws -> URL {
        try writeFixtureToTemporaryFile(resource: filename.rawValue, pathExtension: "html")
    }

    func writeFixtureToTemporaryFile(resource: String, pathExtension: String) throws -> URL {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try fixtureData(resource: resource, pathExtension: pathExtension)
            .write(to: temporaryURL, options: .atomic)
        return temporaryURL
    }

    func fixtureData(resource: String, pathExtension: String) throws -> Data {
        let fixtureURL = try #require(
            Bundle(for: TestBundleLocator.self).url(forResource: resource, withExtension: pathExtension)
        )
        return try Data(contentsOf: fixtureURL)
    }

    func installGalleryVersionMetadataStub(for gallery: Gallery, sessionID: String) throws {
        let gid = try #require(Int(gallery.gid))
        let payload: [String: Any] = [
            "gmetadata": [[
                "gid": gid,
                "token": gallery.token,
                "current_gid": gid,
                "current_key": "updated-key",
                "parent_gid": gid,
                "parent_key": gallery.token,
                "first_gid": gid,
                "first_key": gallery.token
            ]]
        ]
        let responseData = try JSONSerialization.data(withJSONObject: payload, options: [])
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            let response = try #require(HTTPURLResponse(
                url: request.url ?? Defaults.URL.api,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, responseData)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
    }

    func uninstallSharedSessionStub(sessionID: String) {
        SharedSessionStubURLProtocol.removeHandler(for: sessionID)
    }

    func sampleGallery() -> Gallery {
        Gallery(
            gid: "123456",
            token: "token",
            title: "Sample Gallery",
            rating: 4,
            tags: [],
            category: .doujinshi,
            uploader: "Uploader",
            pageCount: 12,
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            galleryURL: URL(string: "https://e-hentai.org/g/123456/token")
        )
    }

    func sampleGalleryDetail(gid: String, title: String) -> GalleryDetail {
        GalleryDetail(
            gid: gid,
            title: title,
            jpnTitle: nil,
            isFavorited: false,
            visibility: .yes,
            rating: 4,
            userRating: 0,
            ratingCount: 10,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            favoritedCount: 2,
            pageCount: 12,
            sizeCount: 120,
            sizeType: "MB",
            torrentCount: 0
        )
    }

    func sampleManifest(
        gid: String,
        title: String,
        pageCount: Int = 2,
        versionSignature: String = "hash:v1"
    ) throws -> DownloadManifest {
        DownloadManifest(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: title,
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            pageCount: pageCount,
            coverRelativePath: "cover.jpg",
            galleryURL: try #require(URL(string: "https://e-hentai.org/g/\(gid)/token")),
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            versionSignature: versionSignature,
            downloadedAt: .now,
            pages: (1...pageCount).map {
                .init(index: $0, relativePath: "pages/\(String(format: "%04d", $0)).jpg")
            }
        )
    }

    func sampleInspection(download: DownloadedGallery) -> DownloadInspection {
        .init(
            download: download,
            coverURL: download.coverURL,
            pages: [
                .init(
                    index: 1,
                    status: .downloaded,
                    relativePath: "pages/0001.jpg",
                    fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"),
                    failure: nil
                ),
                .init(
                    index: 2,
                    status: .failed,
                    relativePath: "pages/0002.jpg",
                    fileURL: nil,
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )
    }

    func sampleDownload(
        gid: String,
        title: String,
        status: DownloadStatus,
        category: EhPanda.Category = .doujinshi,
        pageCount: Int = 12,
        completedPageCount: Int? = nil,
        lastDownloadedAt: Date? = .now,
        remoteVersionSignature: String = "hash:v1",
        latestRemoteVersionSignature: String = "hash:v1",
        lastError: DownloadFailure? = nil,
        pendingOperation: DownloadStartMode? = nil
    ) -> DownloadedGallery {
        DownloadedGallery(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: title,
            jpnTitle: nil,
            uploader: "Uploader",
            category: category,
            tags: [],
            pageCount: pageCount,
            postedDate: .now,
            rating: 4,
            onlineCoverURL: URL(string: "https://example.com/cover.jpg"),
            folderRelativePath: "\(gid) - \(title)",
            coverRelativePath: "cover.jpg",
            status: status,
            completedPageCount: completedPageCount ?? (status == .completed ? pageCount : 0),
            lastDownloadedAt: lastDownloadedAt,
            lastError: lastError,
            downloadOptionsSnapshot: DownloadOptionsSnapshot(),
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            pendingOperation: pendingOperation
        )
    }

    func prepareLocalDownloadFiles(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) throws -> URL {
        guard let folderURL = download.folderURL else {
            throw NSError(
                domain: "DownloadFeatureReducerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Downloads directory is unavailable in the test environment."]
            )
        }
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )
        return folderURL
    }

    func makeInMemoryContainer() throws -> NSPersistentContainer {
        let modelURL = try #require(
            Bundle(for: TestBundleLocator.self).url(forResource: "Model", withExtension: "momd")
            ?? Bundle.main.url(forResource: "Model", withExtension: "momd")
        )
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL))
        let container = NSPersistentContainer(name: UUID().uuidString, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        let waitResult = semaphore.wait(timeout: .now() + 5)
        if waitResult == .timedOut {
            Issue.record("Timed out loading in-memory persistent store.")
        }
        if let loadError {
            Issue.record("Failed to load in-memory persistent store: \(loadError)")
        }
        return container
    }

    func clearPersistedDownloads(in container: NSPersistentContainer) throws {
        let context = container.viewContext
        let downloadRequest = NSFetchRequest<DownloadedGalleryMO>(entityName: "DownloadedGalleryMO")
        let downloads = try context.fetch(downloadRequest)
        for object in downloads {
            context.delete(object)
        }
        let stateRequest = NSFetchRequest<GalleryStateMO>(entityName: "GalleryStateMO")
        let states = try context.fetch(stateRequest)
        for object in states {
            context.delete(object)
        }
        guard context.hasChanges else { return }
        try context.save()
    }

    func insertPersistedDownload(
        in container: NSPersistentContainer,
        gid: String,
        status: DownloadStatus,
        completedPageCount: Int,
        pageCount: Int = 26,
        token: String = "token",
        remoteVersionSignature: String = "",
        latestRemoteVersionSignature: String = "",
        lastError: DownloadFailure? = nil,
        pendingOperation: DownloadStartMode? = nil
    ) throws {
        let context = container.viewContext
        let object = DownloadedGalleryMO(context: context)
        object.gid = gid
        object.host = GalleryHost.ehentai.rawValue
        object.token = token
        object.title = "Pause Race"
        object.jpnTitle = nil
        object.uploader = "Uploader"
        object.category = Category.doujinshi.rawValue
        object.tags = [GalleryTag]().toData()
        object.pageCount = Int64(pageCount)
        object.postedDate = .now
        object.rating = 4
        object.onlineCoverURL = URL(string: "https://example.com/cover.jpg")
        object.folderRelativePath = "\(gid) - Pause Race"
        object.coverRelativePath = nil
        object.status = status.rawValue
        object.completedPageCount = Int64(completedPageCount)
        object.lastDownloadedAt = .now
        object.lastError = lastError?.toData()
        object.downloadOptionsSnapshot = DownloadOptionsSnapshot().toData()
        object.remoteVersionSignature = remoteVersionSignature
        object.latestRemoteVersionSignature = latestRemoteVersionSignature
        object.pendingOperation = pendingOperation?.rawValue
        try context.save()
    }

    func insertPersistedGalleryState(
        in container: NSPersistentContainer,
        gid: String,
        previewURLs: [Int: URL] = [:],
        imageURLs: [Int: URL],
        originalImageURLs: [Int: URL] = [:]
    ) throws {
        let context = container.viewContext
        let object = GalleryStateMO(context: context)
        object.gid = gid
        object.previewURLs = previewURLs.toData()
        object.imageURLs = imageURLs.toData()
        object.originalImageURLs = originalImageURLs.toData()
        try context.save()
    }
}

private final class UncheckedBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private struct RequestRecorderSnapshot: Equatable {
    var detailRequests = 0
    var metadataRequests = 0
    var mpvRequests = 0
    var imageDispatchRequests = 0
    var imageDownloads = 0
    var previewPageNumbers = [Int]()
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var state = RequestRecorderSnapshot()

    func recordDetail() {
        mutate { $0.detailRequests += 1 }
    }

    func recordMetadata() {
        mutate { $0.metadataRequests += 1 }
    }

    func recordPreview(_ pageNumber: Int) {
        mutate { $0.previewPageNumbers.append(pageNumber) }
    }

    func recordMPV() {
        mutate { $0.mpvRequests += 1 }
    }

    func recordImageDispatch() {
        mutate { $0.imageDispatchRequests += 1 }
    }

    func recordImageDownload() {
        mutate { $0.imageDownloads += 1 }
    }

    func reset() {
        mutate { $0 = .init() }
    }

    func snapshot() -> RequestRecorderSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    private func mutate(_ update: (inout RequestRecorderSnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        update(&state)
    }
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let readCount = stream.read(buffer, maxLength: bufferSize)
        guard readCount >= 0 else {
            return nil
        }
        guard readCount > 0 else {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}

private final class FailFastURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}

private final class SharedSessionStubURLProtocol: URLProtocol {
    static let headerKey = "X-TestSession-ID"

    private static let lock = NSLock()
    private static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]

    static func setHandler(
        for sessionID: String,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        defer { lock.unlock() }
        handlers[sessionID] = handler
    }

    static func removeHandler(for sessionID: String) {
        lock.lock()
        defer { lock.unlock() }
        handlers[sessionID] = nil
    }

    private static func handler(
        for request: URLRequest
    ) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        guard let sessionID = request.value(forHTTPHeaderField: headerKey) else {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return handlers[sessionID]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        handler(for: request) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
