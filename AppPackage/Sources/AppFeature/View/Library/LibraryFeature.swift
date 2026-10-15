import AppModels
import ComposableArchitecture

@Reducer
struct LibraryFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var selection: LibraryGroup?

        init(selection: LibraryGroup? = nil) {
            self.selection = selection
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case select(LibraryGroup?)
        case manageFolders
        case syncFromSources
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .select(let selection):
                state.selection = selection
                return .none
            case .manageFolders, .syncFromSources:
                return .none
            }
        }
    }
}
