import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import DetailFeature
import GalleryListComponents
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI
import TagTranslationFeature

struct HistoryView: View {
    @Bindable private var store: StoreOf<HistoryReducer>

    init(store: StoreOf<HistoryReducer>) {
        self.store = store
    }

    var body: some View {
        GalleryList(
            displayMode: store.setting.galleryListPresentation[.history],
            galleries: store.filteredGalleries,
            // History pages through the device's own list, so its cursor is the index of the next entry to fetch.
            pageNumber: PageNumber(nextCursor: store.hasMoreHistory ? String(store.fetchedCount) : nil),
            loadingState: store.reading.isOpening ? .loading : store.loadingState,
            footerLoadingState: store.footerLoadingState,
            // A leading list section, rather than a pinned top banner, keeps the navigation title
            // intact: only the most-recent records survive the launch-time prune.
            notice: .historyLimitDescription(limit: GalleryHistoryEntry.historyCap),
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.delegate(.pushDetail($0))) },
            readAction: { store.send(.reading(.open($0))) },
            translateAction: {
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
            },
            downloadBadges: store.downloadBadges
        )
        .galleryReading(store.scope(\.reading, action: \.reading))
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .filter)
        .toolbar(content: toolbar)
        .navigationTitle(.history)
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            GalleryLayoutPicker(scope: .history)
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
