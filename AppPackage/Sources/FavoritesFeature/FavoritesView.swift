import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DateSeekFeature
import DetailFeature
import GalleryListComponents
import QuickSearchFeature
import Resources
import SwiftUI
import TagTranslationFeature

public struct FavoritesView: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Bindable private var store: StoreOf<FavoritesReducer>

    public init(store: StoreOf<FavoritesReducer>) {
        self.store = store
    }

    private var navigationTitle: String {
        let favoriteCategory = store.user.getFavoriteCategory(index: store.favoritesIndex)
        return (store.favoritesIndex == -1 ? String(localized: .RLocalizable.favorites) : favoriteCategory)
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path
        ) {
            content
            .animation(.default, value: didLogin)
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
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    @ViewBuilder private var content: some View {
        if didLogin {
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
            .transition(.opacity)
        } else {
            NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                .transition(.opacity)
        }
    }

    @ToolbarContentBuilder private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $store.favoritesIndex.sending(\.setFavoritesIndex)) {
                    ForEach(-1..<10) { index in
                        Text(store.user.getFavoriteCategory(index: index)).tag(index)
                    }
                } label: {
                    Text(.RLocalizable.favorites)
                }
                .pickerStyle(.inline)
            } label: {
                Label(.RLocalizable.favorites, systemSymbol: .dialLow)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $store.sortOrder.sending(\.selectSortOrder)) {
                    ForEach(FavoritesSortOrder.allCases) { order in
                        Text(order.value).tag(Optional(order))
                    }
                } label: {
                    Text(.sortOrder)
                }
                .pickerStyle(.inline)
            } label: {
                Label(.sortOrder, systemSymbol: .arrowUpArrowDownCircle)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
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
                    state.rawGalleries[state.favoritesIndex] = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: FavoritesReducer.init
            )
        )
    }
}
