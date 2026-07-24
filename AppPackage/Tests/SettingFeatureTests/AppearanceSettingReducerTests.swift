import AnalyticsClient
import ApplicationClient
import AppModels
import ComposableArchitecture
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct AppearanceSettingReducerTests {
    // The theme picker writes into `@Shared(.setting)`; the reducer applies the interface style through
    // a non-capturable client, so this pins that the change action is handled and runs to completion.
    @MainActor
    @Test
    func preferredColorSchemeChangedRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: AppearanceSettingReducer.init) {
            $0.analyticsClient = .noop
            $0.applicationClient = .noop
        }
        await store.send(.preferredColorSchemeChanged(.dark))
        await store.finish()
    }
}
