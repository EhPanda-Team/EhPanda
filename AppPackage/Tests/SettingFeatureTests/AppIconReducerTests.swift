import Foundation
import Testing
import AppModels
import Sharing
@testable import SettingFeature
import ComposableArchitecture

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct AppIconReducerTests {
    // The screen writes `appIconType` straight into `@Shared(.setting)`; the reducer then reconciles the
    // stored value against whatever icon the system actually reports. This pins that reconciliation by
    // feeding the system's icon name directly and asserting it persists through an independent handle,
    // with storage isolated to an in-memory suite.
    @MainActor
    @Test
    func syncAppIconTypeDonePersistsMatchedType() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let store = TestStore(initialState: .init(), reducer: AppIconReducer.init) {
                $0.defaultAppStorage = defaults
            }
            store.exhaustivity = .off

            await store.send(.syncAppIconTypeDone(AppIconType.ukiyoe.filename))

            @Shared(.setting) var persisted
            #expect(persisted.appIconType == .ukiyoe)
        }
    }
}
