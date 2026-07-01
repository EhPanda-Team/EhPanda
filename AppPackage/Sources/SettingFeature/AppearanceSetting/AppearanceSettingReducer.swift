import ComposableArchitecture

@Reducer
public struct AppearanceSettingReducer: Sendable {
    // Pushes handled by SettingReducer, which owns the Setting navigation stack. The screen itself is
    // stateless — its controls bind directly into `SettingReducer.State.setting` from the root.
    public enum Delegate: Equatable, Sendable {
        case pushAppIcon
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case delegate(Delegate)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none
            }
        }
    }
}
