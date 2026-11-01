import AppComponents
import AppModels
import SwiftUI

struct HomeSlideshowTags: View {
    @Environment(\.colorScheme) private var colorScheme
    let gallery: Gallery

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            TagCloudView(data: gallery.homeSlideshowTags) { tag in
                TagCloudCell(
                    text: tag.text, imageURL: nil, showsImages: false, font: .caption2,
                    padding: .init(top: 4, leading: 8, bottom: 4, trailing: 8),
                    textColor: colorScheme == .dark ? .primary : .secondary, backgroundColor: .clear
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
            }
        }
        .accessibilityIdentifier("home_slideshow_tags")
    }
}
