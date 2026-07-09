import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import DateSeekFeature
import GalleryListComponents
import FiltersFeature
import QuickSearchFeature

struct WatchedView: View {
    @Bindable private var store: StoreOf<WatchedReducer>
    private let blurRadius: Double

    init(
        store: StoreOf<WatchedReducer>,
        blurRadius: Double
    ) {
        self.store = store
        self.blurRadius = blurRadius
    }

    var body: some View {
        ZStack {
            if CookieUtil.didLogin {
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
            item: $store.scope(state: \.destination?.filters, action: \.destination.filters)
        ) { store in
            FiltersView(store: store)
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
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
            if store.galleries.isEmpty && CookieUtil.didLogin {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries())
                }
            }
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

struct WatchedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WatchedView(
                store: .init(initialState: .init(), reducer: WatchedReducer.init),
                blurRadius: 0
            )
        }
    }
}
