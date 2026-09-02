import AppComponents
import AppModels
import AppTools
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        coverAndText
            .padding(.vertical, 5)
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            // The row's own width, which the enclosing `List` proposes rather than derives from
            // this content, determines when the cover and text stack vertically.
            .onGeometryChange(for: CGFloat.self, of: \.size.width) {
                rowWidth = $0
            }
    }

    /// The designed row bleeds outwards into the `List`'s own row insets, which buys the text
    /// column a few points of width while it sits beside the cover. Once it owns the whole row
    /// (the stacked arrangement below), the same bleed spends those points pushing wrapping text
    /// against the screen edges, so above the default size the row keeps the `List`'s natural
    /// insets instead of eating into them — no other inset would line the row up with the rest of
    /// the list. At and below `.large` the designed bleed is kept verbatim, which is what
    /// default-size appearance parity requires.
    private var leadingInset: CGFloat { dynamicTypeSize <= .large ? -10 : 0 }
    private var trailingInset: CGFloat { dynamicTypeSize <= .large ? -5 : 0 }

    /// The cover grows within its shared role limit; the text column also adapts its placement.
    /// At an accessibility size, a column beside the cover
    /// is narrower than the row's own rigid content (five rating stars, a glyph and a count), the
    /// row reports a width larger than the screen and the oversized content is centred — which is
    /// what used to push the cover half off the leading edge and the stats past the trailing one.
    /// Stacking gives the text the row's whole width.
    ///
    /// The arrangement is chosen by an explicit size read rather than by `ViewThatFits`, because
    /// this level cannot be measured honestly: the column holds wrapping text and a flowing tag
    /// cloud whose *ideal* widths are their full single-line widths, so every candidate containing
    /// them measures as not fitting and the last one would win at every size, the default included.
    /// The pairs inside the column are built from single-line members with honest ideal widths, and
    /// those do arbitrate by fitting.
    ///
    /// Stacked, the gap between cover and column is 12 rather than the 10 that separates them side
    /// by side: horizontally the two are told apart by being on different columns, vertically only
    /// by the gap itself, and it has to read as wider than the 10 between the column's own groups.
    @ViewBuilder private var coverAndText: some View {
        if stacksCoverAboveText {
            VStack(alignment: .leading, spacing: 12) {
                cover
                textColumn
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                cover
                textColumn
            }
        }
    }

    /// Stacking is a remedy for a row too narrow to hold the cover beside the grown text, so it is
    /// gated on the row's own width and not on the type size alone: only a *portrait phone* is that
    /// narrow. A landscape phone and an iPad — in either orientation — offer the row enough width
    /// that the text column keeps more than the five rating stars need beside the cover, so there
    /// the cover and title stay on one line at every size, which is what the owner asked for.
    ///
    /// 550 points is the divide: the widest portrait phone proposes this row about 440 points, the
    /// narrowest landscape phone about 670, and the iPad more still, so the threshold sits in the
    /// gap between them with room to spare. An unmeasured row (`rowWidth` still zero) is treated as
    /// the narrow case, so a portrait phone — the common one — stacks on the first pass without a
    /// flip; a landscape row settles from the stack to the row as its width lands.
    private var stacksCoverAboveText: Bool {
        dynamicTypeSize.isAccessibilitySize && rowWidth < coverTextStackWidth
    }
    private let coverTextStackWidth: CGFloat = 550

    @State private var rowWidth: CGFloat = .zero

    private var cover: some View {
        GalleryCover(url: resolvedCoverURL, style: .standard)
    }

    /// The designed 5pt gap is what separates single lines of text. At an accessibility size every
    /// one of these groups is itself several wrapped lines tall, so a gap of 5 is narrower than
    /// the leading inside a group and the column reads as one undifferentiated block: 10pt (double
    /// the designed gap) is the smallest step that keeps title, uploader, tags, stats and category
    /// legible as five separate groups. Below the accessibility sizes each group is one line and
    /// the designed 5 is kept verbatim.
    private var textColumnSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 10 : 5
    }

    /// The vertical gap `AdaptiveStack` puts between the two members of a stat pair once the pair
    /// stops fitting one line. A pair is a single group, so its members sit closer together (6)
    /// than the 10 that separates the column's groups from each other, and the pair still reads as
    /// a pair once it stacks. At and below `.large` the stack keeps SwiftUI's default spacing,
    /// because the pair can stack there too — in a narrow container — and parity binds that case.
    private var pairSpacing: CGFloat? {
        dynamicTypeSize <= .large ? nil : 6
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: textColumnSpacing) {
            Text(gallery.title)
                .lineLimit(titleLineLimit)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            uploaderAndLanguage
            tagCloud
            ratingAndPageCount
            categoryAndDate
        }
        .drawingGroup()
    }

    /// Uploader and language share a line for as long as both fit it whole. Both members are
    /// optional, so this pair is an explicit `ViewThatFits` rather than an `AdaptiveStack`: the
    /// `Spacer()` that holds them apart must live in the horizontal candidate alone (in shared
    /// content it would become a vertical expander once the pair stacks), and so must
    /// `.lineLimit(1)`, so that a stacked uploader may wrap instead of being ellipsised.
    ///
    /// Its stacked candidate takes the same ``pairSpacing`` as the `AdaptiveStack` pairs below it:
    /// uploader and language are one group however they are arranged.
    @ViewBuilder private var uploaderAndLanguage: some View {
        if gallery.uploader != nil || gallery.language != nil {
            ViewThatFits(in: .horizontal) {
                HStack {
                    uploaderText

                    Spacer()

                    languageText
                }
                .lineLimit(1)

                VStack(alignment: .leading, spacing: pairSpacing) {
                    uploaderText
                    languageText
                }
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
        }
    }

    private var uploaderText: Text? {
        gallery.uploader.map(Text.init)
    }

    private var languageText: Text? {
        (gallery.language?.value).map(Text.init)
    }

    @ViewBuilder private var tagCloud: some View {
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
    }

    private var ratingAndPageCount: some View {
        AdaptiveStack(hSpaceBetween: true, vSpacing: pairSpacing) {
            RatingView(rating: gallery.rating)
                .font(.caption)
                .foregroundStyle(.yellow)

            pageCountOrDownloadBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var pageCountOrDownloadBadge: some View {
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
            // Load-bearing for the row separator — NOT a redundant restatement of the
            // default style. A default-styled `Label` publishes a `.listRowSeparatorLeading`
            // anchor at its title's leading edge; because this Label sits at the row's
            // trailing edge, that anchor collapses the `List` row separator to a ~10pt
            // sliver. Routing the Label through any explicit `labelStyle` drops the anchor,
            // so the separator falls back to the text column's leading edge (the pre-sweep
            // inset). Do not remove.
            .labelStyle(.titleAndIcon)
            .labelIconToTitleSpacing(2)
            .lineLimit(statLineLimit)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var categoryAndDate: some View {
        AdaptiveStack(hSpaceBetween: true, hAlignment: .bottom, vSpacing: pairSpacing) {
            CategoryLabel(text: gallery.category.value, color: gallery.color(host: setting.galleryHost))

            Text(gallery.formattedDateString)
                .lineLimit(statLineLimit)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 1)
    }

    /// The title is user-authored text, so above the default size it carries no cap at all: a long
    /// title keeps every word and the row grows to hold it, instead of surrendering its tail one
    /// size step at a time. At and below the default size the designed budget — three lines, two
    /// when a download badge takes a line of its own — is kept verbatim, which is what default-size
    /// appearance parity requires.
    private var titleLineLimit: Int? {
        guard dynamicTypeSize <= .large else { return nil }
        return downloadBadge == nil ? 3 : 2
    }

    /// The stats values read in full at every non-accessibility size, so they keep their single
    /// line there. At accessibility sizes the cap is lifted, so a value that outgrows even a
    /// full-width line of its own wraps rather than losing its tail — a page count with no digits
    /// or a timestamp with no time is a value removed, while a wrapped one is merely taller.
    private var statLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
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

#Preview("Long title, accessibility size", traits: .sizeThatFitsLayout) {
    GalleryDetailCell(gallery: .previewFixture(identity: 4, title: previewLongTitle, rating: 4.5, pageCount: 1234))
        .environment(\.dynamicTypeSize, .accessibility5)
}
