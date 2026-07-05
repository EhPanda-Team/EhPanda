import ComposableArchitecture
import AppModels
import Sharing
import AppTools
import HapticsClient
import DeviceClient
import FiltersFeature
import QuickSearchFeature
import NetworkingFeature
import DetailFeature

@Reducer
public struct SearchRootReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(String)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case quickSearch(QuickSearchReducer)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<SearchPath.State>()
        @Presents public var destination: Destination.State?
        public var keyword = ""
        public var historyGalleries = [Gallery]()

        // Persisted directly in app storage; both are also read/written by pushed Search screens
        // and the QuickSearch editor, which share the same keys, so changes stay live without reloads.
        @Shared(.historyKeywords) public var historyKeywords: [String]
        @Shared(.quickSearchWords) public var quickSearchWords: [QuickSearchWord]

        public init() {}

        mutating func appendHistoryKeywords(_ keywords: [String]) {
            guard !keywords.isEmpty else { return }
            var historyKeywords = historyKeywords

            keywords.forEach { keyword in
                guard !keyword.isEmpty else { return }
                if let index = historyKeywords.firstIndex(where: {
                    $0.caseInsensitiveEqualsTo(keyword)
                }) {
                    if historyKeywords.last != keyword {
                        historyKeywords.remove(at: index)
                        historyKeywords.append(keyword)
                    }
                } else {
                    historyKeywords.append(keyword)
                    let overflow = historyKeywords.count - 20
                    if overflow > 0 {
                        historyKeywords = Array(
                            historyKeywords.dropFirst(overflow)
                        )
                    }
                }
            }
            $historyKeywords.withLock { $0 = historyKeywords }
        }

        mutating func removeHistoryKeyword(_ keyword: String) {
            $historyKeywords.withLock { $0.removeAll { $0 == keyword } }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case pushSearch
        case galleryTapped(String)
        case pushGalleryDetail(String)
        case path(StackActionOf<SearchPath>)
        case setKeyword(String)
        case filtersButtonTapped
        case quickSearchButtonTapped
        case destination(PresentationAction<Destination.Action>)

        case appendHistoryKeyword(String)
        case removeHistoryKeyword(String)
        case fetchHistoryGalleries
        case fetchHistoryGalleriesDone(Result<[Gallery], AppError>)
    }

    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .pushSearch:
                state.path.appendGuardingDuplicate(.search(.init(keyword: state.keyword)))
                return .none

            case .galleryTapped(let gid),
                 let .path(.element(id: _, action: .search(.delegate(.pushDetail(gid))))):
                return GalleryNavigation.routeGalleryDetail(
                    isPad: deviceClient.isPad,
                    present: { .delegate(.presentGalleryDetail(gid)) },
                    push: { .pushGalleryDetail(gid) }
                )

            case .pushGalleryDetail(let gid):
                state.path.appendGuardingDuplicate(.gallery(.detail(.init(gid: gid))))
                return .none

            case .delegate:
                return .none

            case let .path(.element(id: _, action: .search(.delegate(.searchPerformed(keyword))))):
                state.appendHistoryKeywords([keyword])
                return .none

            case let .path(.element(id: _, action: .gallery(.comments(.delegate(.performedCommentAction(gid)))))):
                guard let id = state.path.galleryDetailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .gallery(.detail(.fetchGalleryDetail)))))

            case let .path(.element(id: _, action: .gallery(galleryAction))):
                if let next = GalleryNavigation.nextScreen(for: galleryAction) {
                    state.path.appendGuardingDuplicate(.gallery(next))
                }
                return .none

            case .path:
                return .none

            case .setKeyword(let keyword):
                state.keyword = keyword
                return .none

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .destination:
                return .none

            case .appendHistoryKeyword(let keyword):
                state.appendHistoryKeywords([keyword])
                return .none

            case .removeHistoryKeyword(let keyword):
                state.removeHistoryKeyword(keyword)
                return .none

            case .fetchHistoryGalleries:
                // "Recently seen" suggestions: the 10 most-recent history entries, metadata
                // refetched on demand since no gallery snapshot is persisted.
                @Shared(.galleryHistory) var galleryHistory
                let pairs = galleryHistory.prefix(10).map { (gid: $0.gid, token: $0.token) }
                guard !pairs.isEmpty else {
                    state.historyGalleries = []
                    return .none
                }
                return .run { send in
                    let response = await GalleriesMetadataRequest(gidList: pairs).response()
                    await send(.fetchHistoryGalleriesDone(response))
                }

            case .fetchHistoryGalleriesDone(let result):
                if case .success(let galleries) = result {
                    state.historyGalleries = galleries
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
        .forEach(\.path, action: \.path)
    }
}

extension SearchRootReducer.Destination.State: Equatable, Sendable {}
