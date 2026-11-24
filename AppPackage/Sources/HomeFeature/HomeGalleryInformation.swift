import AppComponents
import AppModels
import AppTools
import Resources
import SFSafeSymbols
import Sharing
import SwiftUI

struct HomePageLanguage: View {
    let gallery: Gallery
    /// Each field keeps its one-line width instead of wrapping in the width it is offered, so that the view reports
    /// the width its fields need. The Front Page cell widens to it (`HomeFrontPageCellLayout`).
    var keepsFieldsWhole = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { fields }
            VStack(alignment: .leading, spacing: 4) { fields }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        // A `Button` centres its label's lines, and the alignment set on the `Button` itself does not reach them, so a
        // wrapped field would sit centred off the cell's leading edge.
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder private var fields: some View {
        Text(.RLocalizable.pages(count: gallery.pageCount))
            .fixedSize(horizontal: keepsFieldsWhole, vertical: true)
        if let language = gallery.language {
            Text(language.value)
                .fixedSize(horizontal: keepsFieldsWhole, vertical: true)
        }
    }
}

struct HomeGalleryRating: View {
    let rating: Float
    var iconFont: Font?

    var body: some View {
        Label {
            Text(rating.halfRounded, format: .number.precision(.fractionLength(1)))
        } icon: {
            Image(systemSymbol: .starFill)
                .font(iconFont)
        }
        .accessibilityRepresentation { RatingView(rating: rating) }
    }
}

struct HomeSlideshowInformation: View {
    let gallery: Gallery

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { ratingAndLanguage }
                VStack(alignment: .leading, spacing: 6) { ratingAndLanguage }
            }
            .font(.subheadline)
            statistics
                .frame(maxWidth: 360, alignment: .leading)
            if !gallery.homeSlideshowTags.isEmpty {
                HomeSlideshowTags(gallery: gallery)
            }
        }
        .accessibilityIdentifier("home_slideshow_information")
    }

    /// Pages and category in two equal columns, or, when the columns do not fit the 360 pt this block is capped at,
    /// one stat per line as "label value" (the owner's C9 decision, 19-23), the same fallback as the compact card's.
    /// The columns stay equal rather than sized by their content, as the owner chose, so the first option's
    /// ideal width is twice the wider column plus the spacing, and no label is ever broken mid-word.
    private var statistics: some View {
        ViewThatFits(in: .horizontal) {
            HomeEqualColumnsLayout(spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.homeMetadataPages).font(.caption).foregroundStyle(.secondary)
                    Text(gallery.pageCount, format: .number).font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(.homeMetadataCategory).font(.caption).foregroundStyle(.secondary)
                    Text(gallery.category.value).font(.subheadline)
                }
            }
            HomeSlideshowStatLines(pageCount: gallery.pageCount, category: gallery.category, valueFont: .subheadline)
        }
    }

    @ViewBuilder private var ratingAndLanguage: some View {
        HomeGalleryRating(rating: gallery.rating)
        if let language = gallery.language {
            Text(language.value).foregroundStyle(.secondary)
        }
    }
}

/// Columns of one width: the widest column's ideal width, or, when the layout is proposed a width, an equal share of
/// it. `ViewThatFits` needs that ideal width to tell whether equal columns fit, which an `HStack` of
/// `maxWidth: .infinity` frames does not report (it reports the sum of the columns' own widths).
private struct HomeEqualColumnsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let columnWidth = equalColumnWidth(proposal: proposal, subviews: subviews)
        let height = subviews
            .map({ $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height })
            .max() ?? 0
        return CGSize(width: totalWidth(columnWidth: columnWidth, count: subviews.count), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = equalColumnWidth(
            proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews
        )
        var columnOrigin = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: columnOrigin, y: bounds.minY), anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: bounds.height)
            )
            columnOrigin += columnWidth + spacing
        }
    }

    private func equalColumnWidth(proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        guard let width = proposal.width else {
            return subviews.map({ $0.sizeThatFits(.unspecified).width }).max() ?? 0
        }
        let gaps = spacing * CGFloat(max(0, subviews.count - 1))
        return max(0, (width - gaps) / CGFloat(max(1, subviews.count)))
    }

    private func totalWidth(columnWidth: CGFloat, count: Int) -> CGFloat {
        columnWidth * CGFloat(count) + spacing * CGFloat(max(0, count - 1))
    }
}

struct HomeFrontPageCell: View {
    @SharedReader(.setting) private var setting: Setting
    @GalleryCoverMetrics private var coverSize: CGSize
    let gallery: Gallery
    let showsRichInformation: Bool
    let coverStyle: GalleryCoverStyle
    let maximumCoverHeight: CGFloat?

    init(
        gallery: Gallery, showsRichInformation: Bool, coverStyle: GalleryCoverStyle = .homeFrontPage,
        maximumCoverHeight: CGFloat? = nil
    ) {
        self.maximumCoverHeight = maximumCoverHeight
        self.gallery = gallery
        self.showsRichInformation = showsRichInformation
        self.coverStyle = showsRichInformation ? coverStyle : .standard
        _coverSize = GalleryCoverMetrics(
            showsRichInformation ? coverStyle : .standard, maximumHeight: maximumCoverHeight
        )
    }

