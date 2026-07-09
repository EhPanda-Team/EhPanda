import ComposableArchitecture
import Testing
import HapticsClient
import DFClient
@testable import SettingFeature

@MainActor
struct LaboratorySettingReducerTests {
    // The SNI toggle's side effect (haptic + `DFClient.setActive`) is fire-and-forget, and neither
    // client exposes a capturable double, so this pins the wiring: the change action is handled and its
    // merged effects run to completion without emitting anything unexpected.
    @Test
    func bypassesSNIFilteringChangedRunsToCompletion() async {
        let store = TestStore(initialState: .init(), reducer: LaboratorySettingReducer.init) {
            $0.hapticsClient = .noop
            $0.dfClient = .noop
        }
        await store.send(.bypassesSNIFilteringChanged(true))
        await store.finish()
    }
}
