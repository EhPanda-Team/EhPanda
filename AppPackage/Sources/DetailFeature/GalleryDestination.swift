import SwiftUI
import AppModels
import TagTranslationFeature
import ComposableArchitecture

// Builds the view for a single gallery stack element. Shared by every gallery host (and reused by the
// nested `.gallery` case of Home's and SearchRoot's paths) so the screen wiring lives in one place.
@MainActor
@ViewBuilder
public func galleryDestination(
    _ store: StoreOf<GalleryPath>,
    user: User,
    setting: Binding<Setting>,
    blurRadius: Double,
    tagTranslator: TagTranslator
) -> some View {
    switch store.case {
    case .detail(let detailStore):
        DetailView(
            store: detailStore, gid: detailStore.gid, user: user,
            setting: setting, blurRadius: blurRadius, tagTranslator: tagTranslator
        )
    case .previews(let previewsStore):
        PreviewsView(
            store: previewsStore, gid: previewsStore.gid,
            setting: setting, blurRadius: blurRadius
        )
    case .comments(let commentsStore):
        CommentsView(
            store: commentsStore, gid: commentsStore.gid, token: commentsStore.token,
            apiKey: commentsStore.apiKey, galleryURL: commentsStore.galleryURL,
            comments: commentsStore.comments, user: user, setting: setting,
            blurRadius: blurRadius, tagTranslator: tagTranslator
        )
    case .detailSearch(let searchStore):
        DetailSearchView(
            store: searchStore, keyword: searchStore.keyword, user: user,
            setting: setting, blurRadius: blurRadius, tagTranslator: tagTranslator
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
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator
    private let root: Root

    public init(
        store: Store<HostState, HostAction>,
        state statePath: KeyPath<HostState, StackState<GalleryPath.State>>,
        action actionPath: CaseKeyPath<HostAction, StackActionOf<GalleryPath>>,
        user: User,
        setting: Binding<Setting>,
        blurRadius: Double,
        tagTranslator: TagTranslator,
        @ViewBuilder root: () -> Root
    ) {
        self.store = store
        self.statePath = statePath
        self.actionPath = actionPath
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
        self.root = root()
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: statePath, action: actionPath)) {
            root
        } destination: { elementStore in
            galleryDestination(
                elementStore, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
}
