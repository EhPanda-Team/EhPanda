import AppTools
import SwiftUI
import AppModels
import AppComponents
import Kingfisher

public struct GalleryRankingCell: View {
    private let gallery: Gallery
    private let ranking: Int

    public init(gallery: Gallery, ranking: Int) {
        self.gallery = gallery
        self.ranking = ranking
    }

    public var body: some View {
        HStack {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .defaultModifier()
                .scaledToFill()
                .frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75)
                .clipShape(.rect(cornerRadius: 2))

            Text(String(ranking))
                .fontWeight(.medium)
                .font(.title2)
                .padding(.horizontal)

            VStack(alignment: .leading) {
                Text(gallery.trimmedTitle)
                    .bold()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                gallery.uploader.map(Text.init)?
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption)
        }
    }
}

private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"

private extension Gallery {
    static func previewFixture(title: String, uploader: String?) -> Gallery {
        .init(
            gid: UUID().uuidString,
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
    GalleryRankingCell(gallery: .previewFixture(title: previewLongTitle, uploader: "Anonymous"), ranking: 999)
}

#Preview("Short title, no uploader", traits: .sizeThatFitsLayout) {
    GalleryRankingCell(gallery: .previewFixture(title: "Doujin", uploader: nil), ranking: 10)
}
