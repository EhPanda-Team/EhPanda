import AppTools
import ComposableArchitecture
import AppModels
import Sharing
import HapticsClient
import NetworkingFeature
import FiltersFeature
import QuickSearchFeature

@Reducer
public struct DetailSearchReducer: Sendable {
    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case quickSearch(QuickSearchReducer)
    }

    public enum Delegate: Equatable, Sendable {
        case pushDetail(Gallery)
    }

    private enum CancelID {
        case fetchGalleries, fetchMoreGalleries
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.searchFilter) public var searchFilter: Filter
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.setting) public var setting: Setting
        @Presents public var destination: Destination.State?
        public var keyword = ""
        public var lastKeyword = ""

        public var galleries = [Gallery]()
        public var pageNumber = PageNumber()
        public var loadingState: LoadingState = .idle
        public var footerLoadingState: LoadingState = .idle

        public init(keyword: String = "") {
            self.keyword = keyword
            self.lastKeyword = keyword
        }

        mutating func insertGalleries(_ galleries: [Gallery]) {
            galleries.forEach { gallery in
                if !self.galleries.contains(gallery) {
                    self.galleries.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case filtersButtonTapped
        case quickSearchButtonTapped
        case destination(PresentationAction<Destination.Action>)

        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.keyword) { _, state in
                if !state.keyword.isEmpty {
                    state.lastKeyword = state.keyword
                }
                return .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .destination:
                return .none

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                    state.lastKeyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = state.searchFilter
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await SearchGalleriesRequest(keyword: lastKeyword, filter: filter).response()
                    await send(.fetchGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    state.galleries = galleries
                    return .none
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries.last?.id
                else { return .none }
                state.footerLoadingState = .loading
                let filter = state.searchFilter
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await MoreSearchGalleriesRequest(
                        keyword: lastKeyword, filter: filter, lastID: lastID
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.pageNumber = pageNumber
                    state.insertGalleries(galleries)

                    var effects: [Effect<Action>] = []
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.loadingState = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.filters,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DetailSearchReducer.Destination.State: Equatable, Sendable {}
