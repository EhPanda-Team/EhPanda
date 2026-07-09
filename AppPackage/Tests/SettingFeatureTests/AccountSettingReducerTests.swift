import ComposableArchitecture
import Testing
import AppModels
import UserDefaultsClient
@testable import SettingFeature

@MainActor
struct AccountSettingReducerTests {
    // The gallery-host picker writes into `@Shared(.setting)`; the reducer mirrors the choice into
    // UserDefaults (a non-capturable fire-and-forget client), so this pins that the wiring is handled
    // and runs to completion.
    @Test
    func galleryHostChangedRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: AccountSettingReducer.init) {
            $0.userDefaultsClient = .noop
        }
        await store.send(.galleryHostChanged(.exhentai))
        await store.finish()
    }
}