    var body: some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle), isEnabled: !showsRichInformation
            )
            .accessibilityIdentifier("home_front_page_title_\(gallery.id)")
    }

    private var cover: some View {
        GalleryCover(
            url: gallery.coverURL, style: coverStyle, contentMode: .fill, maximumHeight: maximumCoverHeight
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        if showsRichInformation {
            HomeFrontPageCellLayout(coverSize: coverSize, spacing: 10) {
                cover
                Text(gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle))
                    .font(coverStyle == .homeCompact ? .footnote.bold() : .subheadline.bold())
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                HomePageLanguage(gallery: gallery, keepsFieldsWhole: true)
            }
        } else {
            cover.frame(width: coverSize.width, alignment: .leading)
        }
    }
}

/// The cover, the title and the fields of a Front Page cell with rich information, in a column as wide as the widest of
/// the cover and the fields' one-line widths, and never narrower than the cover.
///
/// The cover's scale stops at `GalleryCoverStyle.maximumScale` while the text keeps growing with Dynamic Type, so from
/// `.accessibility4` up a page count or a language is wider than the cover. A column exactly as wide as the cover made
/// the field wrap, after the number ("26" / "Seiten") and, in Japanese, inside the unit. The owner chose a wider
/// column over a broken field (19-31, 2026-11-25). At the sizes where the fields fit the cover, which is every size up
/// to `.accessibility3`, the column is the cover's width as before. The cover keeps its size on the leading edge and
/// the title takes the column's width; the wall's columns follow, as `HomeCoverWallLayout` sizes a column by its widest
/// cell.
///
/// The subviews are the cover, the title and the fields (a `HomePageLanguage` that keeps its fields whole). The width
/// asked of the fields is the cover's: they answer with the width they need when it is more, and with a width within it
/// when the page count and the language share a line or when each fits.
private struct HomeFrontPageCellLayout: Layout {
    let coverSize: CGSize
    let spacing: CGFloat

    private struct Parts {
        let cover: LayoutSubview
        let title: LayoutSubview
        let fields: LayoutSubview

        init?(_ subviews: Subviews) {
            guard subviews.count == 3, let cover = subviews.first, let title = subviews.dropFirst().first,
                  let fields = subviews.last
            else { return nil }
            self.cover = cover
            self.title = title
            self.fields = fields
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let parts = Parts(subviews) else { return coverSize }
        let width = columnWidth(parts)
        let columnProposal = ProposedViewSize(width: width, height: nil)
        let titleHeight = parts.title.sizeThatFits(columnProposal).height
        let fieldsHeight = parts.fields.sizeThatFits(columnProposal).height
        return CGSize(width: width, height: coverSize.height + spacing + titleHeight + spacing + fieldsHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let parts = Parts(subviews) else { return }
        let columnProposal = ProposedViewSize(width: columnWidth(parts), height: nil)
        let titleOrigin = bounds.minY + coverSize.height + spacing
        let fieldsOrigin = titleOrigin + parts.title.sizeThatFits(columnProposal).height + spacing
        parts.cover.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(coverSize)
        )
        parts.title.place(
            at: CGPoint(x: bounds.minX, y: titleOrigin), anchor: .topLeading, proposal: columnProposal
        )
        parts.fields.place(
            at: CGPoint(x: bounds.minX, y: fieldsOrigin), anchor: .topLeading, proposal: columnProposal
        )
    }

    private func columnWidth(_ parts: Parts) -> CGFloat {
        let fieldsWidth = parts.fields.sizeThatFits(ProposedViewSize(width: coverSize.width, height: nil)).width
        return max(coverSize.width, fieldsWidth)
    }
}

/// A shared row height keeps both cover rows aligned when metadata wraps differently.
struct HomeFrontPageWall: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let columns: [[Gallery]]
    let maximumCoverHeight: CGFloat?
    let navigateAction: (Gallery) -> Void

    /// The cells are laid out by `HomeCoverWallLayout` rather than a `Grid` so that each one is a direct
    /// child of a scroll target layout. The 20pt side inset is the section's content margin, set where
    /// the scroll view is, so the snapped column and the first column rest at the same inset.
    var body: some View {
        HomeCoverWallLayout(columnSpacing: 20, rowSpacing: 26) {
            ForEach(columns.compactMap(\.first), content: galleryButton)
            ForEach(columns.compactMap(\.last), content: galleryButton)
        }
        .scrollTargetLayout()
    }

    private func galleryButton(gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery)
        } label: {
            HomeFrontPageCell(
                gallery: gallery, showsRichInformation: true,
                coverStyle: horizontalSizeClass == .regular ? .homeFrontPage : .homeCompact,
                maximumCoverHeight: maximumCoverHeight
            )
        }
        .tint(.primary)
        .multilineTextAlignment(.leading)
    }
}

struct HomeDestinationCard: View {
    let type: HomeMiscGridType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(type.title).font(.title2.bold())
                Spacer(minLength: 12)
                Image(systemSymbol: type.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            Text(type.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(type.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemSymbol: .arrowUpRight)
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .padding(24)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 15))
        .containerRelativeFrame(.horizontal) { width, _ in
            width >= 744 ? (width - 80) / 3 : width * 0.7
        }
        .tint(.primary)
        .multilineTextAlignment(.leading)
    }
}

extension HomeMiscGridType {
    var footnote: LocalizedStringResource {
        switch self {
        case .popular: .homePopularFootnote
        case .watched: .homeWatchedFootnote
        case .history: .homeHistoryFootnote
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .popular: .homePopularDescription
        case .watched: .homeWatchedDescription
        case .history: .homeHistoryDescription
        }
    }
}
