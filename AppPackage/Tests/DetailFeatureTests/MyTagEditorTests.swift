import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import MyTagEditor
import MyTagsClient
import Resources
import Sharing
import Testing
import TestingSupport

// Add Tag and Edit Tag (port of PR 462 item 10, design approved 2026-11-22): what can be confirmed, the requests, the
// cache, the alert on the control that failed, and the outcome the host is told. The tags and sets are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagEditorTests {
    private static let refusal = "No matching tag found"
    private static let slate = SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0)
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let artist = MyTag(
        id: 201, name: "artist:sample artist", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: slate, tags: [])

    @MainActor
    @Test
    func aNewTagStartsWatchedAtTheDefaultWeightAndNeedsAName() {
        var state = MyTagEditorFeature.State(tagSet: Self.set2)
        #expect(state.kind == .watched)
        #expect(state.weight == MyTag.defaultWeight)
        #expect(state.color == nil)
        #expect(!state.canConfirm)
        state.name = "  "
        #expect(!state.canConfirm)
        state.name = "artist:sample artist"
        #expect(state.canConfirm)
        state.wellColor = Self.green.color
        #expect(state.color == Self.green)
    }

    @MainActor
    @Test
    func addingSendsTheTagTakesThePageAndCloses() async {
        let calls = LockIsolated<[String]>([])
        let dismissed = LockIsolated(0)
        let added = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: Self.slate, tags: [Self.artist])
        let store = makeStore(
            state: { MyTagEditorFeature.State(tagSet: Self.set2) },
            dismissed: dismissed
        ) {
            $0.addTag = { (host: GalleryHost, tag: MyTagDraft, tagSetID: Int) async throws(AppError) in
                let color = tag.color?.hex ?? ""
                let call = "\(host.rawValue) \(tag.name) \(tag.kind) \(color) \(tag.weight) \(tagSetID)"
                calls.withValue({ $0.append(call) })
                return Self.page(added)
            }
        }

        await store.send(.binding(.set(\.name, " artist:sample artist "))) {
            $0.name = " artist:sample artist "
        }
        await store.send(.binding(.set(\.weight, -5))) {
            $0.weight = -5
        }
        await store.send(.confirmTapped) {
            $0.running = .confirm
        }
        await store.receive(\.addDone.success) {
            $0.running = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, added]) })
        }
        await store.receive(\.delegate.saved)
        #expect(calls.value == ["E-Hentai artist:sample artist watched  -5 2"])
        #expect(dismissed.value == 1)
    }

    @MainActor
    @Test
    func aRefusedAddStaysOpenWithTheAlertOnConfirm() async {
        let dismissed = LockIsolated(0)
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(adding: "artist:no such tag", isNameEditable: false, tagSet: Self.set1)
            },
            dismissed: dismissed
        ) {
            $0.addTag = { (_: GalleryHost, _: MyTagDraft, _: Int) async throws(AppError) in
                Self.page(Self.set1, message: Self.refusal)
            }
        }

        await store.send(.confirmTapped) {
            $0.running = .confirm
        }
        await store.receive(\.addDone.success) {
            $0.running = nil
            $0.alertSource = .confirm
            $0.alert = .failure(title: .RLocalizable.myTagsSaveFailed, message: Self.refusal)
        }
        #expect(dismissed.value == 0)
    }

    @MainActor
    @Test
    func anEditCanBeConfirmedOnceSomethingChanged() {
        var state = MyTagEditorFeature.State(
            editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
        )
        #expect(!state.isAdding)
        #expect(!state.isNameEditable)
        #expect(!state.canConfirm)
        state.weight = 11
        #expect(state.canConfirm)
        state.weight = 10
        #expect(!state.canConfirm)
        state.kind = .hidden
        #expect(state.canConfirm)
    }

    @MainActor
    @Test
    func anAcceptedEditChangesTheCachedTagAndCloses() async {
        let calls = LockIsolated<[String]>([])
        let dismissed = LockIsolated(0)
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            },
            dismissed: dismissed
        ) {
            $0.updateTag = { (host: GalleryHost, apiuid: Int, apikey: String, tag: MyTag) async throws(AppError) in
                let color = tag.color?.hex ?? ""
                let call = "\(host.rawValue) \(apiuid) \(apikey) \(tag.id) \(tag.kind) \(color) \(tag.weight)"
                calls.withValue({ $0.append(call) })
                return .accepted
            }
        }
        var edited = Self.glasses
        edited.kind = .hidden
        edited.color = Self.slate

        await store.send(.binding(.set(\.kind, .hidden))) {
            $0.kind = .hidden
        }
        await store.send(.binding(.set(\.color, Self.slate))) {
            $0.color = Self.slate
        }
        await store.send(.confirmTapped) {
            $0.running = .confirm
        }
        await store.receive(\.updateDone) {
            $0.running = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [
                MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [edited]), Self.set2
            ]) })
        }
        await store.receive(\.delegate.saved)
        #expect(calls.value == ["E-Hentai 1234567 0123456789abcdef 101 hidden #A0B0C0 10"])
        #expect(dismissed.value == 1)
    }

    @MainActor
    @Test
    func aRefusedEditStaysOpenWithTheSitesReason() async {
        let dismissed = LockIsolated(0)
        let reason = "Weight must be between 99 and -99"
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            },
            dismissed: dismissed
        ) {
            $0.updateTag = { (_: GalleryHost, _: Int, _: String, _: MyTag) async throws(AppError) in
                .refused(reason)
            }
        }

        await store.send(.binding(.set(\.weight, 99))) {
            $0.weight = 99
        }
        await store.send(.confirmTapped) {
            $0.running = .confirm
        }
        await store.receive(\.updateDone) {
            $0.running = nil
            $0.alertSource = .confirm
            $0.alert = .failure(title: .RLocalizable.myTagsSaveFailed, message: reason)
        }
        #expect(dismissed.value == 0)
    }

    @MainActor
    @Test
    func removingTakesThePageAndCloses() async {
        let calls = LockIsolated<[String]>([])
        let dismissed = LockIsolated(0)
        let emptied = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            },
            dismissed: dismissed
        ) {
            $0.removeTags = { (_: GalleryHost, tagIDs: [Int], tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("\(tagIDs) \(tagSetID)") })
                return Self.page(emptied)
            }
        }

        await store.send(.removeTapped) {
            $0.running = .remove
        }
        await store.receive(\.removeDone.success) {
            $0.running = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [emptied, Self.set2]) })
        }
        await store.receive(\.delegate.removed)
        #expect(calls.value == ["[101] 1"])
        #expect(dismissed.value == 1)
    }

    @MainActor
    @Test
    func aFailedRemoveStaysOpenWithTheAlertOnRemove() async {
        let dismissed = LockIsolated(0)
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            },
            dismissed: dismissed
        ) {
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await store.send(.removeTapped) {
            $0.running = .remove
        }
        await store.receive(\.removeDone.failure) {
            $0.running = nil
            $0.alertSource = .remove
            $0.alert = .failure(
                title: .RLocalizable.myTagsRemoveFailed, message: AppError.networkingFailed.alertText
            )
        }
        #expect(dismissed.value == 0)
    }

    @MainActor
    private func makeStore(
        state: () -> MyTagEditorFeature.State,
        dismissed: LockIsolated<Int>,
        client: (inout MyTagsClient) -> Void
    ) -> TestStoreOf<MyTagEditorFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        let initial = state()
        initial.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
        return TestStore(initialState: initial, reducer: MyTagEditorFeature.init) {
            $0.dismiss = DismissEffect { dismissed.withValue({ $0 += 1 }) }
            $0.myTagsClient = myTagsClient
        }
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
