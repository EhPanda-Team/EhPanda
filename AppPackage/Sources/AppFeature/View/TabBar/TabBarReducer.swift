import ComposableArchitecture
import AppModels

@Reducer
struct TabBarReducer {
    @ObservableState
    struct State: Equatable {
        var tabBarItemType: TabBarItemType = .home
    }

    enum Action: Equatable {
        case setTabBarItemType(TabBarItemType)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setTabBarItemType(let type):
                state.tabBarItemType = type
                return .none
            }
        }
    }
}
