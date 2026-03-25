//
//  DownloadFeatureReducerTests.swift
//  EhPandaTests
//

import CoreData
import ComposableArchitecture
import Kingfisher
import UIKit
import XCTest
@testable import EhPanda

final class DownloadFeatureReducerTests: XCTestCase, TestHelper {
    func testQuickSearchWordUsesNameWhenContentIsEmpty() {
        let word = QuickSearchWord(name: "artist:hossy", content: "")

        XCTAssertEqual(word.effectiveSearchText, "artist:hossy")
    }

    func testPauseKeepsActiveDownloadPausedWhenDeferredSchedulingRuns() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

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

        try await insertPersistedDownload(
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
            return XCTFail("Pause should succeed, got \(result)")
        }

        try await Task.sleep(for: .milliseconds(100))

        let stored = await manager.testingFetchDownload(gid: gid)
        let activeGalleryID = await manager.testingActiveGalleryID()
        XCTAssertEqual(stored?.status, .paused)
        XCTAssertEqual(stored?.badge, .paused(7, 26))
        XCTAssertNil(activeGalleryID)
    }

    func testPauseUsesTemporaryWorkingSetProgressWhenCancelling() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

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

        try await insertPersistedDownload(
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
            return XCTFail("Pause should succeed, got \(result)")
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        XCTAssertEqual(stored?.status, .paused)
        XCTAssertEqual(stored?.completedPageCount, 2)
        XCTAssertEqual(stored?.badge, .paused(2, 2))
    }

    func testReconcileDownloadsNormalizesLegacyFailedStatusToNeedsAttention() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

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

        try await insertPersistedDownload(
            gid: gid,
            status: .failed,
            completedPageCount: 0,
            pageCount: 18
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        XCTAssertEqual(stored?.status, .partial)
        XCTAssertEqual(stored?.badge, .partial(0, 18))
    }

    func testReconcileDownloadsClearsCancellationLikeGalleryError() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

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

        try await insertPersistedDownload(
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
        XCTAssertNil(stored?.lastError)
        XCTAssertEqual(stored?.status, .partial)
    }

    func testLoadInspectionFiltersCancellationFailuresIntoPendingPages() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

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

        try await insertPersistedDownload(
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
            return XCTFail("Expected inspection to load successfully, got \(result)")
        }

        XCTAssertEqual(inspection.pages[0].status, .downloaded)
        XCTAssertEqual(inspection.pages[1].status, .pending)
        XCTAssertTrue((try? storage.readFailedPages(folderURL: temporaryFolderURL).pages.isEmpty) ?? true)
    }

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

        XCTAssertEqual(state.filteredDownloads, [activeDownload])
    }

    func testQueuedRetryWorkAppearsAsActiveDownloadBadge() {
        let queuedRedownload = sampleDownload(
            gid: "303",
            title: "Gamma Archive",
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        XCTAssertEqual(queuedRedownload.pendingOperation, .redownload)
        XCTAssertEqual(queuedRedownload.badge, .queued)
        XCTAssertTrue(queuedRedownload.matches(filter: .active))
    }

    func testQueuedRepairWorkAppearsAsActiveDownloadBadge() {
        let queuedRepair = sampleDownload(
            gid: "404",
            title: "Broken Archive",
            status: .missingFiles,
            completedPageCount: 3,
            pendingOperation: .repair
        )

        XCTAssertEqual(queuedRepair.pendingOperation, .repair)
        XCTAssertEqual(queuedRepair.badge, .queued)
        XCTAssertTrue(queuedRepair.matches(filter: .active))
    }

    func testQueuedUpdateWorkAppearsAsActiveDownloadBadge() {
        let queuedUpdate = sampleDownload(
            gid: "414",
            title: "Updated Archive",
            status: .updateAvailable,
            completedPageCount: 12,
            latestRemoteVersionSignature: "hash:v2",
            pendingOperation: .update
        )

        XCTAssertEqual(queuedUpdate.pendingOperation, .update)
        XCTAssertEqual(queuedUpdate.badge, .queued)
        XCTAssertTrue(queuedUpdate.matches(filter: .active))
        XCTAssertFalse(queuedUpdate.matches(filter: .update))
    }

    func testQueuedResumedUpdateDoesNotPretendToBeInitialWork() {
        let resumedUpdate = sampleDownload(
            gid: "415",
            title: "Resumed Update",
            status: .queued,
            pageCount: 26,
            completedPageCount: 7,
            latestRemoteVersionSignature: "hash:v2"
        )

        XCTAssertNil(resumedUpdate.pendingOperation)
        XCTAssertTrue(resumedUpdate.isQueuedWorkItem)
        XCTAssertEqual(resumedUpdate.badge, .queued)
        XCTAssertTrue(resumedUpdate.matches(filter: .active))
    }

    func testPausedDownloadAppearsAsActiveBadge() {
        let pausedDownload = sampleDownload(
            gid: "455",
            title: "Paused Archive",
            status: .paused,
            pageCount: 12,
            completedPageCount: 4
        )

        XCTAssertEqual(pausedDownload.badge, .paused(4, 12))
        XCTAssertTrue(pausedDownload.matches(filter: .active))
    }

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

        XCTAssertFalse(downloadingUpdate.canTriggerUpdate)
        XCTAssertFalse(pausedUpdate.canTriggerUpdate)
        XCTAssertTrue(completedUpdate.canTriggerUpdate)
    }

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

        XCTAssertEqual(state.filteredDownloads, [qualifyingDownload])
    }

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

        XCTAssertEqual(state.filteredDownloads, [mangaDownload])
    }

    func testPartialDownloadBadgeUsesNeedsAttentionCopy() {
        let partialDownload = sampleDownload(
            gid: "480",
            title: "Incomplete Archive",
            status: .partial,
            pageCount: 12,
            completedPageCount: 5
        )

        XCTAssertEqual(partialDownload.badge.text, "Needs Attention 5/12")
        XCTAssertEqual(DownloadListFilter.failed.title, "Needs Attention")
    }

    func testQueuedRedownloadDoesNotLeakIntoCompletedFilter() {
        let queuedRedownload = sampleDownload(
            gid: "505",
            title: "Delta Archive",
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        XCTAssertFalse(queuedRedownload.matches(filter: .completed))
        XCTAssertFalse(queuedRedownload.matches(filter: .update))
    }

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

        XCTAssertFalse(queuedRepair.matches(filter: .failed))
        XCTAssertFalse(queuedRepair.matches(filter: .update))
        XCTAssertEqual(missingFilesWithoutQueuedWork.badge, .missingFiles)
        XCTAssertTrue(missingFilesWithoutQueuedWork.matches(filter: .failed))
    }

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

        XCTAssertEqual(queuedRedownload.sortPriority, 1)
        XCTAssertEqual(completedDownload.sortPriority, 7)
        XCTAssertEqual(sortedDownloads.map(\.gid), [queuedRedownload.gid, completedDownload.gid])
    }

    func testInProgressDownloadPrefersTemporaryCoverURL() throws {
        let gid = "811"
        let download = sampleDownload(
            gid: gid,
            title: "Temporary Cover Archive",
            status: .downloading,
            completedPageCount: 3
        )

        guard let rootURL = FileUtil.downloadsDirectoryURL else {
            throw XCTSkip("Downloads directory is unavailable in the test environment.")
        }

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        try? FileManager.default.removeItem(at: temporaryFolderURL)
        defer { try? FileManager.default.removeItem(at: temporaryFolderURL) }

        try FileManager.default.createDirectory(
            at: temporaryFolderURL,
            withIntermediateDirectories: true
        )
        let temporaryCoverURL = temporaryFolderURL.appendingPathComponent("cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: temporaryCoverURL, options: .atomic)

        XCTAssertEqual(download.resolvedCoverURL(rootURL: rootURL), temporaryCoverURL)
    }

    func testQueuedDownloadPreservesTemporaryWorkingSet() {
        let queuedDownload = sampleDownload(
            gid: "809",
            title: "Queued Archive",
            status: .queued,
            completedPageCount: 3
        )

        XCTAssertTrue(queuedDownload.shouldPreserveTemporaryWorkingSet)
    }

    func testActiveDownloadDoesNotNormalizeWhileTaskIsStillRunning() {
        let activeDownload = sampleDownload(
            gid: "810",
            title: "Running Archive",
            status: .downloading,
            completedPageCount: 3
        )

        XCTAssertFalse(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: activeDownload.gid,
                hasActiveTask: true
            )
        )
        XCTAssertTrue(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: nil,
                hasActiveTask: false
            )
        )
        XCTAssertTrue(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: "another-gid",
                hasActiveTask: true
            )
        )
    }

    func testAppLaunchAutomationResolveParsesGalleryURLAndCookies() {
        let automation = AppLaunchAutomation.resolve(environment: [
            "EHPANDA_AUTOMATION_TAB": "downloads",
            "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID": "1394965",
            "EHPANDA_AUTOMATION_GALLERY_URL": "https://e-hentai.org/g/1394965/56c35114b6/",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "4172984",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "pass-hash",
            "EHPANDA_AUTOMATION_IGNEOUS": "igneous-value"
        ])

        XCTAssertEqual(automation?.initialTab, .downloads)
        XCTAssertEqual(automation?.autoDownloadGID, "1394965")
        XCTAssertEqual(
            automation?.galleryURL,
            URL(string: "https://e-hentai.org/g/1394965/56c35114b6/")
        )
        XCTAssertEqual(automation?.loginCookies?.memberID, "4172984")
        XCTAssertEqual(automation?.loginCookies?.passHash, "pass-hash")
        XCTAssertEqual(automation?.loginCookies?.igneous, "igneous-value")
    }

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

        XCTAssertEqual(memberCookie?.value, "4172984")
        XCTAssertEqual(passHashCookie?.value, "pass-hash")
        XCTAssertTrue(memberCookie?.isSessionOnly == true)
        XCTAssertTrue(passHashCookie?.isSessionOnly == true)
        XCTAssertNil(igneousCookie)
        XCTAssertTrue(cookieClient.didLogin)
        XCTAssertTrue(cookieClient.shouldFetchIgneous)
    }

    @MainActor
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
        XCTAssertTrue(cookieClient.didLogin)
        await store.receive(\.setting.loadUserSettings)
    }

    @MainActor
    func testLoadUserSettingsDefersExLaunchAutomationUntilIgneousArrives() async {
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
        XCTAssertFalse(store.state.didRunLaunchAutomation)
        XCTAssertTrue(store.state.isWaitingForIgneousBeforeLaunchAutomation)

        let response: HTTPURLResponse = HTTPURLResponse(
            url: Defaults.URL.exhentai,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Set-Cookie": "\(Defaults.Cookie.igneous)=test-igneous"
            ]
        )!
        await store.send(.setting(.fetchIgneousDone(.success(response))))
        await store.receive(\.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
            $0.isWaitingForIgneousBeforeLaunchAutomation = false
        }
    }

    @MainActor
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
        XCTAssertFalse(store.state.didRunLaunchAutomation)
        XCTAssertTrue(store.state.isWaitingForIgneousBeforeLaunchAutomation)

        await store.send(.setting(.fetchIgneousDone(.failure(.networkingFailed))))
        await store.receive(\.setting.account.loadCookies)
        XCTAssertFalse(store.state.didRunLaunchAutomation)
        XCTAssertTrue(store.state.isWaitingForIgneousBeforeLaunchAutomation)
    }

    @MainActor
    func testDownloadsReducerKeepsIdleStateForEmptyLibrary() async {
        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
        }

        await store.send(.fetchDownloadsDone([])) {
            $0.loadingState = .idle
        }

        XCTAssertEqual(store.state.downloads, [])
    }

    @MainActor
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

        XCTAssertEqual(store.state.route, .detail(download.gid))
        XCTAssertEqual(store.state.detailState.wrappedValue?.gid, download.gid)
        XCTAssertEqual(store.state.detailState.wrappedValue?.gallery.id, download.gid)
        XCTAssertEqual(store.state.detailState.wrappedValue?.downloadBadge, .downloaded)
        XCTAssertTrue(store.state.detailState.wrappedValue?.shouldCheckForRemoteUpdates == true)
    }

    @MainActor
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

        XCTAssertEqual(retried.value, [download.gid])
    }

    @MainActor
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

        XCTAssertEqual(deleted.value, [download.gid])
    }

    @MainActor
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

        XCTAssertEqual(toggled.value, [download.gid])
    }

    @MainActor
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
    func testDownloadInspectorReducerRetryPageUsesDownloadClientRetryPages() async {
        let retried = UncheckedBox<[Int]>([])
        let retryExpectation = XCTestExpectation(description: "Retry page")
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
                    retryExpectation.fulfill()
                    return .success(())
                },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(initialState.inspection!) }
            )
        }
        store.exhaustivity = .off

        await store.send(.retryPage(2))
        await fulfillment(of: [retryExpectation], timeout: 1)
        XCTAssertEqual(retried.value, [2])
    }

    @MainActor
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
                loadInspection: { _ in .success(initialState.inspection!) }
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

        XCTAssertEqual(retried.value, [2])
    }

    @MainActor
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
        XCTAssertEqual(loadInspectionCount.value, 0)
    }

    @MainActor
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
        XCTAssertNil(store.state.inspection)

        await store.send(.loadInspectionDone(secondRequestID, .success(refreshedInspection))) {
            $0.inspection = refreshedInspection
            $0.stableInspection = refreshedInspection
            $0.loadingState = .idle
        }
    }

    func testDownloadManagerLoadInspectionUsesTemporaryFailedPagesSnapshot() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )

        try await insertPersistedDownload(
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

        XCTAssertEqual(inspection.pages[0].status, .downloaded)
        XCTAssertEqual(inspection.pages[1].status, .failed)
        XCTAssertEqual(inspection.pages[1].failure?.code, .networkingFailed)
    }

    func testDownloadManagerLoadLocalPageURLsPrefersCompletedFolderForCompletedDownload() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 11)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try await insertPersistedDownload(
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
        let manifest = sampleManifest(gid: gid, title: "Pause Race")
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

        XCTAssertEqual(pageURLs[1], completedPageURL)
        XCTAssertNotEqual(pageURLs[1], temporaryPageURL)
        XCTAssertNil(pageURLs[3])
    }

    func testDownloadManagerLoadLocalPageURLsMergesReadableCompletedPagesWithTemporaryPages() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 12)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try await insertPersistedDownload(
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
        let manifest = sampleManifest(gid: gid, title: "Pause Race")
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

        XCTAssertEqual(pageURLs[1], completedFolderURL.appendingPathComponent("pages/0001.jpg"))
        XCTAssertEqual(pageURLs[2], temporaryPageURL)
    }

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
        let oldManifest = sampleManifest(
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

        XCTAssertNil(workingSeed.manifest)
        XCTAssertTrue(workingSeed.existingPages.isEmpty)
        XCTAssertNil(workingSeed.coverRelativePath)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent("pages/0002.jpg").path
            )
        )
    }

    func testDownloadManagerLoadLocalPageURLsMarksCompletedDownloadMissingFilesWhenZeroBytePageIsFound() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 13)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try await insertPersistedDownload(
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
        let manifest = sampleManifest(gid: gid, title: "Pause Race")
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

        XCTAssertNil(pageURLs[1])
        XCTAssertEqual(pageURLs[2], goodPageURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyPageURL.path))
        XCTAssertEqual(stored?.status, .missingFiles)
        XCTAssertEqual(stored?.completedPageCount, 1)
    }

    @MainActor
    func testImageClientFetchImageUsesStableAliasCacheKey() async throws {
        let url = try XCTUnwrap(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let stableCacheKey = try XCTUnwrap(url.stableImageCacheKey)
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemRed.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try XCTUnwrap(image.pngData())

        KingfisherManager.shared.cache.store(image, original: imageData, forKey: stableCacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: stableCacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
        }

        let result = await ImageClient.live.fetchImage(url: url)
        let fetchedImage = try result.get()

        XCTAssertEqual(fetchedImage.size, image.size)
    }

    func testRetryPagesQueuesWorkWhenAnotherDownloadIsActive() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try await insertPersistedDownload(
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
            return XCTFail("Retry pages should succeed, got \(result)")
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        XCTAssertEqual(stored?.status, .queued)
        XCTAssertEqual(stored?.badge, .queued)
        XCTAssertNil(stored?.pendingOperation)
        XCTAssertNil(stored?.lastError)

        let resumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
        XCTAssertEqual(resumeState.pageSelection, [2])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: temporaryFolderURL
                .appendingPathComponent(Defaults.FilePath.downloadFailedPages)
                .path
        ))
    }

    func testCancelQueuedRepairRestoresReadableCountAndClearsPendingOperation() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = "cancel-repair-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try await insertPersistedDownload(
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
        let manifest = sampleManifest(gid: gid, title: "Pause Race")
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
            return XCTFail("Cancelling queued repair should succeed, got \(result)")
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        XCTAssertEqual(stored?.status, .missingFiles)
        XCTAssertEqual(stored?.completedPageCount, 1)
        XCTAssertNil(stored?.pendingOperation)
    }

    func testRetryPagesUsesMinimalSourceResolutionAndSkipsWhenNoPendingPages() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 200)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let recorder = RequestRecorder()
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": Int(gid)!,
                "token": "token",
                "current_gid": Int(gid)!,
                "current_key": "updated-key",
                "parent_gid": Int(gid)!,
                "parent_key": "token",
                "first_gid": Int(gid)!,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.host == "api.e-hentai.org" {
                recorder.recordMetadata()
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!,
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
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    detailHTML
                )
            }

            if url.path.contains("/mpv/\(gid)/token") {
                recorder.recordMPV()
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let method = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                if method?["method"] as? String == "gdata" {
                    recorder.recordMetadata()
                    return (
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!,
                        metadataResponse
                    )
                }

                recorder.recordImageDispatch()
                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!,
                    responseData
                )
            }

            if url.host == "example.com" {
                recorder.recordImageDownload()
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )!,
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.requestHandler = nil
            URLProtocol.unregisterClass(SharedSessionStubURLProtocol.self)
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
        let manifest = sampleManifest(
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

        try await insertPersistedDownload(
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
        XCTAssertEqual(firstRunSnapshot.previewPageNumbers, [1])

        recorder.reset()
        try await clearPersistedDownloads()
        try await insertPersistedDownload(
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
        XCTAssertTrue(secondRunSnapshot.previewPageNumbers.isEmpty)
        XCTAssertEqual(secondRunSnapshot.mpvRequests, 0)
        XCTAssertEqual(secondRunSnapshot.imageDispatchRequests, 0)
    }

    func testRetryPagesFallsBackToFullUpdateWhenGalleryHasUpdate() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = try XCTUnwrap(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
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
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": Int(gid)!,
                "token": "token",
                "current_gid": Int(gid)!,
                "current_key": "updated-key",
                "parent_gid": Int(gid)!,
                "parent_key": "token",
                "first_gid": Int(gid)!,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!,
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!,
                    responseData
                )
            }

            if url.host == "example.com" {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )!,
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.requestHandler = nil
            URLProtocol.unregisterClass(SharedSessionStubURLProtocol.self)
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
        XCTAssertGreaterThan(pageCount, pageIndex)
        XCTAssertGreaterThan(pageCount, 5)
        let oldCount = pageCount - 5
        XCTAssertNotEqual(oldCount, pageCount)
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)

        // Queued update path: retryPages should queue a full update and keep no page-selection state.
        try await insertPersistedDownload(
            gid: gid,
            status: .partial,
            completedPageCount: oldCount - 1,
            pageCount: oldCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: updatedVersionSignature
        )

        let queuedCandidate = await queueingManager.testingFetchDownload(gid: gid)
        XCTAssertTrue(queuedCandidate?.hasUpdate == true)

        let blockerTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        await queueingManager.testingInstallActiveTask(gid: "blocker", task: blockerTask)
        defer { blockerTask.cancel() }

        let retryResult = await queueingManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = retryResult else {
            return XCTFail("retryPages should succeed, got \(retryResult)")
        }

        let queued = await queueingManager.testingFetchDownload(gid: gid)
        XCTAssertEqual(queued?.status, .partial)
        XCTAssertEqual(queued?.pendingOperation, .update)
        XCTAssertNil(queued?.lastError)
        if FileManager.default.fileExists(atPath: temporaryFolderURL.path) {
            let queuedResumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
            XCTAssertEqual(queuedResumeState.mode, .update)
            XCTAssertNil(queuedResumeState.pageSelection)
            XCTAssertNotEqual(queuedResumeState.pageSelection, [pageIndex])
        }

        try await clearPersistedDownloads()
        try? storage.removeTemporaryFolder(gid: gid)

        // Immediate update path: retryPages should normalize the working set to full-update semantics.
        let manifest = sampleManifest(
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
        try await insertPersistedDownload(
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
            return XCTFail("Immediate retryPages should succeed, got \(immediateRetryResult)")
        }

        let resumedState = try storage.readResumeState(folderURL: temporaryFolderURL)
        XCTAssertEqual(resumedState.mode, .update)
        XCTAssertEqual(resumedState.versionSignature, updatedVersionSignature)
        XCTAssertEqual(resumedState.pageCount, pageCount)
        XCTAssertNil(resumedState.pageSelection)
        XCTAssertNotEqual(resumedState.pageSelection, [pageIndex])
        let resumedDownload = await immediateManager.testingFetchDownload(gid: gid)
        XCTAssertEqual(resumedDownload?.status, .downloading)
        XCTAssertNil(resumedDownload?.pendingOperation)
        XCTAssertNil(resumedDownload?.lastError)
    }

    func testProcessDownloadClearsStalePageSelectionWhenLatestPayloadRevealsUpdate() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 401)
        let pageIndex = 42
        let oldVersionSignature = try XCTUnwrap(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        var allowedImageURLs = Set<String>()
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": Int(gid)!,
                "token": "token",
                "current_gid": Int(gid)!,
                "current_key": "updated-key",
                "parent_gid": Int(gid)!,
                "parent_key": "token",
                "first_gid": Int(gid)!,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!,
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": "https://example.com/image-\(pageIndex).jpg"
                ])
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!,
                    responseData
                )
            }

            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )!,
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.requestHandler = nil
            URLProtocol.unregisterClass(SharedSessionStubURLProtocol.self)
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
        XCTAssertGreaterThan(updatedPageCount, pageIndex)
        XCTAssertGreaterThan(updatedPageCount, 5)
        let oldPageCount = updatedPageCount - 5
        XCTAssertNotEqual(oldPageCount, updatedPageCount)

        try await insertPersistedDownload(
            gid: gid,
            status: .partial,
            completedPageCount: oldPageCount - 1,
            pageCount: oldPageCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )

        let beforeProcess = await manager.testingFetchDownload(gid: gid)
        XCTAssertFalse(beforeProcess?.hasUpdate ?? true)

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let staleManifest = sampleManifest(
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
        let unwrappedCompletedDownload = try XCTUnwrap(completedDownload)
        XCTAssertEqual(unwrappedCompletedDownload.status, .completed)
        XCTAssertEqual(unwrappedCompletedDownload.pageCount, updatedPageCount)
        XCTAssertEqual(unwrappedCompletedDownload.completedPageCount, updatedPageCount)
        XCTAssertEqual(unwrappedCompletedDownload.remoteVersionSignature, updatedVersionSignature)
        XCTAssertEqual(unwrappedCompletedDownload.latestRemoteVersionSignature, updatedVersionSignature)

        let completedFolderURL = storage.folderURL(relativePath: unwrappedCompletedDownload.folderRelativePath)
        let completedManifest = try storage.readManifest(folderURL: completedFolderURL)
        XCTAssertEqual(completedManifest.versionSignature, updatedVersionSignature)
        XCTAssertEqual(completedManifest.pageCount, updatedPageCount)
        XCTAssertEqual(completedManifest.pages.count, updatedPageCount)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: completedFolderURL.appendingPathComponent("pages/0001.jpg").path
        ))

        let completedResumeState = try storage.readResumeState(folderURL: completedFolderURL)
        XCTAssertEqual(completedResumeState.mode, .redownload)
        XCTAssertEqual(completedResumeState.versionSignature, updatedVersionSignature)
        XCTAssertEqual(completedResumeState.pageCount, updatedPageCount)
        XCTAssertNil(completedResumeState.pageSelection)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryFolderURL.path))
    }

    @MainActor
    func testProcessDownloadClearsRemoteAssetCacheAfterSuccessfulDownload() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 402)
        let pageIndex = 42
        let oldVersionSignature = try XCTUnwrap(
            DownloadSignatureBuilder.chainVersionIdentifier(gid: gid, token: "token")
        )
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let currentPageImageURL = try XCTUnwrap(
            URL(string: "https://example.com/image-\(pageIndex).jpg")
        )
        let staleStoredPageURL = try XCTUnwrap(
            URL(string: "https://example.com/stale-image-\(gid)-1.jpg")
        )
        let plainPreviewURL = try XCTUnwrap(
            URL(string: "https://ehgt.org/preview/\(gid)/1.webp")
        )
        let combinedPreviewURL = URLUtil.combinedPreviewURL(
            plainURL: plainPreviewURL,
            width: "200",
            height: "300",
            offset: "40"
        )
        var allowedImageURLs = Set<String>()
        let metadataResponse = try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": Int(gid)!,
                "token": "token",
                "current_gid": Int(gid)!,
                "current_key": "updated-key",
                "parent_gid": Int(gid)!,
                "parent_key": "token",
                "first_gid": Int(gid)!,
                "first_key": "token"
            ]]
        ])

        SharedSessionStubURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            if url.path.contains("/g/\(gid)/token") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    detailHTML
                )
            }

            if url.path.contains("/mpv/") {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )!,
                    mpvHTML
                )
            }

            if url.path == "/api.php" {
                let body = requestBodyData(from: request)
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let method = body?["method"] as? String
                if method == "gdata" {
                    return (
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!,
                        metadataResponse
                    )
                }

                let responseData = try JSONSerialization.data(withJSONObject: [
                    "i": currentPageImageURL.absoluteString
                ])
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!,
                    responseData
                )
            }

            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "image/jpeg"]
                    )!,
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }

            throw URLError(.unsupportedURL)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        defer {
            SharedSessionStubURLProtocol.requestHandler = nil
            URLProtocol.unregisterClass(SharedSessionStubURLProtocol.self)
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
        let coverURL = try XCTUnwrap(latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL)
        allowedImageURLs.insert(coverURL.absoluteString)

        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let cachedImageData = try XCTUnwrap(cachedImage.jpegData(compressionQuality: 1))

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
        XCTAssertGreaterThan(updatedPageCount, pageIndex)
        XCTAssertGreaterThan(oldPageCount, 0)

        try await insertPersistedDownload(
            gid: gid,
            status: .partial,
            completedPageCount: oldPageCount - 1,
            pageCount: oldPageCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        try await insertPersistedGalleryState(
            gid: gid,
            previewURLs: [1: combinedPreviewURL],
            imageURLs: [1: staleStoredPageURL]
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let staleManifest = sampleManifest(
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
        XCTAssertEqual(completedDownload?.status, .completed)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while cachedKeys.contains(where: { KingfisherManager.shared.cache.isCached(forKey: $0) }),
              clock.now < deadline
        {
            try? await Task.sleep(for: .milliseconds(10))
        }

        for cacheKey in cachedKeys {
            XCTAssertFalse(
                KingfisherManager.shared.cache.isCached(forKey: cacheKey),
                "Expected cache key to be removed after successful download: \(cacheKey)"
            )
        }
    }

    @MainActor
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

        XCTAssertEqual(reconcileCount.value, 1)
    }

    @MainActor
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

        XCTAssertEqual(refreshCount.value, 1)
        XCTAssertEqual(reconcileCount.value, 0)
    }

    @MainActor
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

        XCTAssertEqual(refreshCount.value, 1)
        XCTAssertEqual(reconcileCount.value, 0)
    }

    @MainActor
    func testDetailReducerStartDownloadEnqueuesGalleryWithSnapshotOptions() async {
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
            1: URL(string: "https://example.com/1.jpg")!
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

        XCTAssertEqual(capturedPayload.value?.gallery.gid, gallery.gid)
        XCTAssertEqual(capturedPayload.value?.galleryDetail, detail)
        XCTAssertEqual(capturedPayload.value?.previewConfig, .large(rows: 2))
        XCTAssertEqual(capturedPayload.value?.options, options)
        XCTAssertEqual(capturedPayload.value?.mode, .initial)
        XCTAssertEqual(store.state.downloadBadge, .queued)
    }

    @MainActor
    func testDetailReducerStartDownloadUnlocksActionsAfterQueueing() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot()
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.galleryPreviewURLs = [
            1: URL(string: "https://example.com/1.jpg")!
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
    func testDetailReducerLaunchAutomationWaitsForResolvedDownloadBadge() async {
        let capturedPayload = UncheckedBox<DownloadRequestPayload?>(nil)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadOptionsSnapshot()
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.galleryPreviewURLs = [
            1: URL(string: "https://example.com/1.jpg")!
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
        XCTAssertNil(capturedPayload.value)
        XCTAssertFalse(store.state.didRunLaunchAutomation)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded(options)) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.startDownload, options)
        await store.skipReceivedActions(strict: false)

        XCTAssertEqual(capturedPayload.value?.gallery.gid, gallery.gid)
    }

    @MainActor
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

        XCTAssertEqual(enqueueCount.value, 0)
        XCTAssertTrue(store.state.isPreparingDownload)
        XCTAssertEqual(store.state.downloadBadge, .none)
    }

    @MainActor
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

        XCTAssertEqual(togglePauseCount.value, 1)
        XCTAssertEqual(store.state.downloadBadge, .paused(7, 26))
        XCTAssertFalse(store.state.isPreparingDownload)
    }

    @MainActor
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
    func testDetailReducerOpenReadingUsesLocalManifestWhenAvailable() async {
        let download = sampleDownload(
            gid: "888",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let manifest = sampleManifest(gid: download.gid, title: download.title)
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

        XCTAssertEqual(store.state.readingState.contentSource, .local(download, manifest))
        if case .reading = store.state.route {
        } else {
            XCTFail("Expected reading route to be active.")
        }
    }

    @MainActor
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

        XCTAssertEqual(store.state.readingState.contentSource, .remote)
        if case .reading = store.state.route {
        } else {
            XCTFail("Expected reading route to be active.")
        }
    }

    @MainActor
    func testPreviewsReducerOpenReadingUsesLocalManifestWhenAvailable() async {
        let download = sampleDownload(
            gid: "991",
            title: "Preview Download",
            status: .completed,
            pageCount: 2,
            completedPageCount: 2
        )
        let manifest = sampleManifest(gid: download.gid, title: download.title)
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
            XCTAssertEqual(actualDownload, download)
            XCTAssertEqual(actualManifest, manifest)
        } else {
            XCTFail("Expected previews to open local reading content.")
        }
        if case .reading = store.state.route {
        } else {
            XCTFail("Expected reading route to be active.")
        }
    }

    @MainActor
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
        XCTAssertEqual(store.state.localPreviewRequestID, requestID)
    }

    @MainActor
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
            XCTFail("Expected previews route to enter reading")
            return
        }
        XCTAssertEqual(store.state.readingState.contentSource, .remote)
        XCTAssertEqual(store.state.readingState.localPageURLs, [1: localURL])
    }

    @MainActor
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
    func testReadingReducerRemoteSourceLoadsLocalPagesAndSkipsRemoteFetchForDownloadedPage() async throws {
        let gallery = sampleGallery()
        let localPageURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        let remotePageURL = URL(string: "https://example.com/pages/0001.jpg")!
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
        XCTAssertEqual(store.state.localPageRequestID, requestID)

        XCTAssertEqual(store.state.localPageURLs[1], localPageURL)

        await store.send(.fetchImageURLs(1)) {
            $0.imageURLLoadingStates[1] = .idle
        }
    }

    @MainActor
    func testReadingReducerOnWebImageSucceededCapturesCachedPageIntoDownloadProgress() async {
        let capturedCalls = UncheckedBox([(String, Int, URL?)]())
        let gallery = sampleGallery()
        let remotePageURL = URL(string: "https://example.com/pages/0001.jpg")!
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

        XCTAssertEqual(capturedCalls.value.count, 1)
        XCTAssertEqual(capturedCalls.value.first?.0, gallery.gid)
        XCTAssertEqual(capturedCalls.value.first?.1, 1)
        XCTAssertEqual(capturedCalls.value.first?.2, remotePageURL)
    }

    @MainActor
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

        XCTAssertTrue(capturedCalls.value.isEmpty)
    }

    @MainActor
    func testReadingReducerLocalSourceLoadsOfflineImagesWithoutNetwork() async throws {
        let download = sampleDownload(
            gid: "777",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let manifest = sampleManifest(gid: download.gid, title: download.title)
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
        XCTAssertEqual(store.state.gallery.id, download.gid)
        XCTAssertEqual(store.state.imageURLs[1], folderURL.appendingPathComponent("pages/0001.jpg"))
        XCTAssertEqual(store.state.imageURLs[2], folderURL.appendingPathComponent("pages/0002.jpg"))

        await store.send(.fetchImageURLs(1)) {
            $0.imageURLLoadingStates[1] = .idle
        }
        await store.send(.reloadAllWebImages)

        XCTAssertEqual(store.state.imageURLs[1], folderURL.appendingPathComponent("pages/0001.jpg"))
        XCTAssertEqual(store.state.imageURLs[2], folderURL.appendingPathComponent("pages/0002.jpg"))
    }

    @MainActor
    func testDownloadManagerCaptureCachedPageRestoresTemporaryPageAndUpdatesCompletedCount() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 27)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        try await insertPersistedDownload(
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

        let imageURL = try XCTUnwrap(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try XCTUnwrap(image.jpegData(compressionQuality: 1))
        let cacheKey = try XCTUnwrap(imageURL.stableImageCacheKey)
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
        XCTAssertEqual(stored?.completedPageCount, 1)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
        XCTAssertEqual(
            pageURLs[1],
            temporaryFolderURL.appendingPathComponent("pages/0001.jpg")
        )
    }

    @MainActor
    func testDownloadManagerCaptureCachedPageRepairsCompletedDownloadWithLatestRemoteImage() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 28)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        try await insertPersistedDownload(
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
        let manifest = sampleManifest(gid: gid, title: "Pause Race")
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

        let imageURL = try XCTUnwrap(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try XCTUnwrap(image.jpegData(compressionQuality: 1))
        let cacheKey = try XCTUnwrap(imageURL.stableImageCacheKey)
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

        XCTAssertEqual(stored?.status, .completed)
        XCTAssertEqual(stored?.completedPageCount, 2)
        XCTAssertNil(stored?.lastError)
        XCTAssertEqual(
            pageURLs[1],
            completedFolderURL.appendingPathComponent("pages/0001.jpg")
        )
    }

    @MainActor
    func testDownloadManagerReconcileNormalizesFailedDownloadBeforeTempCleanup() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 31)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try await insertPersistedDownload(
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

        XCTAssertEqual(stored?.status, .partial)
        XCTAssertEqual(stored?.completedPageCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryFolderURL.path))
        XCTAssertEqual(
            localPages[1],
            temporaryFolderURL.appendingPathComponent("pages/0001.jpg")
        )
    }

    @MainActor
    func testUpdateRemoteSignatureDoesNotMarkUpdateAvailableWhenStoredChainAndLatestHashAreDifferentKinds() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 101)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try await insertPersistedDownload(
            gid: gid,
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "chain:\(gid):token"
        )

        let badge = await manager.updateRemoteSignature(gid: gid, latestSignature: "hash:new")
        let stored = await manager.testingFetchDownload(gid: gid)

        XCTAssertEqual(badge, .downloaded)
        XCTAssertEqual(stored?.status, .completed)
        XCTAssertEqual(stored?.remoteVersionSignature, "chain:\(gid):token")
        XCTAssertEqual(stored?.latestRemoteVersionSignature, "hash:new")
    }

    @MainActor
    func testUpdateRemoteSignatureDoesNotMarkUpdateAvailableWhenStoredHashAndLatestNonOriginalChainAreDifferentKinds() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 102)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try await insertPersistedDownload(
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

        XCTAssertEqual(badge, .downloaded)
        XCTAssertEqual(stored?.status, .completed)
        XCTAssertEqual(stored?.remoteVersionSignature, "hash:old")
        XCTAssertEqual(stored?.latestRemoteVersionSignature, "chain:othergid:othertoken")
    }

    @MainActor
    func testUpdateRemoteSignatureCanonicalizesStoredHashToOriginalChainWithoutMarkingUpdate() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 103)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        try await insertPersistedDownload(
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

        XCTAssertEqual(badge, .downloaded)
        XCTAssertEqual(stored?.status, .completed)
        XCTAssertEqual(stored?.remoteVersionSignature, "chain:\(gid):token")
        XCTAssertEqual(stored?.latestRemoteVersionSignature, "chain:\(gid):token")
    }

    @MainActor
    func testDetailReducerDoesNotRequestVersionMetadataForUndownloadedGallery() async {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        var galleryState = GalleryState(gid: gallery.gid)
        galleryState.previewURLs = [1: URL(string: "https://example.com/1t.jpg")!]
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

        XCTAssertEqual(updateCheckCount.value, 0)
        XCTAssertNil(store.state.galleryVersionMetadata)
        XCTAssertFalse(store.state.shouldCheckForRemoteUpdates)
    }

    @MainActor
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesAfterDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = sampleGalleryState(gid: gallery.gid)
        try installGalleryVersionMetadataStub(for: gallery)
        defer { uninstallSharedSessionStub() }

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
        XCTAssertEqual(updateCheckCount.value, 0)

        await store.send(.fetchDownloadBadgeDone(.downloaded))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )

        XCTAssertEqual(updateCheckCount.value, 1)
        XCTAssertTrue(store.state.shouldCheckForRemoteUpdates)
        XCTAssertTrue(store.state.didRequestVersionMetadata)
        XCTAssertNotNil(store.state.galleryVersionMetadata)
    }

    @MainActor
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesBeforeDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = sampleGalleryState(gid: gallery.gid)
        try installGalleryVersionMetadataStub(for: gallery)
        defer { uninstallSharedSessionStub() }

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
        XCTAssertEqual(updateCheckCount.value, 0)

        await store.send(.fetchGalleryDetailDone(.success((detail, galleryState, "", nil))))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )

        XCTAssertEqual(updateCheckCount.value, 1)
        XCTAssertTrue(store.state.shouldCheckForRemoteUpdates)
        XCTAssertTrue(store.state.didRequestVersionMetadata)
        XCTAssertNotNil(store.state.galleryVersionMetadata)
    }

    @MainActor
    func testDetailReducerObserveDownloadDoneAlsoTriggersMetadataCheckWithoutDuplicateRequests() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        try installGalleryVersionMetadataStub(for: gallery)
        defer { uninstallSharedSessionStub() }

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
        XCTAssertEqual(updateCheckCount.value, 1)

        await store.send(.observeDownloadDone(.downloaded))
        await store.skipReceivedActions(strict: false)
        XCTAssertEqual(updateCheckCount.value, 1)
    }

    @MainActor
    func testDetailReducerRemoteUpdateFlagDoesNotStayStickyWhenBadgeReturnsToNone() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        try installGalleryVersionMetadataStub(for: gallery)
        defer { uninstallSharedSessionStub() }

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
        XCTAssertEqual(updateCheckCount.value, 1)
        XCTAssertTrue(store.state.shouldCheckForRemoteUpdates)
        XCTAssertTrue(store.state.didRequestVersionMetadata)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.downloadBadge = .none
            $0.hasLoadedDownloadBadge = true
            $0.shouldCheckForRemoteUpdates = false
            $0.didRequestVersionMetadata = false
            $0.galleryVersionMetadata = nil
        }
        await store.skipReceivedActions(strict: false)

        XCTAssertFalse(store.state.shouldCheckForRemoteUpdates)
        XCTAssertFalse(store.state.didRequestVersionMetadata)
        XCTAssertNil(store.state.galleryVersionMetadata)
    }

    @MainActor
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

        XCTAssertFalse(store.state.isDownloadContext)
        XCTAssertFalse(store.state.shouldCheckForRemoteUpdates)
        XCTAssertFalse(store.state.didRequestVersionMetadata)
        XCTAssertNil(store.state.galleryVersionMetadata)
    }

    func testFileBasedQuotaImageMapsToQuotaExceeded() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://ehgt.org/g/509.gif")!,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://ehgt.org/g/509.gif")
        )

        XCTAssertEqual(error, .quotaExceeded)
    }

    func testFileBasedQuotaImageRequiresKnown509Signature() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        var data = try Data(contentsOf: fileURL)
        data[0] = 0
        try data.write(to: fileURL, options: .atomic)
        let response = makeResponse(
            url: URL(string: "https://ehgt.org/g/509.gif")!,
            contentType: "image/gif",
            contentLength: data.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://ehgt.org/g/509.gif")
        )

        XCTAssertNil(error)
    }

    func testFileBasedBinaryKokomadeImageMapsToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gif")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imageData = try XCTUnwrap(Data(base64Encoded: "R0lGODlhAQABAIABAP///wAAACwAAAAAAQABAAACAkQBADs="))
        try imageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://exhentai.org/img/kokomade.jpg")!,
            contentType: "image/gif",
            contentLength: imageData.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1")
        )

        XCTAssertEqual(error, .authenticationRequired)
    }

    func testFileBasedQuotaImageFingerprintMapsToQuotaExceededEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try XCTUnwrap(URL(string: "https://ehgt.org/h/normal-image-cache-key/1"))
        let response = makeResponse(
            url: normalImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: normalImageURL
        )

        XCTAssertEqual(error, .quotaExceeded)
    }

    func testFileBasedKokomadeImageFingerprintMapsToAuthenticationRequiredEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(resource: "Kokomade", pathExtension: "jpg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try XCTUnwrap(URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1&key=normal-cache-key"))
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: makeResponse(
                url: normalImageURL,
                contentType: "image/jpeg",
                contentLength: 144844
            ),
            requestURL: normalImageURL
        )

        XCTAssertEqual(error, .authenticationRequired)
    }

    func testFileBasedTextImageLimitMapsToQuotaExceeded() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try """
        <html><body>You have exceeded your image viewing limits</body></html>
        """.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://e-hentai.org/s/1/1-1")!,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://e-hentai.org/s/1/1-1")
        )

        XCTAssertEqual(error, .quotaExceeded)
    }

    @MainActor
    func testCachedQuotaPlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 32)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        let normalImageURL = try XCTUnwrap(
            URL(string: "https://ehgt.org/h/quota-placeholder-cache-\(gid)/1")
        )
        try await insertPersistedGalleryState(gid: gid, imageURLs: [1: normalImageURL])

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
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")!
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

        XCTAssertEqual(restoredCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoredPageURL.path))
    }

    @MainActor
    func testCachedKokomadePlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 33)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        let normalImageURL = try XCTUnwrap(URL(string: "https://exhentai.org/fullimg.php?gid=\(gid)&page=1&key=normal-cache-key"))
        try await insertPersistedGalleryState(gid: gid, imageURLs: [1: normalImageURL])

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
                galleryURL: URL(string: "https://exhentai.org/g/\(gid)/token")!
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

        XCTAssertEqual(restoredCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoredPageURL.path))
    }

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
        let response = makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        XCTAssertEqual(error, .authenticationRequired)
    }

    func testFileBasedAuthHTMLMarkersMapToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try """
        <html>
          <body>
            <a href="bounce_login.php">Login</a>
            <img src="/img/kokomade.jpg">
            <p>Access to ExHentai.org is restricted.</p>
          </body>
        </html>
        """.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        XCTAssertEqual(error, .authenticationRequired)
    }

    func testFileBasedInvalidPageMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try """
        <html><body><h1>Invalid page</h1><p>Gallery not found</p></body></html>
        """.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://e-hentai.org/g/1/1/")!,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://e-hentai.org/g/1/1/")
        )

        XCTAssertEqual(error, .notFound)
    }

    func testFileBasedKeepTryingMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try "<html><body><h1>Keep trying</h1></body></html>"
            .data(using: .utf8)!
            .write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://e-hentai.org/s/1/1-1")!,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://e-hentai.org/s/1/1-1")
        )

        XCTAssertEqual(error, .notFound)
    }

    func testFileBasedHTTP404MapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try Data("Not here".utf8).write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://e-hentai.org/g/1/1/")!,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://e-hentai.org/g/1/1/")
        )

        XCTAssertEqual(error, .notFound)
    }

    func testFileBased404GalleryNotAvailableFallsBackToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try """
        <html>
          <head><title>Gallery Not Available</title></head>
          <body><h1>Gallery Not Available</h1></body>
        </html>
        """.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://e-hentai.org/g/1/1/")!,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://e-hentai.org/g/1/1/")
        )

        XCTAssertEqual(error, .notFound)
    }

    func testFileBasedHTMLBanPageStillParsesThroughParserInsteadOfParseFailed() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .ipBanned)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let response = makeResponse(
            url: URL(string: "https://example.com/banned")!,
            contentType: "text/html; charset=utf-8"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://example.com/banned")
        )

        XCTAssertNotEqual(error, .parseFailed)
        guard case .ipBanned = error else {
            return XCTFail("Expected ipBanned, got \(String(describing: error))")
        }
    }

    func testIpBannedDoesNotRetryImmediately() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
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
        SharedSessionStubURLProtocol.requestHandler = { request in
            recorder.recordDetail()
            return (
                HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/banned")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html; charset=utf-8"]
                )!,
                ipBannedHTML
            )
        }
        defer {
            SharedSessionStubURLProtocol.requestHandler = nil
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
            XCTFail("Expected ipBanned error")
        } catch let error as AppError {
            guard case .ipBanned = error else {
                return XCTFail("Expected ipBanned, got \(error)")
            }
        }

        XCTAssertEqual(recorder.snapshot().detailRequests, 1)
    }

    @MainActor
    func testReadingReducerLocalSourceWithoutGalleryStateDoesNotStayLoading() async {
        let download = sampleDownload(
            gid: "700001",
            title: "Offline Gallery",
            status: .completed,
            pageCount: 2,
            completedPageCount: 2
        )
        let manifest = sampleManifest(gid: download.gid, title: download.title)
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

        XCTAssertEqual(store.state.databaseLoadingState, .idle)
        XCTAssertEqual(store.state.readingProgress, 0)
    }

    @MainActor
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
                    XCTAssertEqual(gid, gallery.gid)
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
        XCTAssertEqual(loadCount.value, 1)

        continuationBox.value?.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(loadCount.value, 1)

        continuationBox.value?.finish()
        await store.finish()
    }

    @MainActor
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
                    XCTAssertEqual(gid, gallery.gid)
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
        XCTAssertEqual(loadCount.value, 1)

        continuationBox.value?.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(loadCount.value, 1)

        continuationBox.value?.finish()
        await store.finish()
    }

    @MainActor
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

        XCTAssertEqual(readingLoadCount.value, 2)
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

        XCTAssertEqual(previewsLoadCount.value, 2)
        previewsContinuationBox.value?.finish()
        await previewsStore.finish()
    }

    @MainActor
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
    func testDownloadManagerBatchesObserverUpdatesDuringCachedPageRestore() async throws {
        try await preparePersistenceStore()
        try await clearPersistedDownloads()
        defer {
            Task {
                try? await self.clearPersistedDownloads()
            }
        }

        let pageCount = 20
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try await insertPersistedDownload(
            gid: gid,
            status: .downloading,
            completedPageCount: 0,
            pageCount: pageCount
        )

        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try XCTUnwrap(cachedImage.jpegData(compressionQuality: 1))
        let imageURLs = Dictionary(uniqueKeysWithValues: (1...pageCount).map { index in
            (index, URL(string: "https://example.com/pages/\(gid)-\(index).jpg")!)
        })
        try await insertPersistedGalleryState(gid: gid, imageURLs: imageURLs)
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
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")!
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
        let emissionCount = await emissionTask.value
        let stored = await manager.testingFetchDownload(gid: gid)

        XCTAssertEqual(restoredCount, pageCount)
        XCTAssertEqual(stored?.completedPageCount, pageCount)
        XCTAssertLessThan(emissionCount, pageCount)
        XCTAssertLessThanOrEqual(emissionCount, 1 + Int(ceil(Double(pageCount) / 8.0)))
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
        XCTAssertTrue(
            missingKeys.isEmpty,
            "Timed out waiting for Kingfisher cache visibility for keys: \(missingKeys)"
        )
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

    func sampleGalleryState(gid: String) -> GalleryState {
        var galleryState = GalleryState(gid: gid)
        galleryState.previewURLs = [1: URL(string: "https://example.com/1t.jpg")!]
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
    ) -> HTTPURLResponse {
        var headerFields = headers
        headerFields["Content-Type"] = contentType
        if let contentLength {
            headerFields["Content-Length"] = "\(contentLength)"
        }
        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!
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
        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: resource, withExtension: pathExtension)
        )
        return try Data(contentsOf: fixtureURL)
    }

    func installGalleryVersionMetadataStub(for gallery: Gallery) throws {
        let gid = try XCTUnwrap(Int(gallery.gid))
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
        SharedSessionStubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url ?? Defaults.URL.api,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseData)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
    }

    func uninstallSharedSessionStub() {
        SharedSessionStubURLProtocol.requestHandler = nil
        URLProtocol.unregisterClass(SharedSessionStubURLProtocol.self)
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
    ) -> DownloadManifest {
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
            galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")!,
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
            throw XCTSkip("Downloads directory is unavailable in the test environment.")
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

    func preparePersistenceStore() async throws {
        if !PersistenceController.shared.container.persistentStoreCoordinator.persistentStores.isEmpty {
            return
        }

        let result: Result<Void, AppError> = await withCheckedContinuation { continuation in
            PersistenceController.shared.prepare { result in
                continuation.resume(returning: result)
            }
        }
        try result.get()
    }

    @MainActor
    func clearPersistedDownloads() throws {
        let context = PersistenceController.shared.container.viewContext
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

    @MainActor
    func insertPersistedDownload(
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
        let context = PersistenceController.shared.container.viewContext
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

    @MainActor
    func insertPersistedGalleryState(
        gid: String,
        previewURLs: [Int: URL] = [:],
        imageURLs: [Int: URL],
        originalImageURLs: [Int: URL] = [:]
    ) throws {
        let context = PersistenceController.shared.container.viewContext
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
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        requestHandler != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
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
