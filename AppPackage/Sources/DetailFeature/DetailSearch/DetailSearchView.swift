import SwiftUI
import AppModels
import TagTranslationFeature
import ComposableArchitecture
import AppTools
import AppComponents
import GalleryListComponents
import FiltersFeature
import QuickSearchFeature

struct DetailSearchView: View {
    @Bindable private var store: StoreOf<DetailSearchReducer>
    private let keyword: String

    init(
        store: StoreOf<DetailSearchReducer>,
        keyword: String
    ) {
        self.store = store
        self.keyword = keyword
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
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            }
        )
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).quickSearch
        ) { store in
            QuickSearchView(store: store) { keyword in
                self.store.send(.destination(.dismiss))
                self.store.send(.fetchGalleries(keyword))
            }
            .accentColor(self.store.setting.accentColor)
            .privacyMask()
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).filters
        ) { store in
            FiltersView(store: store)
                .accentColor(self.store.setting.accentColor).privacyMask()
        }
        .searchable(text: $store.keyword, placement: .navigationBarDrawer)
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
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries(keyword))
                }
            }
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

struct DetailSearchView_Previews: PreviewProvider {
    static var previews: some View {
        DetailSearchView(
            store: .init(initialState: .init(), reducer: DetailSearchReducer.init),
            keyword: .init()
        )
    }
}
