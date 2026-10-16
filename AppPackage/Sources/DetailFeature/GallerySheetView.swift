import AppComponents
public import ComposableArchitecture
public import SwiftUI

public struct GallerySheetView: View {
    @Bindable private var store: StoreOf<GallerySheetFeature>
    private let showsCloseButton: Bool
    private let closeAction: (() -> Void)?

    public init(
        store: StoreOf<GallerySheetFeature>, showsCloseButton: Bool = false,
        closeAction: (() -> Void)? = nil
    ) {
        self.store = store
        self.showsCloseButton = showsCloseButton
        self.closeAction = closeAction
    }

    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            DetailView(store: store.scope(\.detail, action: \.detail), gid: store.detail.gid)
                .toolbar {
                    if showsCloseButton { SheetCloseToolbar(action: closeAction) }
                }
        } destination: { store in
            galleryDestination(store)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
