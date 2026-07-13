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
    private let blurRadius: Double

    init(
        store: StoreOf<FrontpageReducer>,
        blurRadius: Double
    ) {
        self.store = store
        self.blurRadius = blurRadius
    }

    var body: some View {
        GenericList(
            galleries: store.filteredGalleries,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            }
        )
        .sheet(
            item: $store.scope(\.$destination, action: \.destination).filters
        ) { store in
            FiltersView(store: store)
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
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
            FiltersButton(hideText: true) {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

struct FrontpageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FrontpageView(
                store: .init(initialState: .init(), reducer: FrontpageReducer.init),
                blurRadius: 0
            )
        }
    }
}
