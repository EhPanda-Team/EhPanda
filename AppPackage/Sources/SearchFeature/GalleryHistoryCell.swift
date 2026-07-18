import AppTools
import SwiftUI
import AppModels
import AppComponents
import Kingfisher

public struct GalleryHistoryCell: View {
    private let gallery: Gallery

    public init(gallery: Gallery) {
        self.gallery = gallery
    }

    public var body: some View {
        HStack(spacing: 20) {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .defaultModifier()
                .scaledToFill()
                .frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75)
                .clipShape(.rect(cornerRadius: 2))

            VStack(alignment: .leading) {
                Text(gallery.trimmedTitle)
                    .bold()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                gallery.uploader.map(Text.init)?
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                RatingView(rating: gallery.rating)
                    .foregroundStyle(.primary)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption)
        }
        .frame(width: Defaults.ImageSize.rowW * 3, height: Defaults.ImageSize.rowH * 0.75)
    }
}

private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"

private extension Gallery {
    static func previewFixture(title: String, rating: Float, uploader: String?) -> Gallery {
        .init(
            gid: UUID().uuidString,
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
    GalleryHistoryCell(gallery: .previewFixture(title: previewLongTitle, rating: 5, uploader: "Anonymous"))
}

#Preview("Min rating, short title", traits: .sizeThatFitsLayout) {
    GalleryHistoryCell(gallery: .previewFixture(title: "Doujin", rating: 0, uploader: nil))
}
