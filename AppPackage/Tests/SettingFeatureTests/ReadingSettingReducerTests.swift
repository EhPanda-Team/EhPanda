import ComposableArchitecture
import Testing
import DeviceClient
import AppDelegateClient
@testable import SettingFeature

@MainActor
struct ReadingSettingReducerTests {
    // Turning landscape ON never re-locks orientation, so the change action returns no effect and
    // touches no dependency.
    @Test
    func enablingLandscapeRunsNoEffect() async {
        let store = TestStore(initialState: .init(), reducer: ReadingSettingReducer.init)
        await store.send(.enablesLandscapeChanged(true))
        await store.finish()
    }

    // Turning landscape OFF on a phone re-applies the portrait mask; this pins that the effect chain
    // runs to completion (the AppDelegate mask call is fire-and-forget and not capturable).
    @Test
    func disablingLandscapeOnPhoneRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: ReadingSettingReducer.init) {
            $0.deviceClient = .noop
            $0.appDelegateClient = .noop
        }
        await store.send(.enablesLandscapeChanged(false))
        await store.finish()
    }
}
