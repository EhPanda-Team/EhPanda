@testable import AppModels
import ComposableArchitecture
import Foundation
import Testing

/// The comment block store (DD-10, research §5.4): an ordered, de-duplicated list of exact author names, kept on the
/// device under `@Shared(.blockedCommentAuthors)`.
struct BlockedCommentAuthorsTests {
    @Test
    func blockingAppendsInOrderAndOnce() {
        var authors = [String]()

        authors.block(author: "A")
        authors.block(author: "B")
        authors.block(author: "A")

        #expect(authors == ["A", "B"])
    }

    @Test
    func unblockingRemovesTheNameAndKeepsTheOrder() {
        var authors = ["A", "B", "C"]

        authors.unblock(author: "A")
        #expect(authors == ["B", "C"])

        authors.unblock(author: "missing")
        #expect(authors == ["B", "C"])
    }

    @Test
    func namesAreExact() {
        var authors = [String]()

        authors.block(author: "Name")
        authors.block(author: "name")
        authors.block(author: " Name ")

        #expect(authors == ["Name", "name", " Name "])
        #expect(authors.isBlocked(author: "Name"))
        #expect(authors.isBlocked(author: "NAME") == false)
        #expect(authors.isBlocked(author: "Name ") == false)

        authors.unblock(author: "name")
        #expect(authors == ["Name", " Name "])
    }

    @Test
    func anEmptyNameIsNeverBlocked() {
        var authors = [String]()

        authors.block(author: "")

        #expect(authors.isEmpty)
        #expect(authors.isBlocked(author: "") == false)
    }

    @Test
    func theListPersistsUnderItsKeyAndStartsEmpty() {
        let defaults = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.blockedCommentAuthors) var authors
            #expect(authors.isEmpty)

            $authors.withLock({ $0.block(author: "A") })
            $authors.withLock({ $0.block(author: "B") })

            @Shared(.blockedCommentAuthors) var reopened
            #expect(reopened == ["A", "B"])
            #expect(defaults.stringArray(forKey: "blockedCommentAuthors") == ["A", "B"])
        }
    }
}
