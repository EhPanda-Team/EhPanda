import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import DateSeekFeature
import FiltersFeature
import GalleryListComponents
import Resources
import SwiftUI
import TagTranslationFeature

struct FrontPageView: View {
    @AccessibilityFocusState private var focusedGalleryID: String?
    @Bindable private var store: StoreOf<FrontPageReducer>

    init(store: StoreOf<FrontPageReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            displayMode: store.setting.galleryListPresentation[.frontPage],
            galleries: store.filteredGalleries,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            },
            galleryFocus: $focusedGalleryID
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
        .onChange(of: store.galleries.isEmpty) { oldEmpty, newEmpty in
            guard oldEmpty, !newEmpty, let firstGallery = store.filteredGalleries.first else { return }
            focusedGalleryID = firstGallery.id
        }
        .toolbar(content: toolbar)
        .navigationTitle(.frontPage)
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            GalleryLayoutPicker(scope: .frontPage)
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
        FrontPageView(
            store: .init(
                initialState: {
                    var state = FrontPageReducer.State()
                    state.galleries = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: FrontPageReducer.init
            )
        )
    }
}
