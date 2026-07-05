import ComposableArchitecture
import AppModels
import Sharing
import Resources
import AppComponents

@Reducer
public struct FiltersReducer: Sendable {
    public enum Dialog: Equatable, Sendable {
        case confirmReset
    }

    public enum FocusedBound: Sendable {
        case lower
        case upper
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var filterRange: FilterRange = .search
        public var focusedBound: FocusedBound?

        public var searchFilter = Filter()
        public var globalFilter = Filter()
        public var watchedFilter = Filter()

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case resetFiltersButtonTapped
        case onTextFieldSubmitted

        case syncFilter(FilterRange)
        case resetFilters
        case fetchFilters
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.searchFilter) { _, state in
                state.searchFilter.fixInvalidData()
                return .send(.syncFilter(.search))
            }
            .onChange(of: \.globalFilter) { _, state in
                state.globalFilter.fixInvalidData()
                return .send(.syncFilter(.global))
            }
            .onChange(of: \.watchedFilter) { _, state in
                state.watchedFilter.fixInvalidData()
                return .send(.syncFilter(.watched))
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .resetFiltersButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .reset)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmReset) {
                        TextState(localized: .reset)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .resetDescription)
                }
                return .none

            case .confirmationDialog(.presented(.confirmReset)):
                return .send(.resetFilters)

            case .confirmationDialog:
                return .none

            case .onTextFieldSubmitted:
                switch state.focusedBound {
                case .lower:
                    state.focusedBound = .upper
                case .upper:
                    state.focusedBound = nil
                default:
                    break
                }
                return .none

            case .syncFilter(let range):
                // Write-through to persisted storage; the working copies stay the edit source so the
                // `BindingReducer` `.onChange` `fixInvalidData` normalization keeps running.
                switch range {
                case .search:
                    @Shared(.searchFilter) var storedFilter
                    $storedFilter.withLock { $0 = state.searchFilter }
                case .global:
                    @Shared(.globalFilter) var storedFilter
                    $storedFilter.withLock { $0 = state.globalFilter }
                case .watched:
                    @Shared(.watchedFilter) var storedFilter
                    $storedFilter.withLock { $0 = state.watchedFilter }
                }
                return .none

            case .resetFilters:
                switch state.filterRange {
                case .search:
                    state.searchFilter = .init()
                    return .send(.syncFilter(.search))
                case .global:
                    state.globalFilter = .init()
                    return .send(.syncFilter(.global))
                case .watched:
                    state.watchedFilter = .init()
                    return .send(.syncFilter(.watched))
                }

            case .fetchFilters:
                // Load the persisted filters into the working copies (synchronous @Shared reads).
                @Shared(.searchFilter) var searchFilter
                @Shared(.globalFilter) var globalFilter
                @Shared(.watchedFilter) var watchedFilter
                state.searchFilter = searchFilter
                state.globalFilter = globalFilter
                state.watchedFilter = watchedFilter
                return .none
            }
        }
    }
}
