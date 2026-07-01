import ComposableArchitecture

// The single flat navigation stack for the Setting tab, owned by `SettingReducer`. Every drill-down
// screen is a path element; child screens never push directly — they emit `delegate` actions that
// `SettingReducer` observes and appends to `path`. State-free screens (driven purely by bindings into
// `SettingReducer.State.setting`) are backed by `StaticSettingScreenReducer` and built from those
// root bindings in `SettingView`'s destination switch.
@Reducer
public enum SettingPath {
    case account(AccountSettingReducer)
    case general(GeneralSettingReducer)
    case appearance(AppearanceSettingReducer)
    case login(LoginReducer)
    case ehSetting(EhSettingReducer)
    case appActivityLogs(AppActivityLogsReducer)
    case download(StaticSettingScreenReducer)
    case reading(StaticSettingScreenReducer)
    case laboratory(StaticSettingScreenReducer)
    case about(StaticSettingScreenReducer)
    case appIcon(StaticSettingScreenReducer)
}

extension SettingPath.State: Equatable, Sendable {}

// A placeholder reducer for Setting screens that hold no state and run no logic (their views are
// driven entirely by bindings into `SettingReducer.State.setting`). Shared across every such leaf.
@Reducer
public struct StaticSettingScreenReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Equatable, Sendable {}

    public init() {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
