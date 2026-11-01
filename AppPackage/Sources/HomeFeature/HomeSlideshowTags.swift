import AppComponents
import AppModels
import Sharing
import SwiftUI
import TagTranslationFeature

struct HomeSlideshowTags: View {
    @Environment(\.colorScheme) private var colorScheme
    @SharedReader(.setting) private var setting: Setting
    @SharedReader(.tagTranslator) private var tagTranslator: TagTranslator
    let gallery: Gallery

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            TagCloudView(data: gallery.homeSlideshowTags) { tag in
                let translation = tagTranslator.lookup(
                    word: tag.id, returnOriginal: !setting.translateTags
                ).translation
                TagCloudCell(
                    text: translation?.displayValue ?? tag.text, imageURL: nil, showsImages: false, font: .caption2,
                    padding: .init(top: 4, leading: 8, bottom: 4, trailing: 8),
                    textColor: colorScheme == .dark ? .primary : .secondary, backgroundColor: .clear
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
            }
        }
        .accessibilityIdentifier("home_slideshow_tags")
    }
}
