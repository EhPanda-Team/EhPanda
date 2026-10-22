import AppComponents
public import AppModels
import AppTools
import PreviewSupport
public import SwiftUI

public struct GalleryRankingCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let showsRichInformation: Bool
    private let gallery: Gallery
    private let ranking: Int

    public init(gallery: Gallery, ranking: Int, showsRichInformation: Bool = false) {
        self.showsRichInformation = showsRichInformation
        self.gallery = gallery
        self.ranking = ranking
    }

    public var body: some View {
        rankAndText
    }

    /// The row sits in a column whose width is a fixed fraction of the screen, and both of the
    /// members it leads with — the cover and the rank number — are intrinsically sized and refuse
    /// to compress. At an accessibility size the text column left beside them is narrower than the
    /// text it has to hold. Keeping the cover and rank on a line of their own and
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
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cover: some View {
        GalleryCover(url: gallery.coverURL, style: showsRichInformation ? .homeRanking : .compact, contentMode: .fill)
    }

    private var rankNumber: some View {
        Text(String(ranking))
            .fontWeight(.medium)
            .font(.title2)
            .padding(.horizontal, showsRichInformation ? 4 : 16)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(gallery.title)
                .accessibilityIdentifier("home_ranking_title_\(gallery.id)")
                .bold()
                .lineLimit(textLineLimit(2))
                .fixedSize(horizontal: false, vertical: true)

            if showsRichInformation {
                Spacer(minLength: 8)
                Text(gallery.category.value)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                HomePageLanguage(gallery: gallery)
                Spacer(minLength: 8)
                HomeGalleryRating(rating: gallery.rating)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: showsRichInformation && !dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            alignment: .leading
        )
        .font(showsRichInformation ? .subheadline : .caption)
    }

    /// Above the default size, the title grows to retain every word. At and below the default
    /// size, it keeps its designed two-line budget.
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
