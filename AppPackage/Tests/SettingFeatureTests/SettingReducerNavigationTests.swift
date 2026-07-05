import Testing
import Foundation
import AppModels
import Sharing
import CookieClient
import FileClient
import HapticsClient
@testable import SettingFeature
import ComposableArchitecture

// Covers the Setting tab's single flat navigation stack: root-row taps, child `delegate`-driven
// pushes, and the post-login effect cascade that `SettingReducer` runs while the login screen
// self-dismisses.
@Suite
@MainActor
struct SettingReducerNavigationTests {
    // MARK: Root menu

    @Test
    func settingRowTappedAppendsMatchingScreen() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        // Each root row appends exactly its mapped `SettingPath` element, in order.
        for screen in SettingReducer.RootScreen.allCases {
            await store.send(.settingRowTapped(screen)) {
                $0.path.append(screen.pathElement)
            }
        }

        #expect(store.state.path.count == SettingReducer.RootScreen.allCases.count)
    }

    @Test
    func pushLoginAppendsLoginScreen() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        await store.send(.pushLogin) {
            $0.path.append(.login(.init()))
        }
    }

    @Test
    func settingRowTappedGuardsAgainstAdjacentDuplicate() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)
        store.exhaustivity = .off

        await store.send(.settingRowTapped(.account))
        #expect(store.state.path.count == 1)

        // A rapid second identical tap is skipped — only the adjacent top is compared.
        await store.send(.settingRowTapped(.account))
        #expect(store.state.path.count == 1)

        // A different row still appends.
        await store.send(.settingRowTapped(.general))
        #expect(store.state.path.count == 2)
    }

    // MARK: Child delegate → parent push

    @Test
    func accountDelegatePushLoginAppendsLogin() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        await store.send(.settingRowTapped(.account)) {
            $0.path.append(.account(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .account(.delegate(.pushLogin))))) {
            $0.path.append(.login(.init()))
        }
    }

    @Test
    func accountDelegatePushEhSettingAppendsEhSetting() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        await store.send(.settingRowTapped(.account)) {
            $0.path.append(.account(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .account(.delegate(.pushEhSetting))))) {
            $0.path.append(.ehSetting(.init()))
        }
    }

    @Test
    func appearanceDelegatePushAppIconAppendsAppIcon() async throws {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)

        await store.send(.settingRowTapped(.appearance)) {
            $0.path.append(.appearance(.init()))
        }
        let id = try #require(store.state.path.ids.last)
        await store.send(.path(.element(id: id, action: .appearance(.delegate(.pushAppIcon))))) {
            $0.path.append(.appIcon(.init()))
        }
    }

    @Test
    func generalDelegatePushAppActivityLogsAppendsLogs() async throws {
        // The logs screen reads in-memory `@SharedReader` keys; isolate them so the read can't see
        // another test's pump state.
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.defaultInMemoryStorage = InMemoryStorage()
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
    }

    // MARK: Child intercepts

    @Test
    func generalFilePickedImportsAndStoresTagTranslator() async throws {
        let imported = TagTranslator(hasCustomTranslations: true)
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
            $0.fileClient.importTagTranslator = { _ in .success(imported) }
            $0.databaseClient = .noop
        }

        await store.send(.settingRowTapped(.general)) {
            $0.path.append(SettingReducer.RootScreen.general.pathElement)
        }
        let id = try #require(store.state.path.ids.last)
        let url = URL(filePath: "/tmp/tags.json")
        await store.send(.path(.element(id: id, action: .general(.onTranslationsFilePicked(url)))))

        // The parent intercept runs `fileClient.importTagTranslator` and stores the result
        // (write-through to `@Shared(.tagTranslator)`).
        await store.receive(\.fetchTagTranslatorDone) {
            $0.$tagTranslator.withLock { $0 = imported }
        }
    }

    // MARK: Post-login cascade

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

    @Test
    func fetchIgneousDoneFailureStillSignalsRefreshed() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)
        store.exhaustivity = .off

        await store.send(.fetchIgneousDone(.failure(.notFound)))
        await store.receive(\.igneousRefreshed)
    }
}
