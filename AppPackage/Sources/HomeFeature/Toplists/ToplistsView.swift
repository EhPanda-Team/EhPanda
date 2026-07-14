import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppComponents
import GalleryListComponents

struct ToplistsView: View {
    @Bindable private var store: StoreOf<ToplistsReducer>

    init(store: StoreOf<ToplistsReducer>) {
        self.store = store
    }

    private var navigationTitle: String {
        [String(localized: .toplists), String(localized: store.type.value)].joined(separator: " - ")
    }

    var body: some View {
        GalleryList(
            galleries: store.filteredGalleries ?? [],
            pageNumber: store.pageNumber,
            loadingState: store.loadingState ?? .idle,
            footerLoadingState: store.footerLoadingState ?? .idle,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            }
        )
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .appAlert($store.scope(\.$alert, action: \.alert), text: $store.jumpPageIndex)
        .onAppear {
            if store.galleries?.isEmpty != false {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries())
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(navigationTitle)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(disabled: store.alert != nil) {
            ToplistsTypeMenu(type: store.type) { type in
                if type != store.type {
                    store.send(.setToplistsType(type))
                }
            }
            if store.setting.galleryHost == .ehentai {
                JumpPageButton(pageNumber: store.pageNumber ?? .init(), hideText: true) {
                    store.send(.presentJumpPageAlert)
                }
            }
        }
    }
}

struct ToplistsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ToplistsView(
                store: .init(initialState: .init(), reducer: ToplistsReducer.init)
            )
        }
    }
}
