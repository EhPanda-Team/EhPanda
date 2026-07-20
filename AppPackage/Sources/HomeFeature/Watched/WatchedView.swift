import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DateSeekFeature
import FiltersFeature
import GalleryListComponents
import QuickSearchFeature
import Resources
import SwiftUI
import TagTranslationFeature

struct WatchedView: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Bindable private var store: StoreOf<WatchedReducer>

    init(store: StoreOf<WatchedReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            galleries: store.galleries,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
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
                self.store.send(.fetchGalleries(keyword))
            }
            .privacyMask()
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).filters
        ) { store in
            FiltersView(store: store)
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
        .navigationTitle(.watched)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                    store.send(.dateSeekButtonTapped(navigation))
                }
                FiltersButton {
                    store.send(.filtersButtonTapped)
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
        NavigationStack {
            WatchedView(
                store: .init(
                    initialState: {
                        var state = WatchedReducer.State()
                        state.galleries = Gallery.previews(count: 10)
                        return state
                    }(),
                    reducer: WatchedReducer.init
                )
            )
        }
    }
}
