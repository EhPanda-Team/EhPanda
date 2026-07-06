import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import GalleryListComponents

struct HistoryView: View {
    @Bindable private var store: StoreOf<HistoryReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<HistoryReducer>,
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
            setting: setting,
            pageNumber: PageNumber(isNextButtonEnabled: store.hasMoreHistory),
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            },
            downloadBadges: store.downloadBadges
        )
        .safeAreaInset(edge: .top, spacing: 0) { historyLimitBanner }
        .searchable(text: $store.keyword, prompt: .filter)
        .onAppear {
            store.send(.onAppear)
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries)
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle(.history)
    }

    // Always-visible notice: only the most-recent records survive the launch-time prune.
    private var historyLimitBanner: some View {
        Text(.historyLimitDescription(limit: GalleryHistoryEntry.historyCap))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                store.send(.clearHistoryButtonTapped)
            } label: {
                Image(systemSymbol: .trashCircle)
            }
            .disabled(store.loadingState == .loading || store.galleryHistory.isEmpty)
            .confirmationDialog(
                $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
            )
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HistoryView(
                store: .init(initialState: .init(), reducer: HistoryReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
