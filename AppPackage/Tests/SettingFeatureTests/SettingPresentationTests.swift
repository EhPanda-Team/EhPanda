import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Foundation
import LibraryClient
import LogsClient
@testable import SettingFeature
import Testing

// The Setting screens' loads used to be kicked off by their views' `onAppear`; they are now sent by
// `SettingReducer` on the push that presents them, and the EhSetting teardown that used to run in
// `onDisappear` now runs on the pop that dismisses it.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct SettingPresentationTests {
    // MARK: Screen → load-action mapping

    // The pairing lives on the route, so adding a screen to `SettingPath` without declaring its load
    // is a visible omission here rather than a silently unstarted screen.
    @Test
    func everyScreenDeclaresItsPresentationLoad() {
        #expect(SettingPath.State.account(.init()).onPresentedAction?.is(\.account.onPresented) == true)
        #expect(
            SettingPath.State.general(.init())
                .onPresentedAction?.is(\.general.calculateWebImageDiskCache) == true
        )
        #expect(
            SettingPath.State.ehSetting(.init())
                .onPresentedAction?.is(\.ehSetting.fetchEhSetting) == true
        )
        #expect(
            SettingPath.State.appActivityLogs(.init())
                .onPresentedAction?.is(\.appActivityLogs.refreshAvailableRuns) == true
        )

        // Screens driven entirely by `@Shared(.setting)`, which fetch nothing.
        #expect(SettingPath.State.appearance(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.login(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.download(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.reading(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.laboratory(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.about(.init()).onPresentedAction == nil)
        #expect(SettingPath.State.appIcon(.init()).onPresentedAction == nil)
    }

    // MARK: Push starts the screen

    @MainActor
    @Test
    func pushingAccountLoadsCookies() async throws {
        let cookieClient = CookieClient.testing(memberID: "member-fixture", passHash: "pass-fixture")
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.cookieClient = cookieClient
        }

        await store.send(.settingRowTapped(.account)) {
            $0.path.append(.account(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.receive(\.path[id: id].account.onPresented)
        await store.receive(\.path[id: id].account.loadCookies) {
            $0.path[id: id, case: \.account]?.ehCookiesState = cookieClient.loadCookiesState(host: .ehentai)
            $0.path[id: id, case: \.account]?.exCookiesState = cookieClient.loadCookiesState(host: .exhentai)
        }
        // The jar subscription the same action starts is long-living by design; it is asserted in
        // `AccountSettingReducerTests`, which drives the stream by hand.
        await store.skipInFlightEffects()
    }

    @MainActor
    @Test
    func pushingGeneralMeasuresTheImageCache() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.libraryClient = .init(
                initializeWebImage: {},
                removeAllCachedImages: {},
                cachedImage: { _ in nil },
                cachedImageData: { _ in nil },
                removeCachedImage: { _ in },
                isCached: { _ in false },
                analyzeImageColors: { _ in .none },
                calculateWebImageDiskCacheSize: { 1024 }
            )
        }

        await store.send(.settingRowTapped(.general)) {
            $0.path.append(.general(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.receive(\.path[id: id].general.calculateWebImageDiskCache)
        await store.receive(\.path[id: id].general.calculateWebImageDiskCacheDone) {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = .useAll
            $0.path[id: id, case: \.general]?.diskImageCacheSize = formatter.string(fromByteCount: 1024)
        }
    }

    @MainActor
    @Test
    func pushingAppActivityLogsListsPreviousRuns() async throws {
        let run = RunLogFile(
            url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-3.jsonl"),
            date: Date(timeIntervalSince1970: 0),
            runCount: 3
        )
        var logsClient = LogsClient.noop
        logsClient.listRunFiles = { [run] }

        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.defaultInMemoryStorage = InMemoryStorage()
            $0.libraryClient = .noop
            $0.logsClient = logsClient
        }
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.general))
        let generalID = try #require(store.state.path.ids.last)
        await store.send(
            .path(.element(id: generalID, action: .general(.delegate(.pushAppActivityLogs))))
        )
        let logsID = try #require(store.state.path.ids.last)

        await store.receive(\.path[id: logsID].appActivityLogs.refreshAvailableRuns)
        await store.receive(\.path[id: logsID].appActivityLogs.availableRunsResponse) {
            $0.path[id: logsID, case: \.appActivityLogs]?.previousRuns = [run]
        }
        await store.finish()
    }

    // A deduped push must start nothing: the screen it would present is already on top, already
    // loaded. The store's end-of-test in-flight check fails if the second tap starts a load.
    @MainActor
    @Test
    func dedupedPushStartsNothing() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.libraryClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.general))
        await store.finish()

        await store.send(.settingRowTapped(.general))
        #expect(store.state.path.count == 1)
    }

    // MARK: Pop tears the screen down

    @MainActor
    @Test
    func poppingEhSettingPersistsTheSelectedProfile() async throws {
        let cookieClient = CookieClient.testing()
        var ehSettingState = EhSettingReducer.State()
        ehSettingState.ehSetting = .empty(
            ehProfiles: [EhProfile(value: 7, name: "EhPanda", isSelected: true)]
        )

        var initialState = SettingReducer.State()
        initialState.$setting.withLock({ $0.galleryHost = .ehentai })
        initialState.path.append(.ehSetting(ehSettingState))

        let store = TestStore(initialState: initialState, reducer: SettingReducer.init) {
            $0.cookieClient = cookieClient
        }
        let id = try #require(store.state.path.ids.last)

        await store.send(.path(.popFrom(id: id))) {
            $0.path.removeAll()
        }
        await store.finish()

        // The screen is gone, but its last-viewed EhPanda profile was persisted on the way out.
        let cookies = cookieClient.cookies(for: GalleryHost.ehentai.url)
        #expect(cookies.map(\.name) == [Defaults.Cookie.selectedProfile])
        #expect(cookies.map(\.value) == ["7"])
    }

    // Every other screen's teardown is TCA's own pop-cancellation, so popping them writes nothing.
    @MainActor
    @Test
    func poppingAnotherScreenWritesNoCookie() async throws {
        let cookieClient = CookieClient.testing()
        var initialState = SettingReducer.State()
        initialState.path.append(.about(.init()))

        let store = TestStore(initialState: initialState, reducer: SettingReducer.init) {
            $0.cookieClient = cookieClient
        }
        let id = try #require(store.state.path.ids.last)

        await store.send(.path(.popFrom(id: id))) {
            $0.path.removeAll()
        }
        await store.finish()

        #expect(cookieClient.cookies(for: GalleryHost.ehentai.url).isEmpty)
        #expect(cookieClient.cookies(for: GalleryHost.exhentai.url).isEmpty)
    }
}
