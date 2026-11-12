public import Foundation

public struct GalleryComment: Identifiable, Equatable, Codable, Sendable {
    public init(
        votedUp: Bool,
        votedDown: Bool,
        votable: Bool,
        editable: Bool,
        score: String? = nil,
        author: String,
        authorMemberID: String? = nil,
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
        self.authorMemberID = authorMemberID
        self.contents = contents
        self.commentID = commentID
        self.commentDate = commentDate
    }
    public var id: String { commentID }

    public var votedUp: Bool
    public var votedDown: Bool
    public let votable: Bool
    public let editable: Bool

    /// The score as the site prints it: signed, so `+113` or `-3`, and `0` at zero.
    public var score: String?
    public let author: String
    /// The poster's E-Hentai member ID, from the forum contact link the site prints after the name; `nil` when the
    /// comment has none. Comment blocking matches on it, never on the name, which can change (owner msg 1918).
    public let authorMemberID: String?
    public let contents: [CommentContent]
    public let commentID: String
    public let commentDate: Date

    /// The score text the site prints for `score`: a plus sign before a positive one, so it reads like the parsed one.
    public static func scoreText(_ score: Int) -> String {
        score > 0 ? "+\(score)" : String(score)
    }

    /// Applies a vote's outcome: `vote` is the site's own vote state for the signed-in user, `1` up, `-1` down, `0`
    /// none, and `score` the comment's new score.
    public mutating func applyVote(score: Int, vote: Int) {
        self.score = Self.scoreText(score)
        votedUp = vote > 0
        votedDown = vote < 0
    }

    public var plainTextContent: String {
        contents
            .filter({ [.plainText, .linkedText, .singleLink].contains($0.type) })
            .compactMap({ content in
                content.type == .singleLink ? content.link?.absoluteString : content.text.map({ String($0.characters) })
            })
            .joined()
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
        text: AttributedString? = nil,
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
    /// The run's text, carrying the author's bold, italic, underline and strikethrough as attributes.
    public var text: AttributedString?
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
