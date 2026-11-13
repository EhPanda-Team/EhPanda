public import AppModels
import AppTools
import SFSafeSymbols
public import SwiftUI

/// The filled heart a list row shows for a gallery in the user's favorites, in the colour of the slot it sits in
/// (the accent colour when the slot is unknown). Nothing is drawn for a gallery that is not a favorite.
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
                .foregroundStyle(Defaults.FavoriteColor.color(at: gallery.favoriteTagIndex) ?? Color.accentColor)
                .accessibilityLabel(.favorited)
        }
    }
}
