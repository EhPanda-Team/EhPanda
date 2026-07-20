import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import FiltersFeature
import GalleryListComponents
import QuickSearchFeature
import SwiftUI
import TagTranslationFeature

struct DetailSearchView: View {
    @Bindable private var store: StoreOf<DetailSearchReducer>

    init(store: StoreOf<DetailSearchReducer>) {
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
            }
        )
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
        .navigationTitle(store.lastKeyword)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
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
    DetailSearchView(
        store: .init(
            initialState: {
                var state = DetailSearchReducer.State()
                state.galleries = Gallery.previews(count: 10)
                return state
            }(),
            reducer: DetailSearchReducer.init
        )
    )
}
