import AppComponents
import AppModels
import AppTools
import Kingfisher
import PreviewSupport
import SFSafeSymbols
import Sharing
import SwiftUI
import TagTranslationFeature

public struct GalleryDetailCell: View {
    public enum CoverSource {
        case dynamic
        case `static`(URL?)
    }

    @Environment(\.colorScheme) private var colorScheme

    private let gallery: Gallery
    private let coverSource: CoverSource
    private let translateAction: ((String) -> TagTranslationLookup)?
    private let downloadBadge: DownloadBadge?

    public init(
        gallery: Gallery,
        coverSource: CoverSource = .dynamic,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadge: DownloadBadge? = nil
    ) {
        self.gallery = gallery
        self.coverSource = coverSource
        self.translateAction = translateAction
        self.downloadBadge = downloadBadge
    }

    private var resolvedCoverURL: URL? {
        switch coverSource {
        case .dynamic:
            gallery.coverURL
        case .static(let url):
            url
        }
    }

    public var body: some View {
        GalleryDetailCellContent(
            gallery: gallery,
            resolvedCoverURL: resolvedCoverURL,
            colorScheme: colorScheme,
            translateAction: translateAction,
            downloadBadge: downloadBadge
        )
    }
}

private struct GalleryDetailCellContent: View {
    @SharedReader(.setting) private var setting: Setting

    private let gallery: Gallery
    private let resolvedCoverURL: URL?
    private let colorScheme: ColorScheme
    private let translateAction: ((String) -> TagTranslationLookup)?
    private let downloadBadge: DownloadBadge?

    init(
        gallery: Gallery,
        resolvedCoverURL: URL?,
        colorScheme: ColorScheme,
        translateAction: ((String) -> TagTranslationLookup)?,
        downloadBadge: DownloadBadge?
    ) {
        self.gallery = gallery
        self.resolvedCoverURL = resolvedCoverURL
        self.colorScheme = colorScheme
        self.translateAction = translateAction
        self.downloadBadge = downloadBadge
    }

    private var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }

    var body: some View {
        HStack(spacing: 10) {
            KFImage(resolvedCoverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.rowAspect)) }
                .defaultModifier()
                .scaledToFit()
                .frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH)
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title)
                    .lineLimit(downloadBadge == nil ? 3 : 2)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if gallery.uploader != nil || gallery.language != nil {
                    HStack {
                        gallery.uploader.map(Text.init)

                        Spacer()

                        (gallery.language?.value).map(Text.init)
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .lineLimit(1)
                }

                let tagContents = gallery.tagContents(maximum: setting.listTagsNumberMaximum)
                if setting.showTagsInList, !tagContents.isEmpty {
                    TagCloudView(data: tagContents) { content in
                        let translation = translateAction?(content.rawNamespace + content.text).translation
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
                HStack {
                    RatingView(rating: gallery.rating)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let downloadBadge {
                        DownloadBadgeLabel(badge: downloadBadge)
                    } else {
                        // A list row inflates a `titleAndIcon` label's icon well past the bare
                        // `Image` this replaced — measured at ~29% wider (G-11-8). Re-asserting the
                        // default scale on the icon itself overrides that ambient inflation and
                        // restores the pre-sweep glyph; it is deliberately not a no-op.
                        Label {
                            Text(gallery.pageCount.description)
                        } icon: {
                            Image(systemSymbol: .photoOnRectangleAngled)
                                .imageScale(.medium)
                        }
                        .labelIconToTitleSpacing(2)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.75)
                    }
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(text: gallery.category.value, color: gallery.color(host: setting.galleryHost))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(gallery.formattedDateString)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.75)
                }
                .padding(.top, 1)
            }
            .drawingGroup()
        }
        .padding(.vertical, 5).padding(.leading, -10).padding(.trailing, -5)
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
    GalleryDetailCell(gallery: .preview)
}

#Preview("Max rating, long title", traits: .sizeThatFitsLayout) {
    GalleryDetailCell(gallery: .previewFixture(identity: 2, title: previewLongTitle, rating: 5, pageCount: 1234))
}

#Preview("Min rating, short title", traits: .sizeThatFitsLayout) {
    GalleryDetailCell(gallery: .previewFixture(identity: 3, title: "Doujin", rating: 0, pageCount: 1))
}
