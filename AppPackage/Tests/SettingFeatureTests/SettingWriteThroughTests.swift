import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// REV-8 / V-2: `setting` is stored directly in `@Shared(.setting)`, so a non-binding write path like
// `syncAppIconTypeDone` (fired at launch) must persist atomically. Previously it mutated a working copy
// and returned `.none`, leaving the persisted value silently diverged until an unrelated binding synced
// it. This pins the fix by reading an INDEPENDENT `@Shared(.setting)` handle rather than `store.state`
// — the working-copy bug updated `state.setting` too, so a `store.state` assertion passed pre-fix and
// wasn't discriminating. Storage is isolated to an in-memory suite so the test never touches real
// UserDefaults.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct SettingWriteThroughTests {
    @MainActor
    @Test(arguments: [AppIconType.ukiyoe.filename, nil])
    func syncAppIconTypeDonePersistsIconTypeToSharedSetting(iconName: String?) async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = SettingReducer.State()
            state.$setting.withLock({ $0.appIconType = .developer })
            let store = TestStore(initialState: state, reducer: SettingReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }
            let expectedType: AppIconType = iconName == nil ? .default : .ukiyoe
            await store.send(.syncAppIconTypeDone(iconName)) {
                $0.$setting.withLock({ $0.appIconType = expectedType })
            }

            @Shared(.setting) var persisted
            #expect(persisted.appIconType == expectedType)
        }
    }
}
