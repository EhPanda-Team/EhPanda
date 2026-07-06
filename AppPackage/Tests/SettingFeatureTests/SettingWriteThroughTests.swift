import Foundation
import Testing
import AppModels
import Sharing
@testable import SettingFeature
import ComposableArchitecture

// REV-8 / V-2: `setting` is stored directly in `@Shared(.setting)`, so a non-binding write path like
// `syncAppIconTypeDone` (fired at launch) must persist atomically. Previously it mutated a working copy
// and returned `.none`, leaving the persisted value silently diverged until an unrelated binding synced
// it. This pins the fix by reading an INDEPENDENT `@Shared(.setting)` handle rather than `store.state`
// — the working-copy bug updated `state.setting` too, so a `store.state` assertion passed pre-fix and
// wasn't discriminating. Storage is isolated to an in-memory suite so the test never touches real
// UserDefaults.
@Suite
@MainActor
struct SettingWriteThroughTests {
    @Test
    func syncAppIconTypeDonePersistsIconTypeToSharedSetting() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let store = TestStore(initialState: .init(), reducer: SettingReducer.init) {
                $0.defaultAppStorage = defaults
            }
            store.exhaustivity = .off

            // The alternate-icon name maps to `.ukiyoe`; the derived type is written through `$setting`.
            await store.send(.syncAppIconTypeDone(AppIconType.ukiyoe.filename))

            @Shared(.setting) var persisted
            #expect(persisted.appIconType == .ukiyoe)
        }
    }
}
