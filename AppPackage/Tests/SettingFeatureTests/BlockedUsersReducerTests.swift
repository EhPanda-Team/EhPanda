import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// Covers the Blocked Users list (UI-SPEC C-11, C-12; D-14, D-14a; owner msg 1918): it reads the shared block list,
// sorts it by the names users were last seen under for display, unblocks a user by member ID from the shared store
// with no confirmation, and is empty once the last user goes.
// Every case isolates `@Shared(.blockedCommentUsers)` in its own in-memory defaults.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it (see 11-22-SUMMARY.md).
@Suite
struct BlockedUsersReducerTests {
    @Test
    func theListIsTheSharedUsersInLocalizedStandardOrderOfName() {
        let defaults = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let names = ["zeta", "item10", "Roobubba", "Alpha", "item2", "囧斯诺"]
            let users = Self.users(names)
            @Shared(.blockedCommentUsers) var blocked
            $blocked.withLock({ $0 = users })

            let state = BlockedUsersReducer.State()
            let expected = names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })

            #expect(state.users.map(\.name) == expected)
            // Case-insensitive and numeric, as in Finder: item2 before item10, Alpha before Roobubba before zeta.
            let latin = state.users.map(\.name).filter({ $0.allSatisfy(\.isASCII) })
            #expect(latin == ["Alpha", "item2", "item10", "Roobubba", "zeta"])
            #expect(!state.isEmpty)
            // Sorting is for display only: the stored list keeps the order users were blocked in.
            #expect(blocked == users)
        }
    }

    /// Two users under one name are two rows, ordered by member ID.
    @Test
    func twoUsersUnderOneNameAreTwoRowsInIDOrder() {
        withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            @Shared(.blockedCommentUsers) var blocked
            $blocked.withLock({
                $0 = [.init(memberID: "990213", name: "Same"), .init(memberID: "12", name: "Same")]
            })

            let state = BlockedUsersReducer.State()
            #expect(state.users.map(\.memberID) == ["12", "990213"])
        }
    }

    @MainActor
    @Test
    func unblockingRemovesTheUserFromTheSharedStore() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedUsers.withLock({ $0 = Self.users(["Roobubba", "囧斯诺", "Alpha"]) })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(memberID: "2")) {
                $0.$blockedUsers.withLock({
                    $0 = [.init(memberID: "1", name: "Roobubba"), .init(memberID: "3", name: "Alpha")]
                })
            }

            @Shared(.blockedCommentUsers) var persisted
            #expect(persisted.map(\.memberID) == ["1", "3"])
            #expect(store.state.users.map(\.name) == ["Alpha", "Roobubba"])
        }
    }

    @MainActor
    @Test
    func unblockingAnIDNotInTheListChangesNothing() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedUsers.withLock({ $0 = Self.users(["Roobubba"]) })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            // The member ID is the user (owner msg 1918): another ID changes nothing.
            await store.send(.unblockTapped(memberID: "2"))
            #expect(store.state.users.map(\.name) == ["Roobubba"])
        }
    }

    // Unblocking from the list reports it once, as the list's surface (20-12). The name and the member ID are the
    // user's; neither can ride along, and the probes in the stored list prove it.
    @MainActor
    @Test
    func unblockingFromTheListSendsOneSignalWithNoUserContent() async {
        let defaults = UserDefaults.inMemory
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedUsers.withLock({
                $0 = [.init(memberID: Self.probeMemberID, name: Self.probeName), .init(memberID: "2", name: "Other")]
            })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(memberID: Self.probeMemberID)) {
                $0.$blockedUsers.withLock({ $0 = [.init(memberID: "2", name: "Other")] })
            }
            await store.finish()

            #expect(recorded.value == [.commentPosterUnblocked(from: .blockedUsers)])
            let leaves = Mirror(reflecting: recorded.value).leafRenderings
            #expect(leaves.contains(where: { $0.contains(Self.probeName) || $0.contains(Self.probeMemberID) }) == false)
        }
    }

    // Nothing is unblocked for an ID that is not in the list, so nothing is reported.
    @MainActor
    @Test
    func unblockingAnIDNotInTheListSendsNothing() async {
        let defaults = UserDefaults.inMemory
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedUsers.withLock({ $0 = Self.users(["Roobubba"]) })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(memberID: "2"))
            await store.finish()

            #expect(recorded.value.isEmpty)
        }
    }

    @MainActor
    @Test
    func removingTheLastUserLeavesTheEmptyState() async {
        let defaults = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = BlockedUsersReducer.State()
            state.$blockedUsers.withLock({ $0 = Self.users(["Roobubba", "囧斯诺"]) })
            let store = TestStore(initialState: state, reducer: BlockedUsersReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
            }

            await store.send(.unblockTapped(memberID: "1")) {
                $0.$blockedUsers.withLock({ $0 = [.init(memberID: "2", name: "囧斯诺")] })
            }
            #expect(!store.state.isEmpty)

            await store.send(.unblockTapped(memberID: "2")) {
                $0.$blockedUsers.withLock({ $0 = [] })
            }
            #expect(store.state.isEmpty)
            #expect(store.state.users.isEmpty)

            @Shared(.blockedCommentUsers) var persisted
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
            #expect(state.users.isEmpty)
        }
    }
}

private extension BlockedUsersReducerTests {
    static let probeName = "zqxprobepostername7731"
    static let probeMemberID = "zqxprobememberid7731"

    /// Users named `names`, with member IDs "1", "2", … in that order.
    static func users(_ names: [String]) -> [BlockedCommentUser] {
        names.enumerated().map({ BlockedCommentUser(memberID: String($0.offset + 1), name: $0.element) })
    }
}

private extension AnalyticsClient {
    /// The `LockIsolated` capture idiom: the inert `.noop` client with its `send` replaced by a collector.
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}

// Reproduces `ContentLeakProbe`'s reflection walk, which lives in a target this one cannot import: every stored
// leaf of a value, including ones the public API never exposes.
private extension Mirror {
    var leafRenderings: [String] {
        children.flatMap({ child in
            let nested = Mirror(reflecting: child.value).leafRenderings
            return nested.isEmpty ? [String(describing: child.value)] : nested
        })
    }
}
