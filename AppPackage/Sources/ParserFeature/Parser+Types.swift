import Foundation
import AppModels

extension Parser {
    public struct ThumbnailPanelInfo {
        public let coverURL: URL
        public let category: AppModels.Category
        public let rating: Float
        public let publishedDate: Date
        public let pageCount: Int
        public let uploader: String?
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
