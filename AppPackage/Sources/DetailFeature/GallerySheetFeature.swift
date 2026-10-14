import ComposableArchitecture

/// A modal gallery owns the detail root and every subsequent gallery drill-down.
@Reducer
public struct GallerySheetFeature {
    @ObservableState
    public struct State: Equatable {
        public var detail: DetailReducer.State
        public var path = StackState<GalleryPath.State>()

        public init(detail: DetailReducer.State) {
            self.detail = detail
        }

        public var readingFlushAction: Action? {
            if let (id, action) = path.topReadingFlush {
                return .path(.element(id: id, action: action))
            }
            guard path.isEmpty, detail.destination?.reading != nil else { return nil }
            return .detail(.destination(.presented(.reading(.flushReadingProgress))))
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case detail(DetailReducer.Action)
        case path(StackActionOf<GalleryPath>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(\.detail, action: \.detail, DetailReducer.init)
        Reduce { state, action in
            switch action {
            case .onPresented:
                return .send(.detail(.onPresented))

            case let .detail(.delegate(delegate)):
                guard let next = GalleryNavigation.nextScreen(for: .detail(.delegate(delegate)))
                else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(next),
                    screen: next,
                    embed: { .path(.element(id: $0, action: $1)) }
                )

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
                if state.detail.gid == gid {
                    return .send(.detail(.fetchGalleryDetail))
                }
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(.fetchGalleryDetail))))

            case let .path(.element(id: _, action: elementAction)):
                guard let next = GalleryNavigation.nextScreen(for: elementAction) else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(next),
                    screen: next,
                    embed: { .path(.element(id: $0, action: $1)) }
                )

            case .binding, .detail, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
