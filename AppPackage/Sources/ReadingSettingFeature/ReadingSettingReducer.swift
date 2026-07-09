import Sharing
import AppModels
import ComposableArchitecture

// A state-only reducer for the reading-setting editor. It carries `@Shared(.setting)` and vends the
// shared projection (`sharedSetting`) so `ReadingSettingView` binds through its own store instead of
// holding a `@Shared` itself. It runs no logic: every field write goes straight through the shared
// value, and the `Setting` model's clamps keep those writes consistent. Any orientation side effect
// stays with the host — the reader drives it from `ReadingReducer`; the Setting tab has none.
@Reducer
public struct ReadingSettingReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.setting) public var setting: Setting
        public var sharedSetting: Shared<Setting> { $setting }

        public init() {}
    }

    public enum Action: Equatable, Sendable {}

    public init() {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
