//
//  DownloadAutomationTests.swift
//  EhPandaTests
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadAutomationTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testAppForegroundReturnReconcilesDownloads() async {
        let reconcileCount = UncheckedBox(0)
        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = true

        let store = TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = .none
                $0.cookieClient = .noop
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = { .init { $0.finish() } }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.reconcileDownloads = {
                    reconcileCount.value += 1
                }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
        store.exhaustivity = .off

        // iOS always interposes .inactive on both edges of a background cycle:
        // .active -> .inactive -> .background -> .inactive -> .active. The
        // reconcile must survive the trailing .inactive and fire exactly once.
        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
        }
        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
        }
        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
        }
        await store.send(.onScenePhaseChange(.active)) {
            $0.scenePhase = .active
            $0.hasEnteredBackground = false
        }
        await store.finish()

        #expect(reconcileCount.value == 1)
    }

    @Test
    func testAppLaunchAutomationResolveParsesGalleryURLAndCookies() {
        let automation = AppLaunchAutomation.resolve(environment: [
            "EHPANDA_AUTOMATION_TAB": "downloads",
            "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID": "1394965",
            "EHPANDA_AUTOMATION_DOWNLOAD_FOLDER": " UI Tests ",
            "EHPANDA_AUTOMATION_GALLERY_URL": "https://e-hentai.org/g/1394965/56c35114b6/",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "4172984",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "pass-hash",
            "EHPANDA_AUTOMATION_IGNEOUS": "igneous-value"
        ])

        #expect(automation?.initialTab == .downloads)
        #expect(automation?.autoDownloadGID == "1394965")
        #expect(automation?.downloadFolderName == "UI Tests")
        #expect(
            automation?.galleryURL == URL(string: "https://e-hentai.org/g/1394965/56c35114b6/")
        )
        #expect(automation?.loginCookies?.memberID == "4172984")
        #expect(automation?.loginCookies?.passHash == "pass-hash")
        #expect(automation?.loginCookies?.igneous == "igneous-value")
    }

    @Test
    func testImportAutomationCookiesClearsStaleIgneousAndUsesSessionCookies() {
        let cookieClient = CookieClient.testing()
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

        let exCookies = cookieClient.cookies(for: Defaults.URL.exhentai)
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
        let automation = AppLaunchAutomation(
            initialTab: .downloads,
            autoDownloadGID: nil,
            downloadFolderName: nil,
            loginCookies: nil,
            galleryURL: URL(string: "https://example.com/not-a-gallery")
        )

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = appLaunchAutomationClient(automation)
                $0.cookieClient = .noop
                $0.deviceClient = .noop
                $0.hapticsClient = .noop
                $0.urlClient = .init(
                    checkIfHandleable: { _ in false },
                    checkIfMPVURL: { _ in false },
                    parseGalleryID: { _ in .init() }
                )
            }
        )

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
        let cookieClient = CookieClient.testing()
        let automation = AppLaunchAutomation(
            initialTab: nil,
            autoDownloadGID: nil,
            downloadFolderName: nil,
            loginCookies: .init(
                memberID: "4172984",
                passHash: "pass-hash",
                igneous: nil
            ),
            galleryURL: nil
        )

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = appLaunchAutomationClient(automation)
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
        )
        store.exhaustivity = .off

        await store.send(.appDelegate(.migration(.onDatabasePreparationSuccess)))
        await store.receive(\.appDelegate.removeExpiredImageURLs)
        #expect(cookieClient.shouldFetchIgneous)
        await store.receive(\.setting.loadUserSettings)
    }

    @MainActor
    @Test
    func testLoadUserSettingsDefersExLaunchAutomationUntilIgneousArrives() async throws {
        let cookieClient = CookieClient.testing(
            memberID: "4172984",
            passHash: "pass-hash",
            igneous: nil
        )
        let automation = AppLaunchAutomation(
            initialTab: nil,
            autoDownloadGID: nil,
            downloadFolderName: nil,
            loginCookies: nil,
            galleryURL: URL(string: "https://exhentai.org/g/1394965/56c35114b6/")
        )

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = appLaunchAutomationClient(automation)
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
        )
        store.exhaustivity = .off

        await store.send(.setting(.loadUserSettingsDone))
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isAwaitingIgneousForLaunchAutomation)

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
            $0.isAwaitingIgneousForLaunchAutomation = false
        }
    }

    @MainActor
    @Test
    func testLoadUserSettingsKeepsExLaunchAutomationDeferredWhenIgneousFetchFails() async {
        let cookieClient = CookieClient.testing(
            memberID: "4172984",
            passHash: "pass-hash",
            igneous: nil
        )
        let automation = AppLaunchAutomation(
            initialTab: nil,
            autoDownloadGID: nil,
            downloadFolderName: nil,
            loginCookies: nil,
            galleryURL: URL(string: "https://exhentai.org/g/1394965/56c35114b6/")
        )

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = appLaunchAutomationClient(automation)
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
        )
        store.exhaustivity = .off

        await store.send(.setting(.loadUserSettingsDone))
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isAwaitingIgneousForLaunchAutomation)

        await store.send(.setting(.fetchIgneousDone(.failure(.networkingFailed))))
        await store.receive(\.setting.account.loadCookies)
        #expect(store.state.didRunLaunchAutomation == false)
        #expect(store.state.isAwaitingIgneousForLaunchAutomation)
    }
}
