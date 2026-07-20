import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import CookieClient
import DateSeekFeature
import GalleryListComponents
import QuickSearchFeature
import DetailFeature

public struct FavoritesView: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Bindable private var store: StoreOf<FavoritesReducer>

    public init(store: StoreOf<FavoritesReducer>) {
        self.store = store
    }

    private var navigationTitle: String {
        let favoriteCategory = store.user.getFavoriteCategory(index: store.index)
        return (store.index == -1 ? String(localized: .RLocalizable.favorites) : favoriteCategory)
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path
        ) {
            GalleryList(
                galleries: store.galleries ?? [],
                pageNumber: store.pageNumber,
                loadingState: store.loadingState ?? .idle,
                footerLoadingState: store.footerLoadingState ?? .idle,
                fetchAction: { store.send(.fetchGalleries()) },
                fetchMoreAction: { store.send(.fetchMoreGalleries) },
                navigateAction: { store.send(.galleryTapped($0)) },
                translateAction: {
                    store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
                },
                downloadBadges: store.downloadBadges
            )
            .animation(.default) {
                $0.opacity(didLogin ? 1 : 0)
            }
            .overlay {
                NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                    .animation(.default) {
                        $0.opacity(didLogin ? 0 : 1)
                    }
            }
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).quickSearch
            ) { store in
                QuickSearchView(store: store) { keyword in
                    self.store.send(.destination(.dismiss))
                    self.store.send(.fetchGalleries(keyword: keyword))
                }
                .privacyMask()
            }
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).dateSeek
            ) { store in
                @Bindable var store = store
                DateSeekPickerView(
                    selectedDate: $store.date,
                    navigation: store.navigation,
                    seekAction: { store.send(.performSeek($0)) }
                )
                .privacyMask()
            }
            .searchable(text: $store.keyword, placement: .navigationBarDrawer)
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: store.tagTranslator.translations,
                    showsImages: store.setting.showImagesInTags, isEnabled: store.setting.showTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.fetchGalleries())
            }
            .onAppear {
                store.send(.onAppear)
                if store.galleries?.isEmpty != false && didLogin {
                    DispatchQueue.main.async {
                        store.send(.fetchGalleries())
                    }
                }
            }
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FavoritesIndexMenu(index: store.index) { index in
                if index != store.index {
                    store.send(.setFavoritesIndex(index))
                }
            }
            SortOrderMenu(sortOrder: store.sortOrder) { order in
                if store.sortOrder != order {
                    store.send(.fetchGalleries(sortOrder: order))
                }
            }
            ToolbarFeaturesMenu {
                DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                    store.send(.dateSeekButtonTapped(navigation))
                }
                QuickSearchButton {
                    store.send(.quickSearchButtonTapped)
                }
            }
        }
    }
}

#Preview("Initial") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        FavoritesView(
            store: .init(
                initialState: {
                    var state = FavoritesReducer.State()
                    state.rawGalleries[state.index] = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: FavoritesReducer.init
            )
        )
    }
}
