import AppComponents
import AppModels
import AppTools
import Resources
import SFSafeSymbols
import SwiftUI

struct HomePageLanguage: View {
    let gallery: Gallery

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { fields }
            VStack(alignment: .leading, spacing: 4) { fields }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var fields: some View {
        Text(.RLocalizable.pages(count: gallery.pageCount))
            .fixedSize(horizontal: false, vertical: true)
        if let language = gallery.language {
            Text(language.value)
                .fixedSize(horizontal: false, vertical: true)
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
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.homeMetadataPages).font(.caption).foregroundStyle(.secondary)
                    Text(gallery.pageCount, format: .number).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(.homeMetadataCategory).font(.caption).foregroundStyle(.secondary)
                    Text(gallery.category.value).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 360, alignment: .leading)
            if !gallery.homeSlideshowTags.isEmpty {
                HomeSlideshowTags(gallery: gallery)
            }
        }
        .accessibilityIdentifier("home_slideshow_information")
    }

    @ViewBuilder private var ratingAndLanguage: some View {
        HomeGalleryRating(rating: gallery.rating)
        if let language = gallery.language {
            Text(language.value).foregroundStyle(.secondary)
        }
    }
}

struct HomeFrontPageCell: View {
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
        VStack(alignment: .leading, spacing: 10) {
            GalleryCover(
                url: gallery.coverURL, style: coverStyle, contentMode: .fill, maximumHeight: maximumCoverHeight
            )
                .accessibilityHidden(true)
            if showsRichInformation {
                Text(gallery.title)
                    .font(coverStyle == .homeCompact ? .footnote.bold() : .subheadline.bold())
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                HomePageLanguage(gallery: gallery)
            }
        }
        .frame(width: coverSize.width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(gallery.title, isEnabled: !showsRichInformation)
        .accessibilityIdentifier("home_front_page_title_\(gallery.id)")
    }
}

/// A shared row height keeps both cover rows aligned when metadata wraps differently.
struct HomeFrontPageWall: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let columns: [[Gallery]]
    let maximumCoverHeight: CGFloat?
    let navigateAction: (Gallery) -> Void

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 26) {
            GridRow {
                ForEach(columns.compactMap(\.first), content: galleryButton)
            }
            GridRow {
                ForEach(columns.compactMap(\.last), content: galleryButton)
            }
        }
        .padding(.horizontal, 20)
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
