import ComposableArchitecture
import AppModels
import Sharing
import AppTools
import HapticsClient
import NetworkingFeature
import FiltersFeature

@Reducer
public struct PopularReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case pushDetail(Gallery)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
    }

    private enum CancelID {
        case fetchGalleries
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.globalFilter) public var globalFilter: Filter
        @Presents public var destination: Destination.State?
        public var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        public var galleries = [Gallery]()
        public var loadingState: LoadingState = .idle

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case filtersButtonTapped
        case destination(PresentationAction<Destination.Action>)

        case fetchGalleries
        case fetchGalleriesDone(Result<[Gallery], AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .destination:
                return .none

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                let filter = state.globalFilter
                return .run { send in
                    let response = await PopularGalleriesRequest(filter: filter).response()
                    await send(.fetchGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let galleries):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.galleries = galleries
                    return .none
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.filters,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
    }
}

extension PopularReducer.Destination.State: Equatable, Sendable {}
