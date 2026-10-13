import AppModels
import AppTools
import ComposableArchitecture

@Reducer
struct TabBarReducer {
    @ObservableState
    struct State: Equatable {
        var tabBarItemType: TabBarItemType = .home
    }

    enum Action: Equatable {
        case delegate(Delegate)
        case selectSettingInline
        case setTabBarItemType(TabBarItemType)
    }

    @CasePathable
    enum Delegate: Equatable {
        /// The Setting tab was chosen. The app root, which knows the window's size classes, either
        /// presents Setting as a sheet over the current tab or answers with `selectSettingInline`.
        case openSetting
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .selectSettingInline:
                state.tabBarItemType = .setting
                return .none

            case .setTabBarItemType(.setting):
                return .send(.delegate(.openSetting))

            case .setTabBarItemType(let type):
                state.tabBarItemType = type
                return .none
            }
        }
    }
}
