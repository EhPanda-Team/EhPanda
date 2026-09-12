import AppComponents
import AppModels
import AppTools
import Kingfisher
import PreviewSupport
import SFSafeSymbols
import Sharing
import SwiftUI
import TagTranslationFeature

public struct GalleryThumbnailCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SharedReader(.setting) private var setting: Setting

    /// At non-accessibility sizes, the badge's inward corner is cut into the cover rather than
    /// drawn by the badge itself, so it scales against the badge's own text style: a 15pt notch
    /// under text drawn three times taller reads as a square block, which is the same reason the
    /// badge's insets and radius scale (`CategoryLabel`). Identity at `.large`, where 15 is the
    /// designed radius and matches the cell's own corners.
    @ScaledMetric(relativeTo: .footnote) private var badgeCornerRadius: CGFloat = 15

    private let gallery: Gallery
    private let translateAction: ((String) -> TagTranslationLookup)?
    private let downloadBadge: DownloadBadge?

    public init(
        gallery: Gallery,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
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
            cover
            VStack(alignment: .leading, spacing: textColumnSpacing) {
                Text(gallery.title)
                    .font(.callout.bold())
                    .lineLimit(titleLineLimit)
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
                pageCountAndLanguage
                if dynamicTypeSize.isAccessibilitySize {
                    categoryLabel
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                rating
            }
            .padding()
        }
        .background(backgroundColor).clipShape(.rect(cornerRadius: 15))
    }

    /// Five symbols that grow with the text need roughly 245 points at `.accessibility5`, against
    /// the ~158 a half-width column leaves inside the cell's padding. `RatingView` is an `HStack` of
    /// intrinsically sized images: it can neither wrap nor compress, so the row would report a width
    /// wider than its own column and the cell's background would bleed over its neighbour — the one
    /// thing a two-column grid cannot allow (the column floor is the owner's, see `ThumbnailList`).
    ///
    /// So the rating keeps its designed five symbols for exactly as long as they fit the column
    /// whole — every non-accessibility size, and the wide iPad column at every size — and otherwise
    /// draws the same rating as one symbol and its value. That is the identical information in the
    /// width the column actually has, not less of it: the numeral is if anything the more precise
    /// reading of the two. Both candidates are intrinsically sized, so `ViewThatFits` measures them
    /// honestly here, and at and below the default size the first candidate always wins.
    private var rating: some View {
        ViewThatFits(in: .horizontal) {
            RatingView(rating: gallery.rating)
            compactRating
        }
        .foregroundStyle(Color.ratingStar)
        .font(.caption)
    }

    /// The rating as a single filled symbol and its half-rounded value — `RatingView`'s own
    /// rounding, so the compact form can never disagree with the symbols it stands in for.
    private var compactRating: some View {
        Label {
            Text(gallery.rating.halfRounded, format: .number)
        } icon: {
            Image(systemSymbol: .starFill)
        }
        .labelIconToTitleSpacing(2)
        .lineLimit(1)
    }

    /// At non-accessibility sizes the badge stays in the cover's designed corner overlay. At
    /// accessibility sizes it moves into the text column, where the full column width lets its
    /// uncapped text wrap without covering the artwork.
    private var cover: some View {
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
                if !dynamicTypeSize.isAccessibilitySize {
                    CategoryLabel(
                        text: gallery.category.value, color: gallery.color(host: setting.galleryHost),
                        insets: .init(top: 3, leading: 6, bottom: 3, trailing: 6),
                        cornerRadius: 0
                    )
                    // The label sits flush in the top-trailing corner of the cover; only its
                    // inward (bottom-leading) corner is rounded. Keep the label's own background
                    // flat (cornerRadius 0) so this uneven clip alone defines the shape.
                    .clipShape(.rect(bottomLeadingRadius: badgeCornerRadius))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
    }

    /// At accessibility sizes the category is a regular text-column badge. Its background uses
    /// `CategoryLabel`'s even corners rather than the cover overlay's one-corner cutout.
    private var categoryLabel: some View {
        CategoryLabel(
            text: gallery.category.value, color: gallery.color(host: setting.galleryHost),
            insets: .init(top: 3, leading: 6, bottom: 3, trailing: 6)
        )
    }

    /// The cell's stat group, spread across it: page count (or the download badge) leading,
    /// language trailing. The flexible frame that spreads it lives here rather than inside the
    /// arrangement below, because inside a `ViewThatFits` candidate it would absorb the overflow
    /// and every candidate would then measure as fitting.
    private var pageCountAndLanguage: some View {
        pageCountAndLanguageArrangement
            .lineLimit(statLineLimit)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Above the default size the pair is an `AdaptiveStack`: it keeps the designed row for as long
    /// as both members fit it whole and gives each a full-width line of its own once they do not.
    /// Both members are single-line wherever that arbitration happens, so their ideal widths are
    /// honest and `ViewThatFits` can measure them.
    ///
    /// The language is optional, which `AdaptiveStack` asks to be built from an explicit
    /// `ViewThatFits` when the two candidates need spacers or line limits of their own. This pair
    /// needs neither: a missing language leaves the lone page count anchored leading by the
    /// component's own lone-member rule, and both members answer to one line-limit policy — capped
    /// while the stack is what gives, uncapped once a full-width line is all there is to give.
    ///
    /// At and below the default size the designed row is used verbatim instead of being arbitrated
    /// (P-04), and the gate is not decoration here the way it would be on a full-width row: a
    /// two-column grid leaves this pair around 150 points, which a long language name fills on its
    /// own, so an ungated `AdaptiveStack` would stack the pair at the designed size too. Turning a
    /// designed one-line row into two lines is a visible change at the size this phase holds fixed;
    /// what the row does there instead — give both members the width and let them truncate — is the
    /// designed behaviour and stays it.
    @ViewBuilder private var pageCountAndLanguageArrangement: some View {
        if dynamicTypeSize <= .large {
            HStack(spacing: 10) {
                pageCountOrDownloadBadge
                    .frame(maxWidth: .infinity, alignment: .leading)

                languageText
            }
        } else {
            AdaptiveStack(hSpaceBetween: true, vSpacing: pairSpacing) {
                pageCountOrDownloadBadge

                languageText
            }
        }
    }

    private var languageText: Text? {
        (gallery.language?.value).map(Text.init)
    }

    @ViewBuilder private var pageCountOrDownloadBadge: some View {
        if let downloadBadge {
            DownloadBadgeLabel(badge: downloadBadge)
        } else {
            // A list row inflates a `titleAndIcon` label's icon well past the bare
            // `Image` this replaced — measured at ~29% wider (G-11-8). Re-asserting
            // the default scale on the icon itself overrides that ambient inflation
            // and restores the pre-sweep glyph; it is deliberately not a no-op.
            Label {
                Text(gallery.pageCount.description)
            } icon: {
                Image(systemSymbol: .photoOnRectangleAngled)
                    .imageScale(.medium)
            }
            .labelIconToTitleSpacing(2)
        }
    }

    /// Five lines at every size, with or without a download badge.
    ///
    /// The budget this replaces — three lines, two when a download badge took a line of its own —
    /// was chosen for a cell whose text is drawn at the default size, and it survives neither end
    /// of this grid's real range. A half-width column at an accessibility size fits three or four
    /// characters to a line, so three lines name no gallery at all; an uncapped title runs a single
    /// cell past a whole screen. Five lines is the owner's budget for both ends (owner decision,
    /// 2026-09-03), and it is a *wider* budget than the designed one at the default size, not a
    /// narrower one.
    ///
    /// It deliberately supersedes default-size appearance parity (D-15) rather than preserving it:
    /// the owner's reading is that the old cap was an oversight in a design that never met this
    /// case, so a uniform budget repairs the design instead of trading information away. The tail
    /// of a title too long for five lines is reached by opening the gallery, which is what tapping
    /// the cell already does.
    private let titleLineLimit: Int? = 5

    /// The stats read in full at every non-accessibility size, so they keep their single line
    /// there — the stack, not the glyphs, is what gives when the pair stops fitting. At
    /// accessibility sizes the cap is lifted, so a value that outgrows even a full-width line of
    /// its own wraps rather than losing its tail: a page count with no digits is a value removed,
    /// a wrapped one is merely taller. Mirrors `GalleryDetailCell`, the same list's other cell.
    private var statLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }

    /// The designed 5pt gap is what separates single lines of text. At an accessibility size the
    /// title alone is several wrapped lines tall and the tag cloud is a block, so a gap of 5 is
    /// narrower than the leading inside those groups and the cell reads as one slab of text: 10pt
    /// (double the designed gap) is the smallest step that keeps title, tags, stats, category and
    /// rating legible as separate groups. Below those sizes each group is one line and the designed
    /// 5 is kept verbatim.
    private var textColumnSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 10 : 5
    }

    /// The vertical gap `AdaptiveStack` leaves between the two members of the stat pair once they
    /// stop sharing a line. The pair is a single group, so its members sit closer together (6) than
    /// the 10 that separates the cell's groups from each other, and still read as a pair once
    /// stacked. At and below `.large` the stack keeps SwiftUI's default spacing, because the pair
    /// can stack there too — in a narrow enough column — and parity binds that case.
    private var pairSpacing: CGFloat? {
        dynamicTypeSize <= .large ? nil : 6
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

// The two widths the masonry actually gives a cell at an accessibility size. The grid never falls
// below two columns (owner, 2026-09-03), so the phone case is half a 415pt row — 200pt, the tightest
// width this cell is ever laid out in — and the iPad portrait case is half a 794pt row.
#Preview("Long title, AX5, phone column", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .previewFixture(identity: 5, title: previewLongTitle, rating: 4.5, pageCount: 1234))
        .frame(width: 190)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Long title, AX5, iPad column", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .previewFixture(identity: 7, title: previewLongTitle, rating: 4.5, pageCount: 1234))
        .frame(width: 390)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Long title, XXXL", traits: .sizeThatFitsLayout) {
    GalleryThumbnailCell(gallery: .previewFixture(identity: 6, title: previewLongTitle, rating: 4.5, pageCount: 1234))
        .frame(width: 180)
        .environment(\.dynamicTypeSize, .xxxLarge)
}
