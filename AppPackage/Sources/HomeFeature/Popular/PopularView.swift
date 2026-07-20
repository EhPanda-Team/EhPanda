import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import FiltersFeature
import GalleryListComponents
import Resources
import SwiftUI
import TagTranslationFeature

struct PopularView: View {
    @Bindable private var store: StoreOf<PopularReducer>

    init(store: StoreOf<PopularReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            galleries: store.filteredGalleries,
            pageNumber: nil,
            loadingState: store.loadingState,
            footerLoadingState: .idle,
            fetchAction: { store.send(.fetchGalleries) },
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
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .toolbar(content: toolbar)
        .navigationTitle(.popular)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        PopularView(
            store: .init(
                initialState: {
                    var state = PopularReducer.State()
                    state.galleries = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: PopularReducer.init
            )
        )
    }
}
