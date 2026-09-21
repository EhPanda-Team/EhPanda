import AppComponents
import AppModels
import ComposableArchitecture
import GalleryListComponents
import Resources
import SwiftUI
import TagTranslationFeature

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
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            }
        )
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .appAlert($store.scope(\.$alert, action: \.alert), text: $store.jumpPageIndex)
        .toolbar(content: toolbar)
        .navigationTitle(navigationTitle)
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $store.type.sending(\.setToplistsType)) {
                    ForEach(ToplistsType.allCases) { type in
                        Text(type.value).tag(type)
                    }
                } label: {
                    Text(.toplistsType)
                }
                .pickerStyle(.inline)
            } label: {
                Label(.toplistsType, systemSymbol: .dialLow)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(store.alert != nil)
            if store.setting.galleryHost == .ehentai {
                JumpPageButton(pageNumber: store.pageNumber ?? .init()) {
                    store.send(.presentJumpPageAlert)
                }
                .disabled(store.alert != nil)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        ToplistsView(
            store: .init(
                initialState: {
                    var state = ToplistsReducer.State()
                    state.rawGalleries[state.type] = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: ToplistsReducer.init
            )
        )
    }
}
