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
    private let blurRadius: Double

    init(
        store: StoreOf<HistoryReducer>,
        blurRadius: Double
    ) {
        self.store = store
        self.blurRadius = blurRadius
    }

    var body: some View {
        GenericList(
            galleries: store.filteredGalleries,
            setting: store.setting,
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
                store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translatesTags)
            },
            downloadBadges: store.downloadBadges
        )
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
                blurRadius: 0
            )
        }
    }
}
