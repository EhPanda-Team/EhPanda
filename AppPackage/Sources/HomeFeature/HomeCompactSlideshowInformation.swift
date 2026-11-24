import AppModels
import AppTools
import SwiftUI

/// The compact slideshow card's three stats: rating, page count and category.
///
/// Beside the cover the stats are a grid of labels over values, with the category dropped when the three columns do
/// not fit. When even the two-column grid does not fit beside the cover, `HomeCompactSlideshowLayout` moves the stats
/// below the cover and this view draws them as ``HomeSlideshowStatLines`` instead (`stacksStats`).
struct HomeCompactSlideshowInformation: View {
    let gallery: Gallery
    var stacksStats = false

    var body: some View {
        Group {
            if stacksStats {
                HomeSlideshowStatLines(
                    rating: gallery.rating, pageCount: gallery.pageCount, category: gallery.category,
                    valueFont: .caption
                )
            } else {
                // Both grids keep their one-line widths, so the layout can read the narrower grid's width as the
                // least the stats need (its proposal of zero width gets the last option at that width).
                ViewThatFits(in: .horizontal) {
                    metadata(showsCategory: true)
                        .fixedSize(horizontal: true, vertical: false)
                    metadata(showsCategory: false)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .accessibilityIdentifier("home_slideshow_information")
    }

    private func metadata(showsCategory: Bool) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow(alignment: .firstTextBaseline) {
                Text(.homeMetadataRating)
                Text(.homeMetadataPages)
                if showsCategory {
                    Text(.homeMetadataCategory)
                }
            }
            .foregroundStyle(.secondary)

            GridRow(alignment: .firstTextBaseline) {
                Text(gallery.rating.halfRounded, format: .number.precision(.fractionLength(1)))
                Text(gallery.pageCount, format: .number)
                if showsCategory {
                    Text(gallery.category.value)
                }
            }
        }
        .font(.caption)
    }
}

/// The last fallback of the slideshow card's stats (the owner's C9 decision, 19-23): one stat per line, the label then
/// its value, so that no label is ever broken mid-word. A label is always one word that fits the card's width on its
/// own, which a grid column beside the cover cannot promise at the largest accessibility sizes ("Rat-ing",
/// "Be-wer-tung"). The rating is listed with the other two stats where the card has no star rating of its own.
struct HomeSlideshowStatLines: View {
    var rating: Float?
    let pageCount: Int
    let category: AppModels.Category
    let valueFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let rating {
                HomeSlideshowStatLine(label: .homeMetadataRating) {
                    Text(rating.halfRounded, format: .number.precision(.fractionLength(1)))
                        .font(valueFont)
                }
            }
            HomeSlideshowStatLine(label: .homeMetadataPages) {
                Text(pageCount, format: .number).font(valueFont)
            }
            HomeSlideshowStatLine(label: .homeMetadataCategory) {
                Text(category.value).font(valueFont)
            }
        }
    }
}

/// A stat's label and value on one line. A value that does not fit beside its label moves under it, as a whole word,
/// rather than breaking inside the word.
private struct HomeSlideshowStatLine<Value: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder let value: Value

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                labelText
                value
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText
                value
            }
        }
    }

    private var labelText: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
