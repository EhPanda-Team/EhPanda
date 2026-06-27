import SwiftUI
import Resources
import ComposableArchitecture
import SwiftUINavigationExt

// MARK: NavigationLinks
extension DetailView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: $store.route, case: \.previews) { _ in
            PreviewsView(
                store: store.scope(state: \.previewsState, action: \.previews),
                gid: gid, setting: $setting, blurRadius: blurRadius
            )
        }
        NavigationLink(unwrapping: $store.route, case: \.comments) { route in
            if let commentStore = store.scope(state: \.commentsState.wrappedValue, action: \.comments) {
                CommentsView(
                    store: commentStore, gid: gid, token: store.gallery.token, apiKey: store.apiKey,
                    galleryURL: route.wrappedValue, comments: store.galleryComments, user: user,
                    setting: $setting, blurRadius: blurRadius,
                    tagTranslator: tagTranslator
                )
            }
        }
        NavigationLink(unwrapping: $store.route, case: \.detailSearch) { route in
            if let detailSearchStore = store.scope(state: \.detailSearchState.wrappedValue, action: \.detailSearch) {
                DetailSearchView(
                    store: detailSearchStore, keyword: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
        NavigationLink(unwrapping: $store.route, case: \.galleryInfos) { route in
            let (gallery, galleryDetail) = route.wrappedValue
            GalleryInfosView(
                store: store.scope(state: \.galleryInfosState, action: \.galleryInfos),
                gallery: gallery, galleryDetail: galleryDetail
            )
        }
    }
}

// MARK: ToolBar
extension DetailView {
    func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                Button {
                    if let galleryURL = store.gallery.galleryURL,
                       let archiveURL = store.galleryDetail?.archiveURL {
                        store.send(.setNavigation(.archives(galleryURL, archiveURL)))
                    }
                } label: {
                    Label(L10n.Localizable.DetailView.ToolbarItem.Button.archives, systemSymbol: .zipperPage)
                }
                .disabled(store.galleryDetail?.archiveURL == nil || !CookieUtil.didLogin)
                Button {
                    store.send(.setNavigation(.torrents()))
                } label: {
                    let base = L10n.Localizable.DetailView.ToolbarItem.Button.torrents
                    let torrentCount = store.galleryDetail?.torrentCount ?? 0
                    let baseWithCount = [base, "(\(torrentCount))"].joined(separator: " ")
                    Label(torrentCount > 0 ? baseWithCount : base, systemSymbol: .leaf)
                }
                .disabled((store.galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
                    if let galleryURL = store.gallery.galleryURL {
                        store.send(.setNavigation(.share(galleryURL)))
                    }
                } label: {
                    Label(L10n.Localizable.DetailView.ToolbarItem.Button.share, systemSymbol: .squareAndArrowUp)
                }
            }
            .disabled(store.galleryDetail == nil || store.loadingState == .loading)
        }
    }
}
