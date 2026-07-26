import AnalyticsClient
import AppModels
import AppTools
import ComposableArchitecture
import DetailFeature
import DeviceClient
import FiltersFeature
import HapticsClient
import NetworkingFeature
import QuickSearchFeature
import Sharing

@Reducer
public struct SearchRootReducer: Sendable {
    private enum CancelID {
        case fetchHistoryGalleries
    }

    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(Gallery)
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
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.setting) public var setting: Setting

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
            $historyKeywords.withLock({ $0 = historyKeywords })
        }

        mutating func removeHistoryKeyword(_ keyword: String) {
            $historyKeywords.withLock { $0.removeAll { $0 == keyword } }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case delegate(Delegate)
        case pushSearch
        case galleryTapped(Gallery)
        case pushGalleryDetail(Gallery)
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

    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // Presentation-driven lifecycle: Search is a tab root that outlives any single visit, so
            // the app reducer sends this when the Search tab becomes the active one — replacing the
            // former view `onAppear`. `fetchHistoryGalleries` carries its own unchanged-gids guard,
            // so re-activating the tab re-downloads nothing.
            case .onPresented:
                return .send(.fetchHistoryGalleries)

            case .pushSearch:
                // Pushing the results screen is what starts its search, the reducer-side replacement
                // for the former view `onAppear`. A `nil` id means the push was deduped.
                guard let id = state.path.appendGuardingDuplicate(
                    .search(.init(keyword: state.keyword))
                ) else { return .none }
                return .send(.path(.element(id: id, action: .search(.onPresented))))

            case .galleryTapped(let gallery),
                 let .path(.element(id: _, action: .search(.delegate(.pushDetail(gallery))))):
                // No analytics here: this tap routes to a phone push (`.pushGalleryDetail`, counted
                // there) or an iPad modal (counted by the app-root `presentGalleryDetail`); emitting
                // at the tap would double-count one open across the two device paths (T-14-13).
                return GalleryNavigation.routeGalleryDetail(
                    deviceType: deviceClient.deviceType,
                    present: { .delegate(.presentGalleryDetail(gallery)) },
                    push: { .pushGalleryDetail(gallery) }
                )

            case .pushGalleryDetail(let gallery):
                let screen = GalleryPath.State.detail(.init(gallery: gallery))
                return .merge(
                    GalleryNavigation.presentationEffect(
                        id: state.path.appendGuardingDuplicate(.gallery(screen)),
                        screen: screen,
                        embed: { .path(.element(id: $0, action: .gallery($1))) }
                    ),
                    // Same content-free derivation as the other four gallery-detail entry paths: a
                    // closed `Category` plus exact per-namespace tag counts — no gid, token, title,
                    // URL or tag text (D-06, D-09).
                    //
                    // Load-bearing because of the device split above: without it a search-originated
                    // open is recorded from iPads only, so the metric is not merely short but skewed
                    // by device idiom — worse than an absent one, since it still looks complete.
                    .run(operation: { _ in
                        analyticsClient.send(.galleryDetailOpened(
                            category: gallery.category,
                            tagNamespaces: TagNamespaceCounts(tags: gallery.tags)
                        ))
                    })
                )

            case .delegate:
                return .none

            case let .path(.element(id: _, action: .search(.delegate(.searchPerformed(keyword))))):
                // Deliberately emits no analytics signal. This is the persistence path for the raw
                // keyword; the performed-search signal is emitted once at SearchReducer's fetch
                // completion as a reduced SearchShape, never here. Do not add an emission (D-06).
                state.appendHistoryKeywords([keyword])
                return .none

            case let .path(.element(id: _, action: .gallery(.comments(.delegate(.performedCommentAction(gid)))))):
                guard let id = state.path.galleryDetailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .gallery(.detail(.fetchGalleryDetail)))))

            case let .path(.element(id: _, action: .gallery(galleryAction))):
                guard let next = GalleryNavigation.nextScreen(for: galleryAction) else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(.gallery(next)),
                    screen: next,
                    embed: { .path(.element(id: $0, action: .gallery($1))) }
                )

            case .path:
                return .none

            case .setKeyword(let keyword):
                state.keyword = keyword
                return .none

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                // Presenting the sheet loads the persisted filters into it, replacing the form's
                // former `onAppear`. Every screen that presents Filters must send this.
                // Records that the filter panel was opened from the Search-root surface (D-14).
                return .merge(
                    .send(.destination(.presented(.filters(.fetchFilters)))),
                    .run(operation: { _ in analyticsClient.send(.filterPanelOpened(.searchRoot)) })
                )

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                // Records that the quick-search panel was opened from the Search-root surface (D-14).
                return .run(operation: { _ in analyticsClient.send(.quickSearchPanelOpened(.searchRoot)) })

            case .destination:
                return .none

            case .appendHistoryKeyword(let keyword):
                // Deliberately emits no analytics signal despite carrying the raw keyword: this is a
                // persistence action, and the keyword must not cross the analytics boundary in any
                // form other than the SearchShape already emitted at fetch completion (D-06). A later
                // reader must not add an emission here for completeness.
                state.appendHistoryKeywords([keyword])
                return .none

            case .removeHistoryKeyword(let keyword):
                state.removeHistoryKeyword(keyword)
                return .none

            case .fetchHistoryGalleries:
                // "Recently seen" suggestions: the 10 most-recent history entries, metadata
                // refetched on demand since no gallery snapshot is persisted.
                @Shared(.galleryHistory) var galleryHistory
                let pairs = galleryHistory.prefix(10).map({ (gid: $0.gid, token: $0.token) })
                guard !pairs.isEmpty else {
                    state.historyGalleries = []
                    return .none
                }
                // Skip when the shown suggestions already reflect the 10 most-recent gids — a plain pop
                // back to the Search root shouldn't re-download identical metadata. `cancelInFlight`
                // stops rapid re-entry from stacking overlapping, last-writer-wins requests.
                guard pairs.map(\.gid) != state.historyGalleries.map(\.gid) else { return .none }
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let galleries = try await GalleriesMetadataRequest(
                            host: host,
                            gidList: pairs
                        )
                        .response()
                        await send(.fetchHistoryGalleriesDone(.success(galleries)))
                    } catch {
                        await send(.fetchHistoryGalleriesDone(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.fetchHistoryGalleries, cancelInFlight: true)

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
