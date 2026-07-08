import SwiftUI
import AppModels
import ComposableArchitecture

// Builds the view for a single gallery stack element. Shared by every gallery host (and reused by the
// nested `.gallery` case of Home's and SearchRoot's paths) so the screen wiring lives in one place.
@MainActor
@ViewBuilder
public func galleryDestination(
    _ store: StoreOf<GalleryPath>,
    blurRadius: Double
) -> some View {
    switch store.case {
    case .detail(let detailStore):
        DetailView(
            store: detailStore, gid: detailStore.gid,
            blurRadius: blurRadius
        )
    case .previews(let previewsStore):
        PreviewsView(
            store: previewsStore, gid: previewsStore.gid,
            blurRadius: blurRadius
        )
    case .comments(let commentsStore):
        CommentsView(
            store: commentsStore, gid: commentsStore.gid, token: commentsStore.token,
            apiKey: commentsStore.apiKey, galleryURL: commentsStore.galleryURL,
            comments: commentsStore.comments,
            blurRadius: blurRadius
        )
    case .detailSearch(let searchStore):
        DetailSearchView(
            store: searchStore, keyword: searchStore.keyword,
            blurRadius: blurRadius
        )
    case .galleryInfos(let infosStore):
        GalleryInfosView(
            store: infosStore, gallery: infosStore.gallery, galleryDetail: infosStore.galleryDetail
        )
    }
}

// A `NavigationStack` whose drill-down is the shared `GalleryPath`. Hosts that stack only gallery
// screens (Favorites, Downloads, deep-link detail) build their root list here; the iPhone/iPad
// navigation container decision is centralized in this one type.
public struct GalleryNavigationContainer<HostState: ObservableState, HostAction, Root: View>: View {
    @Bindable private var store: Store<HostState, HostAction>
    private let statePath: KeyPath<HostState, StackState<GalleryPath.State>>
    private let actionPath: CaseKeyPath<HostAction, StackActionOf<GalleryPath>>
    private let blurRadius: Double
    private let root: Root

    public init(
        store: Store<HostState, HostAction>,
        state statePath: KeyPath<HostState, StackState<GalleryPath.State>>,
        action actionPath: CaseKeyPath<HostAction, StackActionOf<GalleryPath>>,
        blurRadius: Double,
        @ViewBuilder root: () -> Root
    ) {
        self.store = store
        self.statePath = statePath
        self.actionPath = actionPath
        self.blurRadius = blurRadius
        self.root = root()
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: statePath, action: actionPath)) {
            root
        } destination: { elementStore in
            galleryDestination(
                elementStore, blurRadius: blurRadius
            )
        }
    }
}
