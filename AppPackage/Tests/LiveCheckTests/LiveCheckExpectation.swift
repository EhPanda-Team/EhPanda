import Foundation

/// What each page must show, with a fixed ID and a fixed English sentence (19-CONTEXT D-22, D-23).
///
/// The sentence is the only text an issue or a results file carries about a failure. Every sentence is a literal:
/// nothing from a page, a URL or an error is ever interpolated into it.
enum LiveCheckExpectation: String, Codable, CaseIterable, Sendable {
    case frontPageRows = "frontPage.rows"
    case searchRows = "search.rows"
    case popularRows = "popular.rows"
    case toplistsRows = "toplists.rows"
    case galleryDetail = "gallery.detail"
    case galleryComments = "gallery.comments"
    case readerThumbnails = "reader.thumbnails"
    case readerImageURL = "reader.imageURL"
    case readerImageDecode = "readerImage.decode"
    case tagDatabaseAsset = "tagSuggestions.asset"
    case reportFormFields = "reportForm.fields"
    case earlierPage = "dependency.earlierPage"

    var sentence: String {
        switch self {
        case .frontPageRows:
            return "expected a gallery list with at least one row, found none"
        case .searchRows:
            return "expected search results with at least one row, found none"
        case .popularRows:
            return "expected the Popular list with at least one row, found none"
        case .toplistsRows:
            return "expected a gallery table with at least one row, found none"
        case .galleryDetail:
            return "expected a gallery page with its title, category and page count, found a page the parser rejects"
        case .galleryComments:
            return "expected the gallery page's comments with at least one comment, found none"
        case .readerThumbnails:
            return "expected links to the gallery's pages on its first preview page, found none"
        case .readerImageURL:
            return "expected the first page's image address on its reader page, found none"
        case .readerImageDecode:
            return "expected the first page's image to decode, found data that does not"
        case .tagDatabaseAsset:
            return "expected a tag database release with an English asset, found none"
        case .reportFormFields:
            return "expected the report form with its type picker and fields, found none"
        case .earlierPage:
            return "expected the value an earlier page provides, found none because that page failed"
        }
    }
}
