import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import GalleryListComponents
import FiltersFeature

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
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            }
        )
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).filters
        ) { store in
            FiltersView(store: store)
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
        .navigationTitle(.popular)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton(hideText: true) {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        PopularView(
            store: .init(initialState: .init(), reducer: PopularReducer.init)
        )
    }
}
