import AppModels
import Sharing
import SwiftUI

/// The compact slideshow card: the cover with the title, the stats and the tags (the iPhone, and any window that is
/// not large).
///
/// The stats go beside the cover, in the text column, whenever the two-column grid fits there. When it does not, the
/// owner's C9 decision (19-23) puts them below the cover at the card's full width, one stat per line, so that no stat
/// label is ever broken mid-word. That is a choice about the whole card, so it is made here, with a `ViewThatFits`
/// over one `HomeCompactSlideshowLayout` of each arrangement, rather than inside the stats (a stat view cannot place
/// itself below its sibling cover). The layout reports the cover, its spacing and the narrowest the stats get as the
/// ideal width of the beside arrangement, so the title's one-line width plays no part in the choice.
struct HomeCompactSlideshowContent<Cover: View>: View {
    @SharedReader(.setting) private var setting: Setting
    let gallery: Gallery
    let cover: Cover

    init(gallery: Gallery, @ViewBuilder cover: () -> Cover) {
        self.gallery = gallery
        self.cover = cover()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            card(.beside)
            card(.below)
        }
    }

    private func card(_ arrangement: HomeCompactSlideshowLayout.Arrangement) -> some View {
        HomeCompactSlideshowLayout(arrangement: arrangement) {
            cover
            title
            HomeCompactSlideshowInformation(gallery: gallery, stacksStats: arrangement == .below)
            if !gallery.homeSlideshowTags.isEmpty {
                HomeCompactSlideshowTags(gallery: gallery)
            }
        }
    }

    private var title: some View {
        Text(gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle))
            .accessibilityIdentifier("home_slideshow_title_\(gallery.id)")
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// The tags, or nothing when the height they are proposed is less than they need. The layout proposes no height while
/// it measures and the room that is left when it places, so the tags that do not fit under the title and the stats in
/// the cover's height are dropped and never cut off.
private struct HomeCompactSlideshowTags: View {
    let gallery: Gallery

    var body: some View {
        ViewThatFits(in: .vertical) {
            HomeSlideshowTags(gallery: gallery)
            Color.clear.frame(width: 0, height: 0)
        }
    }
}
