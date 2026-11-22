import AppComponents
public import ComposableArchitecture
import ReadingFeature
public import SwiftUI
import SystemNotification

extension View {
    /// Presents the reader a gallery list opened directly, and the toast for an open that failed.
    public func galleryReading(_ store: StoreOf<GalleryReadingFeature>) -> some View {
        modifier(GalleryReadingPresentation(store: store))
    }
}

private struct GalleryReadingPresentation: ViewModifier {
    @Bindable var store: StoreOf<GalleryReadingFeature>

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $store.scope(\.$reader, action: \.reader)) { store in
                ReadingView(store: store)
                    .privacyMask()
            }
            .toast($store.scope(\.$toast, action: \.toast))
    }
}
