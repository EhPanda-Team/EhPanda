import Foundation

public enum GalleryURLParser {
    public struct Route: Equatable, Sendable {
        public let url: URL
        public let gid: String
        public let pageIndex: Int?
        public let commentID: String?
        public let isGalleryImageURL: Bool

        public init(
            url: URL,
            gid: String,
            pageIndex: Int?,
            commentID: String?,
            isGalleryImageURL: Bool
        ) {
            self.url = url
            self.gid = gid
            self.pageIndex = pageIndex
            self.commentID = commentID
            self.isGalleryImageURL = isGalleryImageURL
        }
    }

    public static func parse(_ url: URL) -> Route? {
        nil
    }

    public static func isMPVURL(_ url: URL?) -> Bool {
        url?.pathComponents.dropFirst().first == "mpv"
    }
}
