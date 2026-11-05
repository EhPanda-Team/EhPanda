@testable import AppModels
import ComposableArchitecture
import Foundation
import Testing

/// The comment block store (DD-10, research §5.4; owner msg 1918): an ordered list of users keyed by E-Hentai member
/// ID, each ID held once with the name it was last seen under, kept on the device under
/// `@Shared(.blockedCommentUsers)`.
struct BlockedCommentUserTests {
    @Test
    func blockingAppendsInOrderAndOnce() {
        var users = [BlockedCommentUser]()

        users.block(memberID: "1", name: "A")
        users.block(memberID: "2", name: "B")
        users.block(memberID: "1", name: "A again")

        #expect(users == [.init(memberID: "1", name: "A"), .init(memberID: "2", name: "B")])
    }

    @Test
    func unblockingRemovesTheIDAndKeepsTheOrder() {
        var users: [BlockedCommentUser] = [
            .init(memberID: "1", name: "A"), .init(memberID: "2", name: "B"), .init(memberID: "3", name: "C")
        ]

        users.unblock(memberID: "1")
        #expect(users.map(\.memberID) == ["2", "3"])

        users.unblock(memberID: "missing")
        #expect(users.map(\.memberID) == ["2", "3"])
    }

    /// Matching reads the member ID only: one name under two IDs is two users, and a renamed user stays blocked.
    @Test
    func matchingIsByMemberIDNeverByName() {
        var users = [BlockedCommentUser]()

        users.block(memberID: "990213", name: "Roobubba")
        users.block(memberID: "4764920", name: "Roobubba")

        #expect(users.count == 2)
        #expect(users.isBlocked(memberID: "990213"))
        #expect(users.isBlocked(memberID: "4764920"))
        #expect(users.isBlocked(memberID: "12") == false)

        users.unblock(memberID: "990213")
        #expect(users == [.init(memberID: "4764920", name: "Roobubba")])
    }

    @Test
    func anEmptyOrNonNumericIDIsNeverBlocked() {
        var users = [BlockedCommentUser]()

        users.block(memberID: "", name: "A")
        users.block(memberID: "abc", name: "B")
        users.block(memberID: "１２", name: "C")

        #expect(users.isEmpty)
        #expect(users.isBlocked(memberID: "") == false)
        #expect(users.isBlocked(memberID: nil) == false)
    }

    /// A blocked ID seen under a new name reports the new name; unchanged names, unblocked IDs and comments without an
    /// ID report nothing, so the caller writes only when a name changed.
    @Test
    func renamedUsersFindsOnlyChangedNamesOfBlockedIDs() {
        let users: [BlockedCommentUser] = [
            .init(memberID: "990213", name: "Roobubba-old"), .init(memberID: "4764920", name: "Pokom")
        ]
        let comments = [
            Self.comment(author: "Roobubba", memberID: "990213"),
            Self.comment(author: "Pokom", memberID: "4764920"),
            Self.comment(author: "Other", memberID: "12"),
            Self.comment(author: "Roobubba-old", memberID: nil),
            Self.comment(author: "", memberID: "4764920")
        ]

        #expect(users.renamedUsers(in: comments) == ["990213": "Roobubba"])
        #expect(users.renamedUsers(in: comments.filter({ $0.author != "Roobubba" })).isEmpty)
    }

    @Test
    func updateNamesRenamesInPlaceAndKeepsTheOrder() {
        var users: [BlockedCommentUser] = [
            .init(memberID: "1", name: "A"), .init(memberID: "2", name: "B"), .init(memberID: "3", name: "C")
        ]

        users.updateNames(["2": "B2", "9": "Nobody"])

        #expect(users.map(\.name) == ["A", "B2", "C"])
        #expect(users.map(\.memberID) == ["1", "2", "3"])
    }

    @Test
    func theListPersistsUnderItsKeyAndStartsEmpty() {
        let defaults = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.blockedCommentUsers) var users
            #expect(users.isEmpty)

            $users.withLock({ $0.block(memberID: "1", name: "A") })
            $users.withLock({ $0.block(memberID: "2", name: "B") })

            @Shared(.blockedCommentUsers) var reopened
            #expect(reopened == [.init(memberID: "1", name: "A"), .init(memberID: "2", name: "B")])
            #expect(defaults.object(forKey: "blockedCommentUsers") != nil)
            #expect(defaults.object(forKey: "blockedCommentAuthors") == nil)
        }
    }

    @Test
    func roundTripsThroughJSON() throws {
        let users: [BlockedCommentUser] = [.init(memberID: "990213", name: "Roobubba")]
        let decoded = try JSONDecoder().decode([BlockedCommentUser].self, from: JSONEncoder().encode(users))
        #expect(decoded == users)
    }

    /// An entry that could never match a comment, or from a newer schema, fails the whole list's decode.
    @Test(arguments: [
        #"[{"schemaVersion": 1, "memberID": "", "name": "A"}]"#,
        #"[{"schemaVersion": 1, "memberID": "abc", "name": "A"}]"#,
        #"[{"schemaVersion": 1, "name": "A"}]"#,
        #"[{"schemaVersion": 99, "memberID": "1", "name": "A"}]"#,
        #"["Roobubba"]"#
    ])
    func decodingRejectsAnEntryWithoutAUsableID(json: String) {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode([BlockedCommentUser].self, from: Data(json.utf8))
        }
    }
}

private extension BlockedCommentUserTests {
    static func comment(author: String, memberID: String?) -> GalleryComment {
        GalleryComment(
            votedUp: false, votedDown: false, votable: false, editable: false,
            author: author, authorMemberID: memberID, contents: [],
            commentID: UUID().uuidString, commentDate: .distantPast
        )
    }
}
