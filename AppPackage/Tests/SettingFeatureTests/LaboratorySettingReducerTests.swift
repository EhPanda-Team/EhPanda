import ComposableArchitecture
import DFClient
import HapticsClient
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct LaboratorySettingReducerTests {
    // The SNI toggle's side effect (haptic + `DFClient.setActive`) is fire-and-forget, and neither
    // client exposes a capturable double, so this pins the wiring: the change action is handled and its
    // merged effects run to completion without emitting anything unexpected.
    @MainActor
    @Test
    func bypassesSNIFilteringChangedRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: LaboratorySettingReducer.init) {
            $0.hapticsClient = .noop
            $0.dfClient = .noop
        }
        await store.send(.bypassSNIFilteringChanged(true))
        await store.finish()
    }
}
