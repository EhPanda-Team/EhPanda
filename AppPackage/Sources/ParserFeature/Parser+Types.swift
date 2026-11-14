public import AppModels
public import Foundation

extension Parser {
    public struct ThumbnailPanelInfo {
        public let coverURL: URL
        public let category: AppModels.Category
        public let rating: Float
        public let publishedDate: Date
        public let pageCount: Int
        public let uploader: String?
        /// The row's star class is not plain `ir`: the signed-in user has rated the gallery.
        public let hasRated: Bool
        /// The colour class (`irr`, `irg`, `irb`) of that rating; nil for the plain average.
        public let userRatingTint: UserRatingTint?
        /// The posted date is struck through: the site expunged the gallery.
        public let isExpunged: Bool
        /// The favorites slot the row's date box is bordered in, when the colour is a known one.
        public let favoriteTagIndex: Int?
        /// The favorites slot's name, the title of the date box; nil when the gallery is not a favorite.
        public let favoriteTagName: String?
    }

    /// The eight fields of a gallery detail page's info panel, as raw strings.
    ///
    /// The panel is scraped by matching row labels, so the fields arrive in no guaranteed order and
    /// the parser fills them one at a time. Naming them beats the positional `[String]` this used to
    /// be: the slots were addressed by bare literal indices at eleven write sites and eight read
    /// sites, and nothing tied slot 4 to the file size other than the reader's memory.
    struct InfoPanel {
        let postedDate: String
        let parentURL: String
        let visibility: String
        let language: String
        let fileSize: String
        let sizeType: String
        let pageCount: String
        let favoritedCount: String
    }

    /// A gallery's title link, carrying the identifiers already extracted from its URL.
    struct GalleryTitleInfo {
        let title: String
        let url: URL
        let gid: String
        let token: String
    }

    public struct GalleryNormalImageInfo {
        public let index: Int
        public let imageURL: URL
        public let originalImageURL: URL?
    }

    public struct RatingResult {
        public let imgRating: Float
        public let textRating: Float?
        public let containsUserRating: Bool
        /// The colour class (`irr`, `irg`, `irb`) of the user's own rating; nil for the plain average.
        public let userRatingTint: UserRatingTint?
    }

    public struct PreviewConfigInfo {
        public let plainURL: URL
        public let size: CGSize
        public let offset: CGSize
    }

    public struct SelectionOption {
        public let name: String
        public let value: String
        public let isSelected: Bool
    }

    public struct ThumbnailSizeOption {
        public let value: Int
        public let isEnabled: Bool
        public let isSelected: Bool
    }
}
