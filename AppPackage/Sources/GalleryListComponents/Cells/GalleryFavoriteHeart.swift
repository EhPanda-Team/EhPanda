public import AppModels
import SFSafeSymbols
public import SwiftUI

/// The filled heart a list row or grid cell shows for a gallery in the user's favorites, in the secondary colour of
/// the page count beside it: it says only that the gallery is a favorite. The slot's colour stays on the detail
/// page's favorite button (design decision, 2026-11-21). Nothing is drawn for a gallery that is not a favorite.
///
/// The heart has no font of its own: each cell gives it the `.footnote` of the line it sits on.
///
/// The heart carries the favorited state to VoiceOver, so it is a labelled element rather than decoration.
public struct GalleryFavoriteHeart: View {
    private let gallery: Gallery

    public init(gallery: Gallery) {
        self.gallery = gallery
    }

    public var body: some View {
        if gallery.isFavorite {
            Image(systemSymbol: .heartFill)
                .foregroundStyle(.secondary)
                .accessibilityLabel(.favorited)
        }
    }
}
