import AppComponents
import AppModels
import AppTools
import Resources
import SFSafeSymbols
import Sharing
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

    var body: some View {
        Label {
            Text(rating.halfRounded, format: .number)
        } icon: {
            Image(systemSymbol: .starFill)
        }
        .accessibilityRepresentation { RatingView(rating: rating) }
    }
}

struct HomeSlideshowInformation: View {
    @Environment(\.colorScheme) private var colorScheme

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
            .frame(maxWidth: 500, alignment: .leading)
            if !gallery.homeSlideshowTags.isEmpty {
                GlassEffectContainer(spacing: 0) {
                    TagCloudView(data: gallery.homeSlideshowTags) { tag in
                        TagCloudCell(
                            text: tag.text, imageURL: nil, showsImages: false, font: .caption2,
                            padding: .init(top: 4, leading: 8, bottom: 4, trailing: 8),
                            textColor: colorScheme == .dark ? .primary : .secondary, backgroundColor: .clear
                        )
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    }
                }
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

extension Gallery {
    /// Language is already a field; duplicate names never fill additional chip positions.
    var homeSlideshowTags: [GalleryTag.Content] {
        var names: Set<String> = [category.rawValue.lowercased()]
        return Array(tags
            .filter({ $0.namespace != .language })
            .flatMap(\.contents)
            .filter { tag in
                let name = tag.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !name.isEmpty && names.insert(name).inserted
            }
            .prefix(3))
    }
}

struct HomeFrontpageCell: View {
    @SharedReader(.setting) private var setting: Setting
    @GalleryCoverMetrics private var coverSize: CGSize
    let gallery: Gallery
    let showsRichInformation: Bool

    init(gallery: Gallery, showsRichInformation: Bool) {
        self.gallery = gallery
        self.showsRichInformation = showsRichInformation
        _coverSize = GalleryCoverMetrics(showsRichInformation ? .homeFrontpage : .standard)
    }

    private var title: String {
        setting.simplifyGalleryTitles ? gallery.simplifiedTitle : gallery.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GalleryCover(
                url: gallery.coverURL, style: showsRichInformation ? .homeFrontpage : .standard, contentMode: .fill
            )
                .accessibilityHidden(true)
            if showsRichInformation {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                HomePageLanguage(gallery: gallery)
            }
        }
        .frame(width: coverSize.width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title, isEnabled: !showsRichInformation)
        .accessibilityIdentifier("home_frontpage_title_\(gallery.id)")
    }
}

/// A shared row height keeps both cover rows aligned when metadata wraps differently.
struct HomeFrontpageWall: View {
    let columns: [[Gallery]]
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
            HomeFrontpageCell(gallery: gallery, showsRichInformation: true)
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
        .containerRelativeFrame(.horizontal) { width, _ in (width - 80) / 3 }
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
