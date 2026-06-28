import AppTools
import SwiftUI
import Foundation

public struct GalleryState: Codable, Sendable {
    public static let empty = GalleryState(gid: "")
    public static let preview = GalleryState(gid: "")

    public let gid: String
    public var tags = [GalleryTag]()
    public var readingProgress = 0
    public var previewURLs = [Int: URL]()
    public var previewConfig: PreviewConfig?
    public var comments = [GalleryComment]()
    public var imageURLs = [Int: URL]()
    public var originalImageURLs = [Int: URL]()
    public var thumbnailURLs = [Int: URL]()

    public init(
        gid: String,
        tags: [GalleryTag] = [GalleryTag](),
        readingProgress: Int = 0,
        previewURLs: [Int: URL] = [Int: URL](),
        previewConfig: PreviewConfig? = nil,
        comments: [GalleryComment] = [GalleryComment](),
        imageURLs: [Int: URL] = [Int: URL](),
        originalImageURLs: [Int: URL] = [Int: URL](),
        thumbnailURLs: [Int: URL] = [Int: URL]()
    ) {
        self.gid = gid
        self.tags = tags
        self.readingProgress = readingProgress
        self.previewURLs = previewURLs
        self.previewConfig = previewConfig
        self.comments = comments
        self.imageURLs = imageURLs
        self.originalImageURLs = originalImageURLs
        self.thumbnailURLs = thumbnailURLs
    }
}
extension GalleryState: CustomStringConvertible {
    public var description: String {
        let params = String(
            describing: [
                "gid": gid,
                "tagsCount": tags.count,
                "readingProgress": readingProgress,
                "previewURLsCount": previewURLs.count,
                "previewConfig": String(describing: previewConfig),
                "commentsCount": comments.count,
                "imageURLsCount": imageURLs.count,
                "originalImageURLsCount": originalImageURLs.count,
                "thumbnailURLsCount": thumbnailURLs.count
            ]
            as [String: Any]
        )
        return "GalleryState(\(params))"
    }
}

public struct GalleryTag: Codable, Equatable, Hashable, Identifiable, Sendable {
    public init(
        rawNamespace: String,
        contents: [Content]
    ) {
        self.rawNamespace = rawNamespace
        self.contents = contents
    }
    public struct Content: Codable, Equatable, Hashable, Identifiable, Sendable {
        public init(
            rawNamespace: String,
            text: String,
            isVotedUp: Bool,
            isVotedDown: Bool,
            textColor: Color? = nil,
            backgroundColor: Color? = nil
        ) {
            self.rawNamespace = rawNamespace
            self.text = text
            self.isVotedUp = isVotedUp
            self.isVotedDown = isVotedDown
            self.textColor = textColor
            self.backgroundColor = backgroundColor
        }
        public var id: String { rawNamespace + text }
        public var firstLetterCapitalizedText: String {
            text.firstLetterCapitalized
        }
        public func voteKeyword(tag: GalleryTag) -> String {
            let namespace = tag.namespace?.abbreviation ?? tag.namespace?.rawValue ?? tag.rawNamespace.lowercased()
            return tag.namespace == .temp ? text : [namespace, text].joined(separator: ":")
        }
        public func serachKeyword(tag: GalleryTag) -> String {
            let keyword = text.contains(" ") ? "\"\(text)$\"" : "\(text)$"
            let namespace = tag.namespace?.abbreviation ?? tag.namespace?.rawValue ?? tag.rawNamespace.lowercased()
            return tag.namespace == .temp ? keyword : [namespace, keyword].joined(separator: ":")
        }

        public let rawNamespace: String
        public let text: String
        public let isVotedUp: Bool
        public let isVotedDown: Bool
        public let textColor: Color?
        public let backgroundColor: Color?
    }

    public var id: String { rawNamespace }
    public var namespace: TagNamespace? {
        .init(rawValue: rawNamespace)
    }

    public let rawNamespace: String
    public let contents: [Content]
}

public enum PreviewConfig: Codable, Equatable, Sendable {
    case normal(rows: Int)
    case large(rows: Int)
}

extension PreviewConfig {
    public var batchSize: Int {
        switch self {
        case .normal(let rows):
            return 10 * rows
        case .large(let rows):
            return 5 * rows
        }
    }

    public func pageNumber(index: Int) -> Int {
        max(index - 1, 0) / batchSize
    }
    public func batchRange(index: Int) -> ClosedRange<Int> {
        let lowerBound = pageNumber(index: index) * batchSize + 1
        let upperBound = lowerBound + batchSize - 1
        return lowerBound...upperBound
    }
}
