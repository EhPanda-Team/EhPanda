import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import GalleryListComponents

struct ToplistsView: View {
    @Bindable private var store: StoreOf<ToplistsReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<ToplistsReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        [L10n.Localizable.ToplistsView.toplists, store.type.value].joined(separator: " - ")
    }

    var body: some View {
        GenericList(
            galleries: store.filteredGalleries ?? [],
            setting: setting,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState ?? .idle,
            footerLoadingState: store.footerLoadingState ?? .idle,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .searchable(text: $store.keyword, prompt: L10n.Localizable.Searchable.filter)
        .appAlert($store.scope(state: \.alert, action: \.alert), text: $store.jumpPageIndex)
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
            if AppUtil.galleryHost == .ehentai {
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
                store: .init(initialState: .init(), reducer: ToplistsReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
