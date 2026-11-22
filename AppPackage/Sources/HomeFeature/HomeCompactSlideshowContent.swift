import AppModels
import AutomationIdentifiers
import Sharing
import SwiftUI

/// Tags are optional; measuring the complete title prevents them from causing truncation.
struct HomeCompactSlideshowContent: View {
    @SharedReader(.setting) private var setting: Setting
    let gallery: Gallery

    var body: some View {
        ViewThatFits(in: .vertical) {
            if !gallery.homeSlideshowTags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    title.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HomeCompactSlideshowInformation(gallery: gallery)
                        .fixedSize(horizontal: false, vertical: true)
                    HomeSlideshowTags(gallery: gallery)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                title.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HomeCompactSlideshowInformation(gallery: gallery)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var title: some View {
        Text(gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle))
            .accessibilityIdentifier(AccessibilityIdentifiers.homeSlideshowTitle(id: gallery.id))
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
