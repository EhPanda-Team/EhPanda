import AppComponents
import AppModels
import AppTools
import PreviewSupport
import SwiftUI

public struct GalleryRankingCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let gallery: Gallery
    private let ranking: Int

    public init(gallery: Gallery, ranking: Int) {
        self.gallery = gallery
        self.ranking = ranking
    }

    public var body: some View {
        rankAndText
    }

    /// The row sits in a column whose width is a fixed fraction of the screen, and both of the
    /// members it leads with — the cover and the rank number — are intrinsically sized and refuse
    /// to compress. At an accessibility size the text column left beside them is narrower than the
    /// text it has to hold, which is what used to eat the title's tail and then remove the
    /// uploader from the row entirely. Keeping the two identifiers on a line of their own and
    /// handing the text the column's whole width beneath them gives it the only width there is to
    /// give; the row's height was never bounded, so it simply grows to hold what it now shows.
    ///
    /// The arrangement is chosen by an explicit size read rather than by `ViewThatFits`, because
    /// the title wraps: its *ideal* width is its full single-line width, so every candidate holding
    /// it measures as not fitting and the stacked one would win at every size, the default
    /// included.
    @ContentBuilder private var rankAndText: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    cover
                    rankNumber
                }
                textColumn
            }
        } else {
            HStack(alignment: .top) {
                cover
                rankNumber
                textColumn
            }
        }
    }

    private var cover: some View {
        GalleryCover(url: gallery.coverURL, style: .compact)
    }

    private var rankNumber: some View {
        Text(String(ranking))
            .fontWeight(.medium)
            .font(.title2)
            .padding(.horizontal)
    }

    private var textColumn: some View {
        VStack(alignment: .leading) {
            Text(gallery.trimmedTitle)
                .bold()
                .lineLimit(textLineLimit(2))
                .fixedSize(horizontal: false, vertical: true)

            gallery.uploader.map(Text.init)?
                .foregroundStyle(.secondary)
                .lineLimit(textLineLimit(1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.caption)
    }

    /// The title and the uploader are user-authored text, so above the default size they carry no
    /// cap at all: a long title keeps every word and a long uploader every character, and the row
    /// grows to hold them instead of surrendering a tail one size step at a time. At and below the
    /// default size each keeps its designed budget verbatim — two lines for the title, one for the
    /// uploader — which is what default-size appearance parity requires.
    private func textLineLimit(_ budget: Int) -> Int? {
        dynamicTypeSize <= .large ? budget : nil
    }
}

private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"

private extension Gallery {
    static func previewFixture(identity: Int, title: String, uploader: String?) -> Gallery {
        .init(
            gid: PreviewIdentifiers[identity].uuidString,
            token: "",
            title: title,
            rating: 3.5,
            tags: [],
            category: .doujinshi,
            uploader: uploader,
            pageCount: 24,
            postedDate: .now,
            coverURL: nil,
            galleryURL: nil
        )
    }
}

#Preview("Top rank", traits: .sizeThatFitsLayout) {
    GalleryRankingCell(gallery: .preview, ranking: 1)
}

#Preview("Long title, high rank", traits: .sizeThatFitsLayout) {
    GalleryRankingCell(
        gallery: .previewFixture(identity: 0, title: previewLongTitle, uploader: "Anonymous"), ranking: 999
    )
}

#Preview("Short title, no uploader", traits: .sizeThatFitsLayout) {
    GalleryRankingCell(gallery: .previewFixture(identity: 1, title: "Doujin", uploader: nil), ranking: 10)
}

// The Toplists column is 70% of a compact screen's width, so the stacked arrangement is previewed
// against the width it actually gets (0.7 of a 390-point screen).
#Preview("Long title, accessibility size", traits: .sizeThatFitsLayout) {
    GalleryRankingCell(
        gallery: .previewFixture(identity: 2, title: previewLongTitle, uploader: "AnonymousUploader"), ranking: 12
    )
    .frame(width: 273)
    .environment(\.dynamicTypeSize, .accessibility5)
}
