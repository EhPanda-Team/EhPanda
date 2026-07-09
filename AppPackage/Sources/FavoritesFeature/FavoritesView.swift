import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import DateSeekFeature
import GalleryListComponents
import QuickSearchFeature
import DetailFeature

public struct FavoritesView: View {
    @Bindable private var store: StoreOf<FavoritesReducer>
    private let blurRadius: Double

    public init(
        store: StoreOf<FavoritesReducer>,
        blurRadius: Double
    ) {
        self.store = store
        self.blurRadius = blurRadius
    }

    private var navigationTitle: String {
        let favoriteCategory = store.user.getFavoriteCategory(index: store.index)
        return (store.index == -1 ? String(localized: .RLocalizable.favorites) : favoriteCategory)
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path,
            blurRadius: blurRadius
        ) {
            ZStack {
                if CookieUtil.didLogin {
                    GenericList(
                        galleries: store.galleries ?? [],
                        pageNumber: store.pageNumber,
                        loadingState: store.loadingState ?? .idle,
                        footerLoadingState: store.footerLoadingState ?? .idle,
                        fetchAction: { store.send(.fetchGalleries()) },
                        fetchMoreAction: { store.send(.fetchMoreGalleries) },
                        navigateAction: { store.send(.galleryTapped($0)) },
                        translateAction: {
                            store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
                        },
                        downloadBadges: store.downloadBadges
                    )
                } else {
                    NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                }
            }
            .sheet(
                item: $store.scope(state: \.destination?.quickSearch, action: \.destination.quickSearch)
            ) { store in
                QuickSearchView(store: store) { keyword in
                    self.store.send(.destination(.dismiss))
                    self.store.send(.fetchGalleries(keyword))
                }
                .accentColor(self.store.setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(
                item: $store.scope(state: \.destination?.dateSeek, action: \.destination.dateSeek)
            ) { store in
                @Bindable var store = store
                DateSeekPickerView(
                    selectedDate: $store.date,
                    navigation: store.navigation,
                    seekAction: { store.send(.performSeek($0)) }
                )
                .accentColor(self.store.setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .searchable(text: $store.keyword)
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: store.tagTranslator.translations,
                    showsImages: store.setting.showsImagesInTags, isEnabled: store.setting.showsTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.fetchGalleries())
            }
            .onAppear {
                store.send(.onAppear)
                if store.galleries?.isEmpty != false && CookieUtil.didLogin {
                    DispatchQueue.main.async {
                        store.send(.fetchGalleries())
                    }
                }
            }
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            FavoritesIndexMenu(index: store.index) { index in
                if index != store.index {
                    store.send(.setFavoritesIndex(index))
                }
            }
            SortOrderMenu(sortOrder: store.sortOrder) { order in
                if store.sortOrder != order {
                    store.send(.fetchGalleries(nil, order))
                }
            }
            DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                store.send(.dateSeekButtonTapped(navigation))
            }
            QuickSearchButton(hideText: true) {
                store.send(.quickSearchButtonTapped)
            }
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(
            store: .init(initialState: .init(), reducer: FavoritesReducer.init),
            blurRadius: 0
        )
    }
}
