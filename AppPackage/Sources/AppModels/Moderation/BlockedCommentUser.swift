/// A comment author the user blocked (DD-10, D-13), held in `@Shared(.blockedCommentUsers)`.
///
/// The block is keyed by the poster's E-Hentai member ID, the digits of the forum contact link the site prints after
/// every comment author's name, because a display name can change and the ID cannot (owner msg 1918). `name` is the
/// display name the author was last seen under, kept for the Blocked Users list; matching never reads it.
public struct BlockedCommentUser: Codable, Equatable, Hashable, Identifiable, Sendable, SchemaVersioned {
    /// This model's schema history (oldest → newest); see `SchemaVersioned` / `VersionedSchema`.
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    /// The v1 base schema; it exists solely to anchor version 1.
    enum SchemaV1: VersionedSchema {
        static let version = 1
        static func migrate(_ object: inout [String: JSONValue]) throws {}
    }

    /// Self-validating (see `SchemaVersion`): a newer value is rejected on decode, which resets the list.
    public var schemaVersion: SchemaVersion<BlockedCommentUser> = 1
    /// The poster's E-Hentai member ID, as digits.
    public let memberID: String
    /// The display name the poster was last seen under.
    public var name: String

    public var id: String { memberID }

    public init(memberID: String, name: String) {
        self.memberID = memberID
        self.name = name
    }
}

// MARK: Manually decode
extension BlockedCommentUser {
    /// Strict, throwing decode: an entry without a member ID of digits, or with an unknown `schemaVersion`, throws,
    /// failing the whole `[BlockedCommentUser]` decode so Sharing resets the list to `[]` rather than keeping an entry
    /// that can never match a comment.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SchemaVersion<BlockedCommentUser>.self, forKey: .schemaVersion)
        memberID = try container.decode(String.self, forKey: .memberID)
        name = try container.decode(String.self, forKey: .name)
        guard !memberID.isEmpty, memberID.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "BlockedCommentUser requires a member ID of digits"
            ))
        }
    }
}

/// The block list's operations (research §5.4).
///
/// The list keeps the order users were blocked in and holds each member ID once. The list stays on this device.
extension Array where Element == BlockedCommentUser {
    /// Adds the poster at the end unless their ID is already blocked. An ID that is empty or not all digits is never
    /// added, as the stored list would fail to decode with it.
    public mutating func block(memberID: String, name: String) {
        guard !memberID.isEmpty, memberID.allSatisfy({ $0.isASCII && $0.isNumber }), !isBlocked(memberID: memberID)
        else { return }
        append(BlockedCommentUser(memberID: memberID, name: name))
    }

    /// Removes the poster with `memberID`, keeping the order of the rest.
    public mutating func unblock(memberID: String) {
        removeAll(where: { $0.memberID == memberID })
    }

    /// Whether the poster with `memberID` is blocked. A comment with no member ID is never blocked.
    public func isBlocked(memberID: String?) -> Bool {
        guard let memberID, !memberID.isEmpty else { return false }
        return contains(where: { $0.memberID == memberID })
    }

    /// The current display names of the blocked posters among `comments` whose name changed, by member ID; empty when
    /// every stored name is current, so a caller writes the list only when something changed.
    public func renamedUsers(in comments: [GalleryComment]) -> [String: String] {
        var renamed = [String: String]()
        for comment in comments {
            guard let memberID = comment.authorMemberID, !comment.author.isEmpty,
                  let user = first(where: { $0.memberID == memberID }), user.name != comment.author
            else { continue }
            renamed[memberID] = comment.author
        }
        return renamed
    }

    /// Stores `names`, current display names by member ID, on the blocked posters they belong to, keeping the order.
    public mutating func updateNames(_ names: [String: String]) {
        self = map { user in
            guard let name = names[user.memberID] else { return user }
            return BlockedCommentUser(memberID: user.memberID, name: name)
        }
    }
}
