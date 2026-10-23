import AppComponents
import AppModels
import ComposableArchitecture
import CoreGraphics

@Reducer
struct LibraryFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var selection: LibraryGroup?
        var isDownloadsExpanded = true
        var isFavoritesExpanded = true
        var device: WindowDevice?
        var viewport: CGSize = .zero

        var usesSidebar: Bool {
            switch device {
            case .pad, .none: true
            case .other: false
            case .duo:
                viewport == .zero || device?.supportsLandscapePanes(in: viewport) == true
            }
        }

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
        case deviceChanged(WindowDevice)
        case viewportChanged(CGSize)
        case showInitialFavorites
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .select(let selection):
                state.selection = selection
                return selection == nil && !state.usesSidebar ? .send(.showInitialFavorites) : .none
            case .deviceChanged(let device):
                state.device = device
                return .none
            case .viewportChanged(let viewport):
                state.viewport = viewport
                return .none
            case .manageFolders, .createDefaultFolder, .syncFromSources, .showInitialFavorites:
                return .none
            }
        }
        .onChange(of: \.usesSidebar) { _, state in
            guard !state.usesSidebar, state.selection == nil else { return .none }
            return .send(.showInitialFavorites)
        }
    }
}
