import ComposableArchitecture
import Testing
import AppModels
import ApplicationClient
@testable import SettingFeature

@MainActor
struct AppearanceSettingReducerTests {
    // The theme picker writes into `@Shared(.setting)`; the reducer applies the interface style through
    // a non-capturable client, so this pins that the change action is handled and runs to completion.
    @Test
    func preferredColorSchemeChangedRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: AppearanceSettingReducer.init) {
            $0.applicationClient = .noop
        }
        await store.send(.preferredColorSchemeChanged(.dark))
        await store.finish()
    }
}
