import AppComponents
import ComposableArchitecture
import DetailFeature
import SwiftUI

struct HomeSheetView: View {
    @Bindable var store: StoreOf<HomeSheetFeature>
    let viewport: CGSize
    let usesSplitLayout: Bool

    var body: some View {
        Group {
            switch store.scope(\.root, action: \.root).case {
            case .gallery(let store):
                GallerySheetView(store: store, showsCloseButton: true)
            case .frontpage(let store):
                NavigationStack { FrontpageView(store: store).toolbar { SheetCloseToolbar() } }
            case .popular(let store):
                NavigationStack { PopularView(store: store).toolbar { SheetCloseToolbar() } }
            case .toplists(let store):
                NavigationStack { ToplistsView(store: store).toolbar { SheetCloseToolbar() } }
            case .watched(let store):
                NavigationStack { WatchedView(store: store).toolbar { SheetCloseToolbar() } }
            case .history(let store):
                NavigationStack { HistoryView(store: store).toolbar { SheetCloseToolbar() } }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .privacyMask()
        .background {
            @UIBindable var presentationStore = store
            HomePaneSheet(
                item: $presentationStore.scope(\.$gallery, action: \.gallery),
                viewport: viewport,
                usesSplitLayout: usesSplitLayout,
                side: { _ in store.side.opposite }
            ) { galleryStore in
                GallerySheetView(store: galleryStore, showsCloseButton: true).privacyMask()
            }
        }
    }
}
