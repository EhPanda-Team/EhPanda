import SwiftUI
import AppModels
import TagTranslationFeature
import ComposableArchitecture
import AppTools
import AppComponents
import DateSeekFeature
import GalleryListComponents
import FiltersFeature
import QuickSearchFeature

struct SearchView: View {
    @Bindable private var store: StoreOf<SearchReducer>
    private let blurRadius: Double

    init(
        store: StoreOf<SearchReducer>,
        blurRadius: Double
    ) {
        self.store = store
        self.blurRadius = blurRadius
    }

    var body: some View {
        GenericList(
            galleries: store.galleries,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            },
            downloadBadges: store.downloadBadges
        )
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).quickSearch
        ) { store in
            QuickSearchView(store: store) { keyword in
                self.store.send(.destination(.dismiss))
                self.store.send(.fetchGalleries(keyword))
            }
            .accentColor(self.store.setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).filters
        ) { store in
            FiltersView(store: store)
                .accentColor(self.store.setting.accentColor).autoBlur(radius: blurRadius)
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
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries())
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(store.lastKeyword)
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

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(initialState: .init(), reducer: SearchReducer.init),
            blurRadius: 0
        )
    }
}
