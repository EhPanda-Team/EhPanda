import Foundation
import AppModels

extension Parser {
    struct ThumbnailPanelInfo {
        let coverURL: URL
        let category: AppModels.Category
        let rating: Float
        let publishedDate: Date
        let pageCount: Int
        let uploader: String?
    }

    struct GalleryNormalImageInfo {
        let index: Int
        let imageURL: URL
        let originalImageURL: URL?
    }

    struct RatingResult {
        let imgRating: Float
        let textRating: Float?
        let containsUserRating: Bool
    }

    struct PreviewConfigInfo {
        let plainURL: URL
        let size: CGSize
        let offset: CGSize
    }

    struct SelectionOption {
        let name: String
        let value: String
        let isSelected: Bool
    }

    struct ThumbnailSizeOption {
        let value: Int
        let isEnabled: Bool
        let isSelected: Bool
    }
}
