import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// Covers the Blocked Users list (UI-SPEC C-11, C-12; D-14, D-14a): it reads the shared block list, sorts it for
// display, unblocks a name from the shared store with no confirmation, and is empty once the last name goes.
// Every case isolates `@Shared(.blockedCommentAuthors)` in its own in-memory defaults.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it (see 11-22-SUMMARY.md).
@Suite
struct BlockedUsersReducerTests {
    @Test
    func theListIsTheSharedNamesInLocalizedStandardOrder() {
        let defaults = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.blockedCommentAuthors) var blocked
            $blocked.withLock({ $0 = ["zeta", "item10", "Roobubba", "Alpha", "item2", "囧斯诺"] })

            let state = BlockedUsersReducer.State()
            let expected = ["zeta", "item10", "Roobubba", "Alpha", "item2", "囧斯诺"]
                .sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })

            #expect(state.authors == expected)
            // Case-insensitive and numeric, as in Finder: item2 before item10, Alpha before Roobubba before zeta.
            let latin = state.authors.filter({ $0.allSatisfy(\.isASCII) })
            #expect(latin == ["Alpha", "item2", "item10", "Roobubba", "zeta"])
            #expect(!state.isEmpty)
            // Sorting is for display only: the stored list keeps the order users were blocked in.
            #expect(blocked == ["zeta", "item10", "Roobubba", "Alpha", "item2", "囧斯诺"])
        }
    }

    @MainActor
    @Test
    func unblockingRemovesTheNameFromTheSharedStore() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedAuthors.withLock({ $0 = ["Roobubba", "囧斯诺", "Alpha"] })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(author: "囧斯诺")) {
                $0.$blockedAuthors.withLock({ $0 = ["Roobubba", "Alpha"] })
            }

            @Shared(.blockedCommentAuthors) var persisted
            #expect(persisted == ["Roobubba", "Alpha"])
            #expect(store.state.authors == ["Alpha", "Roobubba"])
        }
    }

    @MainActor
    @Test
    func unblockingANameNotInTheListChangesNothing() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedAuthors.withLock({ $0 = ["Roobubba"] })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            // Exact names only: a name differing in case is another user (DD-10).
            await store.send(.unblockTapped(author: "roobubba"))
            #expect(store.state.authors == ["Roobubba"])
        }
    }

    @MainActor
    @Test
    func removingTheLastNameLeavesTheEmptyState() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedAuthors.withLock({ $0 = ["Roobubba", "囧斯诺"] })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(author: "Roobubba")) {
                $0.$blockedAuthors.withLock({ $0 = ["囧斯诺"] })
            }
            #expect(!store.state.isEmpty)

            await store.send(.unblockTapped(author: "囧斯诺")) {
                $0.$blockedAuthors.withLock({ $0 = [] })
            }
            #expect(store.state.isEmpty)
            #expect(store.state.authors.isEmpty)

            @Shared(.blockedCommentAuthors) var persisted
            #expect(persisted.isEmpty)
        }
    }

    @Test
    func nobodyBlockedIsTheEmptyState() {
        withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let state = BlockedUsersReducer.State()
            #expect(state.isEmpty)
            #expect(state.authors.isEmpty)
        }
    }
}
