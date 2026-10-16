import AppModels
import ComposableArchitecture

@Reducer
struct LibraryFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var selection: LibraryGroup?
        var isDownloadsExpanded = true
        var isFavoritesExpanded = true

        init(selection: LibraryGroup? = nil) {
            self.selection = selection
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case select(LibraryGroup?)
        case manageFolders
        case createDefaultFolder
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
            case .manageFolders, .createDefaultFolder, .syncFromSources:
                return .none
            }
        }
    }
}
