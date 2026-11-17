import AppComponents
import AppModels
import ComposableArchitecture
import CoreGraphics
import Sharing

@Reducer
struct LibraryFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        /// What both layouts show. It is kept in memory only and carries over between layouts within one process,
        /// and it is never itself persisted, because only compact choices are remembered (261117-tyj, A-2).
        var selection: LibraryGroup?
        /// The group last chosen on the compact layout's picker (A-2). `AppReducer`'s compact-only hook writes it,
        /// and the compact initial selection reads it.
        @Shared(.libraryPickerChoice) var pickerChoice: LibraryPickerChoice?
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
        /// Sent when the compact layout has no selection (the layout turned compact, or the compact picker was
        /// cleared). `AppReducer` resolves it to the remembered picker choice, else Favorites at the current index.
        case showInitialSelection
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .select(let selection):
                state.selection = selection
                return selection == nil && !state.usesSidebar ? .send(.showInitialSelection) : .none
            case .deviceChanged(let device):
                state.device = device
                return .none
            case .viewportChanged(let viewport):
                state.viewport = viewport
                return .none
            case .manageFolders, .createDefaultFolder, .syncFromSources, .showInitialSelection:
                return .none
            }
        }
        .onChange(of: \.usesSidebar) { _, state in
            guard !state.usesSidebar, state.selection == nil else { return .none }
            return .send(.showInitialSelection)
        }
    }
}
