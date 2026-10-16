import AppComponents
import AppTools
import SwiftUI

/// Keeps page artwork fitted inside the same neutral tile in Detail and the full Previews grid.
struct PreviewThumbnail: View {
    @Environment(\.colorScheme) private var colorScheme
    let url: URL?

    var body: some View {
        Color(uiColor: colorScheme == .dark ? .systemGray5 : .secondarySystemBackground)
            .aspectRatio(Defaults.ImageSize.previewAspect, contentMode: .fit)
            .overlay {
                PreviewImageView(originalURL: url)
            }
            .clipShape(GalleryCover.clipShape)
    }
}
