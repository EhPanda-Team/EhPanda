import ComposableArchitecture

@Reducer
public struct AppearanceSettingReducer: Sendable {
    @CasePathable
    public enum Route: Sendable {
        case appIcon
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var route: Route?
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none
            }
        }
    }
}
