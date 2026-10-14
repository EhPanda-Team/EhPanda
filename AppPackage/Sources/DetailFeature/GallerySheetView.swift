import AppComponents
import ComposableArchitecture
import SwiftUI

public struct GallerySheetView: View {
    @Bindable private var store: StoreOf<GallerySheetFeature>
    private let showsCloseButton: Bool

    public init(store: StoreOf<GallerySheetFeature>, showsCloseButton: Bool = false) {
        self.store = store
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            DetailView(store: store.scope(\.detail, action: \.detail), gid: store.detail.gid)
                .toolbar {
                    if showsCloseButton { SheetCloseToolbar() }
                }
        } destination: { store in
            galleryDestination(store)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
