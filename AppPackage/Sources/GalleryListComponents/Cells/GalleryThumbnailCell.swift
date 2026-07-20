import SwiftUI
import Sharing
import SFSafeSymbols
import AppModels
import TagTranslationFeature
import AppComponents
import Kingfisher
import AppTools
import PreviewSupport

public struct GalleryThumbnailCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @SharedReader(.setting) private var setting: Setting

    private let gallery: Gallery
    private let translateAction: ((String) -> (String, TagTranslation?))?
    private let downloadBadge: DownloadBadge?

    public init(
        gallery: Gallery,
        translateAction: ((String) -> (String, TagTranslation?))? = nil,
        downloadBadge: DownloadBadge? = nil
    ) {
        self.gallery = gallery
        self.translateAction = translateAction
        self.downloadBadge = downloadBadge
    }

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5)
    }
    private var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.rowAspect)) }
                .imageModifier(WebtoonModifier(
                    minAspect: Defaults.ImageSize.webtoonMinAspect,
                    idealAspect: Defaults.ImageSize.webtoonIdealAspect
                ))
                .fade(duration: 0.25)
                .resizable()
                .scaledToFit()
                .overlay {
                    CategoryLabel(
                        text: gallery.category.value, color: gallery.color(host: setting.galleryHost),
                        insets: .init(top: 3, leading: 6, bottom: 3, trailing: 6),
                        cornerRadius: 0
                    )
                    // The label sits flush in the top-trailing corner of the cover; only its
                    // inward (bottom-leading) corner is rounded. Keep the label's own background
                    // flat (cornerRadius 0) so this uneven clip alone defines the shape.
                    .clipShape(.rect(bottomLeadingRadius: 15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title)
                    .font(.callout.bold())
                    .lineLimit(downloadBadge == nil ? 3 : 2)
                let tagContents = gallery.tagContents(maximum: setting.listTagsNumberMaximum)
                if setting.showTagsInList, !tagContents.isEmpty {
                    TagCloudView(data: tagContents) { content in
                        let translation = translateAction?(content.rawNamespace + content.text).1
                        TagCloudCell(
                            text: translation?.displayValue ?? content.text,
                            imageURL: translation?.valueImageURL,
                            showsImages: setting.showImagesInTags,
                            font: .caption2, padding: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
                            textColor: content.backgroundColor != nil ? content.textColor ?? .secondary : .secondary,
                            backgroundColor: content.backgroundColor ?? tagColor
                        )
                    }
                }
                HStack(spacing: 10) {
                    Group {
                        if let downloadBadge {
                            DownloadBadgeLabel(badge: downloadBadge)
                        } else {
                            Label(gallery.pageCount.description, systemSymbol: .photoOnRectangleAngled)
                                .labelIconToTitleSpacing(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    (gallery.language?.value).map(Text.init)
                }
                .lineLimit(1).font(.footnote).foregroundStyle(.secondary)

                RatingView(rating: gallery.rating).foregroundStyle(.yellow).font(.caption)
            }
            .padding()
        }
        .background(backgroundColor).clipShape(.rect(cornerRadius: 15))
    }
}

private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"

private extension Gallery {
    static func previewFixture(identity: Int, title: String, rating: Float, pageCount: Int) -> Gallery {
        .init(
            gid: PreviewIdentifiers[identity].uuidString,
            token: "",
            title: title,
            rating: rating,
            tags: [],
            category: .doujinshi,
            uploader: "Anonymous",
            pageCount: pageCount,
            postedDate: .now,
            coverURL: nil,
            galleryURL: nil
        )
    }
}

#Preview("Loaded", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .preview)
}

#Preview("Max rating, long title", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .previewFixture(identity: 0, title: previewLongTitle, rating: 5, pageCount: 1234))
}

#Preview("Min rating, short title", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .previewFixture(identity: 1, title: "Doujin", rating: 0, pageCount: 1))
}
