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

struct FrontpageView: View {
    @Bindable private var store: StoreOf<FrontpageReducer>

    init(store: StoreOf<FrontpageReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            galleries: store.filteredGalleries,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            }
        )
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
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .onAppear {
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries)
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(.frontpage)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                store.send(.dateSeekButtonTapped(navigation))
            }
            FiltersButton {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        FrontpageView(
            store: .init(
                initialState: {
                    var state = FrontpageReducer.State()
                    state.galleries = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: FrontpageReducer.init
            )
        )
    }
}
