import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt
import GalleryListComponents

struct HistoryView: View {
    @Bindable private var store: StoreOf<HistoryReducer>

    init(store: StoreOf<HistoryReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            galleries: store.filteredGalleries,
            pageNumber: PageNumber(isNextButtonEnabled: store.hasMoreHistory),
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            // A leading list section, rather than a pinned top banner, keeps the navigation title
            // intact: only the most-recent records survive the launch-time prune.
            notice: .historyLimitDescription(limit: GalleryHistoryEntry.historyCap),
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            },
            downloadBadges: store.downloadBadges
        )
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .toolbar(content: toolbar)
        .navigationTitle(.history)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                store.send(.clearHistoryButtonTapped)
            } label: {
                Label(.RLocalizable.clear, systemSymbol: .trashCircle)
            }
            .disabled(store.loadingState == .loading || store.galleryHistory.isEmpty)
            .confirmationDialog(
                $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
            )
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        HistoryView(
            store: .init(
                initialState: {
                    var state = HistoryReducer.State()
                    state.galleries = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: HistoryReducer.init
            )
        )
    }
}
