import AppModels
import Foundation

extension GalleryDetail {
    /// The size's number to at most the two decimals the site gives, in the reader's number format.
    /// The unit stays with each caller, because the Detail strip sets it on a line of its own.
    func formattedSizeCount(locale: Locale = .autoupdatingCurrent) -> String {
        sizeCount.formatted(.number.locale(locale).precision(.fractionLength(0...2)).grouping(.never))
    }
}
