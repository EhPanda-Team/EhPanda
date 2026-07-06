import Testing
import AppModels
import Sharing
@testable import SettingFeature
import ComposableArchitecture

// REV-8: `setting` is now stored directly in `@Shared(.setting)`, so a non-binding write path like
// `syncAppIconTypeDone` (fired at launch) persists atomically. Previously it mutated a working copy and
// returned `.none`, leaving the persisted value silently diverged until an unrelated binding synced it.
@Suite
@MainActor
struct SettingWriteThroughTests {
    @Test
    func syncAppIconTypeDonePersistsIconTypeToSharedSetting() async {
        let store = TestStore(initialState: .init(), reducer: SettingReducer.init)
        store.exhaustivity = .off

        // The alternate-icon name maps to `.ukiyoe`; the derived type is written through `state.$setting`.
        await store.send(.syncAppIconTypeDone(AppIconType.ukiyoe.filename))

        #expect(store.state.setting.appIconType == .ukiyoe)
    }
}
