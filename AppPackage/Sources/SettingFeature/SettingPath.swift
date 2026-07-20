import ComposableArchitecture
import ReadingSettingFeature

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
    case reading(ReadingSettingReducer)
    case laboratory(LaboratorySettingReducer)
    case about(StaticSettingScreenReducer)
    case appIcon(AppIconReducer)
}

extension SettingPath.State: Equatable, Sendable {}

extension StackState where Element == SettingPath.State {
    // Skip appending a screen identical to the current top, so a rapid double-activation of a Setting
    // row — or a child re-emitting the same `delegate` — can't stack the same screen twice. Only the
    // adjacent element is checked, mirroring the gallery stacks' guard. Comparison is by *route*, not
    // by value: the screen on top starts loading the moment it is presented, so its state has already
    // diverged from a freshly-initialized element of the same screen by the time a second tap lands.
    // Setting screens carry no per-screen identity (there is one Account screen, one General screen),
    // so the case alone is the route.
    // Returns the new element's id, or `nil` when the push was deduped — so a deduped push starts
    // nothing.
    mutating func appendGuardingDuplicate(_ element: SettingPath.State) -> StackElementID? {
        guard last?.routeKey != element.routeKey else { return nil }
        append(element)
        return ids.last
    }
}

extension SettingPath.State {
    fileprivate var routeKey: String {
        switch self {
        case .account: return "account"
        case .general: return "general"
        case .appearance: return "appearance"
        case .login: return "login"
        case .ehSetting: return "ehSetting"
        case .appActivityLogs: return "appActivityLogs"
        case .download: return "download"
        case .reading: return "reading"
        case .laboratory: return "laboratory"
        case .about: return "about"
        case .appIcon: return "appIcon"
        }
    }
}

extension SettingPath.State {
    // The action that starts this screen's work, sent by `SettingReducer` right after it pushes the
    // screen — the reducer-side replacement for the screens' former view `onAppear`. `nil` means the
    // screen has nothing to start: it renders `@Shared(.setting)` and fetches nothing.
    var onPresentedAction: SettingPath.Action? {
        switch self {
        case .account:
            return .account(.onPresented)
        case .general:
            return .general(.calculateWebImageDiskCache)
        case .ehSetting:
            return .ehSetting(.fetchEhSetting)
        case .appActivityLogs:
            return .appActivityLogs(.refreshAvailableRuns)
        case .appearance, .login, .download, .reading, .laboratory, .about, .appIcon:
            return nil
        }
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
