import ComposableArchitecture

// The single flat navigation stack for the Setting tab, owned by `SettingReducer`. Every drill-down
// screen is a path element; child screens never push directly — they emit `delegate` actions that
// `SettingReducer` observes and appends to `path`. Each screen's view reads and writes `setting`
// through its own `@Shared(.setting)`/`@SharedReader(.setting)`. Screens whose edits trigger a side
// effect own a dedicated reducer for it; the remaining state-free screens (download, about) share
// `StaticSettingScreenReducer`.
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
    case laboratory(LaboratorySettingReducer)
    case about(StaticSettingScreenReducer)
    case appIcon(StaticSettingScreenReducer)
}

extension SettingPath.State: Equatable, Sendable {}

extension StackState where Element == SettingPath.State {
    // Skip appending a screen identical to the current top, so a rapid double-activation of a Setting
    // row — or a child re-emitting the same `delegate` — can't stack the same screen twice. Setting
    // path states are cleanly `Equatable` (no volatile per-init fields), so a plain value comparison
    // suffices here; only the adjacent element is checked, mirroring the gallery stacks' guard.
    mutating func appendGuardingDuplicate(_ element: SettingPath.State) {
        guard last != element else { return }
        append(element)
    }
}

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
