import AnalyticsClient
import AppModels
public import ComposableArchitecture
public import DetailFeature

@Reducer
public struct HomeSheetFeature {
    @Reducer
    public enum RootFeature {
        case frontpage(FrontpageReducer)
        case popular(PopularReducer)
        case toplists(ToplistsReducer)
        case watched(WatchedReducer)
        case history(HistoryReducer)
        case gallery(GallerySheetFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var root: RootFeature.State
        public let side: HomePane
        @Presents public var gallery: GallerySheetFeature.State?

        public init(root: RootFeature.State, side: HomePane) {
            self.root = root
            self.side = side
        }

        public var readingFlushAction: Action? {
            if let action = gallery?.readingFlushAction {
                return .gallery(.presented(action))
            }
            if case .gallery(let root) = root, let action = root.readingFlushAction {
                return .root(.gallery(action))
            }
            return nil
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case root(RootFeature.Action)
        case gallery(PresentationAction<GallerySheetFeature.Action>)
    }

    @Dependency(\.analyticsClient) private var analyticsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(\.root, action: \.root) { RootFeature.body }
        Reduce { state, action in
            switch action {
            case .onPresented:
                switch state.root {
                case .frontpage:
                    return .send(.root(.frontpage(.onPresented)))
                case .popular:
                    return .send(.root(.popular(.onPresented)))
                case .toplists:
                    return .send(.root(.toplists(.onPresented)))
                case .watched:
                    return .send(.root(.watched(.onPresented)))
                case .history:
                    return .send(.root(.history(.onPresented)))
                case .gallery(let gallery):
                    return .merge(.send(.root(.gallery(.onPresented))), detailOpened(gallery.detail.gallery))
                }

            case .root(.frontpage(.delegate(.pushDetail(let gallery)))),
                 .root(.popular(.delegate(.pushDetail(let gallery)))),
                 .root(.toplists(.delegate(.pushDetail(let gallery)))),
                 .root(.watched(.delegate(.pushDetail(let gallery)))),
                 .root(.history(.delegate(.pushDetail(let gallery)))):
                guard state.gallery == nil else { return .none }
                state.gallery = .init(detail: .init(gallery: gallery))
                return .merge(.send(.gallery(.presented(.onPresented))), detailOpened(gallery))

            case .binding, .root, .gallery:
                return .none
            }
        }
        .ifLet(\.$gallery, action: \.gallery, destination: GallerySheetFeature.init)
    }

    private func detailOpened(_ gallery: Gallery) -> Effect<Action> {
        .run { [analyticsClient] _ in
            analyticsClient.send(.galleryDetailOpened(
                category: gallery.category,
                tagNamespaces: TagNamespaceCounts(tags: gallery.tags)
            ))
        }
    }
}

extension HomeSheetFeature.RootFeature.State: Equatable {}
