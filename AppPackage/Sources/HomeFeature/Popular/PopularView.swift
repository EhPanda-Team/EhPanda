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
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<PopularReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        GenericList(
            galleries: store.filteredGalleries,
            setting: setting, pageNumber: nil,
            loadingState: store.loadingState,
            footerLoadingState: .idle,
            fetchAction: { store.send(.fetchGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .sheet(
            item: $store.scope(state: \.destination?.filters, action: \.destination.filters)
        ) { store in
            FiltersView(store: store)
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
        }
        .searchable(text: $store.keyword, prompt: L10n.Localizable.Searchable.Prompt.filter)
        .onAppear {
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries)
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.PopularView.Title.popular)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton(hideText: true) {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

struct PopularView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PopularView(
                store: .init(initialState: .init(), reducer: PopularReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
