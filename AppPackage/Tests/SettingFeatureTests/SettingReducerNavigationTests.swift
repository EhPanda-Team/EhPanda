import AppModels
import ComposableArchitecture
import CookieClient
import FileClient
import Foundation
import HapticsClient
import LibraryClient
import LogsClient
@testable import SettingFeature
import Sharing
import Testing

// Covers the Setting tab's single flat navigation stack: root-row taps, child `delegate`-driven
// pushes, and the post-login effect cascade that `SettingReducer` runs while the login screen
// self-dismisses.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct SettingReducerNavigationTests {
    // Every dependency a pushed Setting screen's presentation load can reach, stubbed inert so the
    // navigation assertions never depend on a client's behaviour.
    @MainActor
    private func makeStore(
        initialState: SettingReducer.State = .init()
    ) -> TestStoreOf<SettingReducer> {
        TestStore(initialState: initialState, reducer: SettingReducer.init) {
            $0.cookieClient = .noop
            $0.libraryClient = .noop
            $0.logsClient = .noop
        }
    }

    // MARK: Root menu

    @MainActor
    @Test
    func settingRowTappedAppendsMatchingScreen() async throws {
        let store = makeStore()
        store.exhaustivity = .off

        // Each root row appends exactly its mapped `SettingPath` element, in order.
        for screen in SettingReducer.RootScreen.allCases {
            await store.send(.settingRowTapped(screen))
        }

        // Every row pushed — none deduped, none dropped.
        #expect(store.state.path.count == SettingReducer.RootScreen.allCases.count)
        await store.finish()
    }

    @MainActor
    @Test
    func pushLoginAppendsLoginScreen() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        await store.send(.pushLogin) {
            $0.path.append(.login(.init()))
        }
    }

    @MainActor
    @Test
    func settingRowTappedGuardsAgainstAdjacentDuplicate() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.account))
        #expect(store.state.path.count == 1)

        // A rapid second identical tap is skipped — only the adjacent top is compared.
        await store.send(.settingRowTapped(.account))
        #expect(store.state.path.count == 1)

        // A different row still appends.
        await store.send(.settingRowTapped(.general))
        #expect(store.state.path.count == 2)
        await store.finish()
    }

    // MARK: Child delegate → parent push

    @MainActor
    @Test
    func accountDelegatePushLoginAppendsLogin() async throws {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.account))
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .account(.delegate(.pushLogin)))))

        #expect(store.state.path.count == 2)
        guard case .login = store.state.path.last else {
            Issue.record("Expected .login on top of the Setting stack")
            return
        }
        await store.finish()
    }

    // `.ehSetting`'s push is asserted at the mapping level in `SettingPresentationTests`, not here:
    // presenting it now starts `fetchEhSetting`, and `EhSettingRequest` takes its `URLSession` as an
    // `init` default the reducer never overrides, so a store-level push would issue a real request.

    @MainActor
    @Test
    func appearanceDelegatePushAppIconAppendsAppIcon() async throws {
        let store = makeStore()

        await store.send(.settingRowTapped(.appearance)) {
            $0.path.append(.appearance(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .appearance(.delegate(.pushAppIcon))))) {
            $0.path.append(.appIcon(.init()))
        }
    }

    @MainActor
    @Test
    func generalDelegatePushAppActivityLogsAppendsLogs() async throws {
        // The logs screen reads in-memory `@SharedReader` keys; isolate them so the read can't see
        // another test's pump state.
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.defaultInMemoryStorage = InMemoryStorage()
            $0.libraryClient = .noop
            $0.logsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.general))
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .general(.delegate(.pushAppActivityLogs)))))

        #expect(store.state.path.count == 2)
        guard case .appActivityLogs = store.state.path.last else {
            Issue.record("Expected .appActivityLogs on top of the Setting stack")
            return
        }
        await store.finish()
    }

    // MARK: Child delegate → parent effect

    @MainActor
    @Test
    func generalEnablesTagsExtensionDelegateRebuildsWhenEnabled() async throws {
        let defaults = UserDefaults.inMemory
        try await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock { $0.enableTagsExtension = true }

            // A loading table makes the rebuild's follow-on `fetchTagTranslator` guard-return (no network).
            var initialState = SettingReducer.State()
            initialState.tagTranslatorLoadingState = .loading

            let store = TestStore(initialState: initialState, reducer: SettingReducer.init) {
                $0.defaultAppStorage = defaults
                $0.libraryClient = .noop
                $0.fileClient.loadCachedTagTranslator = { (_: TagTranslatorInfo) throws(AppError) in
                    throw .fileOperationFailed("Read cached tag translations")
                }
            }
            store.exhaustivity = .off

            await store.send(.settingRowTapped(.general))
            let id = try #require(store.state.path.ids.last)
            await store.send(.path(.element(id: id, action: .general(.delegate(.enableTagsExtensionChanged)))))
            await store.receive(\.rebuildTagTranslator)
            await store.finish()
        }
    }

    @MainActor
    @Test
    func generalEnablesTagsExtensionDelegateSkipsRebuildWhenDisabled() async throws {
        // `enableTagsExtension` defaults to false, so the delegate must emit no rebuild — the exhaustive
        // store fails if any effect is left unhandled.
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.defaultAppStorage = UserDefaults.inMemory
            $0.libraryClient = .noop
        }

        await store.send(.settingRowTapped(.general)) {
            $0.path.append(SettingReducer.RootScreen.general.pathElement)
        }
        let id = try #require(store.state.path.ids.last)
        // Presenting General starts its cache measurement; the noop client reports no size, so it
        // settles without a state change.
        await store.receive(\.path[id: id].general.calculateWebImageDiskCache)
        await store.receive(\.path[id: id].general.calculateWebImageDiskCacheDone)
        await store.send(.path(.element(id: id, action: .general(.delegate(.enableTagsExtensionChanged)))))
    }

    // MARK: Child intercepts

    @MainActor
    @Test
    func generalFilePickedImportsAndStoresTagTranslator() async throws {
        let imported = TagTranslator(hasCustomTranslations: true)
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.libraryClient = .noop
            $0.fileClient.importTagTranslator = { _ in .success(imported) }
        }

        await store.send(.settingRowTapped(.general)) {
            $0.path.append(SettingReducer.RootScreen.general.pathElement)
        }
        let id = try #require(store.state.path.ids.last)
        await store.receive(\.path[id: id].general.calculateWebImageDiskCache)
        await store.receive(\.path[id: id].general.calculateWebImageDiskCacheDone)
        let url = URL(filePath: "/tmp/tags.json")
        await store.send(.path(.element(id: id, action: .general(.onTranslationsFilePicked(url)))))

        // The parent intercept runs `fileClient.importTagTranslator`, stores the (in-memory) table
        // and records the custom-import flag in the persisted `tagTranslatorInfo`.
        await store.receive(\.fetchTagTranslatorDone) {
            $0.$tagTranslator.withLock { $0 = imported }
            $0.$tagTranslatorInfo.withLock { $0 = TagTranslatorInfo(hasCustomTranslations: true) }
        }
    }

    // MARK: Post-login cascade

    @MainActor
    @Test
    func loginDoneRunsPostLoginFetchCascade() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.cookieClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.pushLogin)
        let id = try #require(store.state.path.ids.last)

        // Finishing login fans out to the four signed-in fetches; each guards on `didLogin` (false
        // under the noop cookie client) so no network effects run.
        await store.send(.path(.element(id: id, action: .login(.loginDone(.success(nil))))))
        await store.receive(\.fetchIgneous)
        await store.receive(\.fetchUserInfo)
        await store.receive(\.fetchFavoriteCategories)
        await store.receive(\.fetchEhProfileIndex)
    }

    // MARK: Igneous refresh signalling

    @MainActor
    @Test
    func fetchIgneousDoneSuccessSignalsRefreshed() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        let response = try #require(
            HTTPURLResponse(url: .mock, statusCode: 200, httpVersion: nil, headerFields: nil)
        )
        await store.send(.fetchIgneousDone(.success(response)))
        await store.receive(\.igneousRefreshed)
    }

    @MainActor
    @Test
    func fetchIgneousDoneFailureStillSignalsRefreshed() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)
        store.exhaustivity = .off

        await store.send(.fetchIgneousDone(.failure(.notFound)))
        await store.receive(\.igneousRefreshed)
    }
}
