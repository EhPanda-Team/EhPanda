import ComposableArchitecture
import AppModels
import AppTools
import HapticsClient
import DatabaseClient
import DeviceClient
import FiltersFeature
import QuickSearchFeature
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

        public var historyKeywords = [String]()
        public var quickSearchWords = [QuickSearchWord]()

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
            self.historyKeywords = historyKeywords
        }

        mutating func removeHistoryKeyword(_ keyword: String) {
            historyKeywords = historyKeywords.filter { $0 != keyword }
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

        case syncHistoryKeywords
        case fetchDatabaseInfos
        case fetchDatabaseInfosDone(AppEnv)
        case appendHistoryKeyword(String)
        case removeHistoryKeyword(String)
        case fetchHistoryGalleries
        case fetchHistoryGalleriesDone([Gallery])
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.path) { oldValue, state in
                // Returning to the root refreshes history keywords / quick-search words that a
                // pushed Search screen (or the QuickSearch editor) may have changed.
                if !oldValue.isEmpty, state.path.isEmpty {
                    return .send(.fetchDatabaseInfos)
                }
                return .none
            }

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
                return .send(.syncHistoryKeywords)

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

            case .syncHistoryKeywords:
                return .run { [historyKeywords = state.historyKeywords] _ in
                    await databaseClient.updateHistoryKeywords(historyKeywords)
                }

            case .fetchDatabaseInfos:
                return .run { send in
                    let appEnv = await databaseClient.fetchAppEnv()
                    await send(.fetchDatabaseInfosDone(appEnv))
                }

            case .fetchDatabaseInfosDone(let appEnv):
                state.historyKeywords = appEnv.historyKeywords
                state.quickSearchWords = appEnv.quickSearchWords
                return .none

            case .appendHistoryKeyword(let keyword):
                state.appendHistoryKeywords([keyword])
                return .send(.syncHistoryKeywords)

            case .removeHistoryKeyword(let keyword):
                state.removeHistoryKeyword(keyword)
                return .send(.syncHistoryKeywords)

            case .fetchHistoryGalleries:
                return .run { send in
                    let historyGalleries = await databaseClient.fetchHistoryGalleries(fetchLimit: 10)
                    await send(.fetchHistoryGalleriesDone(historyGalleries))
                }

            case .fetchHistoryGalleriesDone(let galleries):
                state.historyGalleries = Array(galleries.prefix(min(galleries.count, 10)))
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
