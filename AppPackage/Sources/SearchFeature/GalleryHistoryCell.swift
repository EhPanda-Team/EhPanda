import AppComponents
import AppModels
import AppTools
import PreviewSupport
import SwiftUI

public struct GalleryHistoryCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let gallery: Gallery

    public init(gallery: Gallery) {
        self.gallery = gallery
    }

    /// The cell accepts the history row's tallest ideal height so every card shares one top and
    /// bottom edge without measuring or fixing the row height.
    ///
    /// The cover is pinned to the top for the same reason. At the default size it is exactly as
    /// tall as the text column beside it, so the alignment cannot be seen; once the text column is
    /// several times taller, a centred cover floats away from the title it belongs to.
    public var body: some View {
        HStack(alignment: .top, spacing: 20) {
            GalleryCover(url: gallery.coverURL, style: .compact)

            VStack(alignment: .leading) {
                Text(gallery.trimmedTitle)
                    .bold()
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                gallery.uploader.map(Text.init)?
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                RatingView(rating: gallery.rating)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .font(.caption)
        }
        .frame(width: cellWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Unlike the home carousel's card, this cell is free to get wider: it sits in a plain
    /// horizontal strip with no paging geometry keyed to its width. Widening is the cheapest fix
    /// available here, because it feeds both the title's characters-per-line *and* the rating row,
    /// whose five symbols grow with the text and refuse to compress — it was the rating, not the
    /// title, that first made the cell's content wider than its frame. The top step stops short of
    /// a compact screen's width so the cell still reads as a card in a strip rather than a page.
    private var cellWidth: CGFloat {
        let base = Defaults.ImageSize.rowW * 3
        return switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: base
        case .xLarge, .xxLarge, .xxxLarge: base * 7 / 6
        case .accessibility1, .accessibility2: base * 4 / 3
        case .accessibility3, .accessibility4, .accessibility5: base * 17 / 12
        @unknown default: base
        }
    }

}

private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"

private extension Gallery {
    static func previewFixture(identity: Int, title: String, rating: Float, uploader: String?) -> Gallery {
        .init(
            gid: PreviewIdentifiers[identity].uuidString,
            token: "",
            title: title,
            rating: rating,
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

#Preview("Loaded", traits: .sizeThatFitsLayout) {
    GalleryHistoryCell(gallery: .preview)
}

#Preview("Max rating, long title", traits: .sizeThatFitsLayout) {
    GalleryHistoryCell(
        gallery: .previewFixture(identity: 0, title: previewLongTitle, rating: 5, uploader: "Anonymous")
    )
}

#Preview("Min rating, short title", traits: .sizeThatFitsLayout) {
    GalleryHistoryCell(gallery: .previewFixture(identity: 1, title: "Doujin", rating: 0, uploader: nil))
}

#Preview("Long title, accessibility size", traits: .sizeThatFitsLayout) {
    GalleryHistoryCell(
        gallery: .previewFixture(identity: 2, title: previewLongTitle, rating: 4.5, uploader: "Anonymous")
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}
