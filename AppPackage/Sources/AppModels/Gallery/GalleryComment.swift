import Foundation

public struct GalleryComment: Identifiable, Equatable, Codable, Sendable {
    public init(
        votedUp: Bool,
        votedDown: Bool,
        votable: Bool,
        editable: Bool,
        score: String? = nil,
        author: String,
        contents: [CommentContent],
        commentID: String,
        commentDate: Date
    ) {
        self.votedUp = votedUp
        self.votedDown = votedDown
        self.votable = votable
        self.editable = editable
        self.score = score
        self.author = author
        self.contents = contents
        self.commentID = commentID
        self.commentDate = commentDate
    }
    public var id: String { commentID }

    public var votedUp: Bool
    public var votedDown: Bool
    public let votable: Bool
    public let editable: Bool

    public let score: String?
    public let author: String
    public let contents: [CommentContent]
    public let commentID: String
    public let commentDate: Date

    public var plainTextContent: String {
        contents
            .filter { [.plainText, .linkedText, .singleLink].contains($0.type) }
            .compactMap { $0.type == .singleLink ? $0.link?.absoluteString : $0.text }.joined()
    }
}

extension GalleryComment: DateFormattable {
    public var originalDate: Date {
        commentDate
    }
}

public struct CommentContent: Identifiable, Equatable, Codable, Sendable {
    public init(
        id: UUID = .init(),
        type: CommentContentType,
        text: String? = nil,
        link: URL? = nil,
        imgURL: URL? = nil,
        secondLink: URL? = nil,
        secondImgURL: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.link = link
        self.imgURL = imgURL
        self.secondLink = secondLink
        self.secondImgURL = secondImgURL
    }
    public var id: UUID = .init()
    public let type: CommentContentType
    public var text: String?
    public var link: URL?
    public var imgURL: URL?

    public var secondLink: URL?
    public var secondImgURL: URL?
}

public enum CommentContentType: Int, Codable, Sendable {
    case singleImg
    case doubleImg
    case linkedImg
    case doubleLinkedImg

    case plainText
    case linkedText

    case singleLink
}
