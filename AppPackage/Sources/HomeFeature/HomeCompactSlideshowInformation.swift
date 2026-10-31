import AppModels
import AppTools
import SwiftUI

struct HomeCompactSlideshowInformation: View {
    let gallery: Gallery

    var body: some View {
        ViewThatFits(in: .horizontal) {
            metadata(showsCategory: true)
                .fixedSize(horizontal: true, vertical: false)
            metadata(showsCategory: false)
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
