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
            displayMode: store.setting.galleryListPresentation[.search],
            galleries: store.galleries,
            pageNumber: store.pageNumber,
            loadingState: store.reading.isOpening ? .loading : store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            readAction: { store.send(.reading(.open($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            }
        )
        .galleryReading(store.scope(\.reading, action: \.reading))
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
            item: $store.scope(\.$destination, action: \.destination).newSavedSearch
        ) { store in
            NewSavedSearchView(store: store)
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
        ToolbarOverflowMenu {
            GalleryLayoutPicker(scope: .search)
            FiltersButton {
                store.send(.filtersButtonTapped)
            }
            QuickSearchButton {
                store.send(.quickSearchButtonTapped)
            }
            SaveSearchButton {
                store.send(.saveSearchButtonTapped)
            }
            .disabled(!store.canSaveSearch)
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
