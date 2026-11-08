import Foundation

/// The pages the daily live check reads (19-CONTEXT D-20, D-24), in the order it reads them.
///
/// Guest pages are read through the app's own GET request types and parsers. The list pages (front page, search,
/// Popular, Toplists) are read with the app's URL builders and its list parser: their request types also ask the
/// gallery API for titles with a POST, which the check never sends (D-21). Watched, Favorites and ExHentai need a
/// signed-in account and are `skipped` while the check has no sign-in secret (D-24).
enum LiveCheckPage: String, Codable, CaseIterable, Sendable {
    case frontPage, search, popular, toplists, gallery, reader, readerImage, tagSuggestions, reportForm
    case watched, favorites, exhentai

    /// The keyword the search page asks for: a fixed, neutral word, never logged.
    static let searchKeyword = "landscape"

    /// How the page is read: one entry of the check's GET-only allowlist.
    var reader: LiveCheckReader? {
        switch self {
        case .frontPage, .search, .popular, .toplists:
            return .listPage
        case .gallery:
            return .galleryDetail
        case .reader:
            return .readerPage
        case .readerImage:
            return .imageData
        case .tagSuggestions:
            return .tagDatabase
        case .reportForm:
            return .reportForm
        case .watched, .favorites, .exhentai:
            return nil
        }
    }

    /// A page that needs a signed-in account; the check skips it (D-24).
    var needsSignIn: Bool {
        reader == nil
    }

    /// The expectation a page's own parse failure reports: the first thing the page must show.
    var primaryExpectation: LiveCheckExpectation? {
        switch self {
        case .frontPage:
            return .frontPageRows
        case .search:
            return .searchRows
        case .popular:
            return .popularRows
        case .toplists:
            return .toplistsRows
        case .gallery:
            return .galleryDetail
        case .reader:
            return .readerThumbnails
        case .readerImage:
            return .readerImageDecode
        case .tagSuggestions:
            return .tagDatabaseAsset
        case .reportForm:
            return .reportFormFields
        case .watched, .favorites, .exhentai:
            return nil
        }
    }
}

/// The check's GET-only allowlist: every way a page is read, with the app types it uses. Each type builds GET
/// requests only; `Scripts/live-check/test_request_allowlist.py` fails if this target names any other request type,
/// and the offline tests record every request a page read sends and require GET.
enum LiveCheckReader: String, CaseIterable, Sendable {
    /// `URLUtil`'s list URL, read once with GET and parsed by `Parser.parseGalleries`.
    case listPage
    /// `GalleryDetailRequest`.
    case galleryDetail
    /// `ThumbnailURLsRequest` for the first preview page, then `GalleryNormalImageURLsRequest` for page 1.
    case readerPage
    /// `DataRequest` for page 1's image, decoded in memory and discarded.
    case imageData
    /// `TagTranslatorRequest`: the tag database release the suggestions read.
    case tagDatabase
    /// `ReportFormRequest` on the gallery's `?report=other` page. The form is read, never sent.
    case reportForm

    /// The app request types this reader uses.
    var requestTypes: [String] {
        switch self {
        case .listPage:
            return []
        case .galleryDetail:
            return ["GalleryDetailRequest"]
        case .readerPage:
            return ["ThumbnailURLsRequest", "GalleryNormalImageURLsRequest"]
        case .imageData:
            return ["DataRequest"]
        case .tagDatabase:
            return ["TagTranslatorRequest"]
        case .reportForm:
            return ["ReportFormRequest"]
        }
    }
}
