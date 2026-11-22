import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import MyTagEditor
import MyTagsClient
import Resources
import Sharing
import Testing

// A tag's My Tags item on Detail (port of PR 462 item 10, design approved 2026-11-22): Add to My Tags opens Add Tag
// for the tag set last chosen, Remove from My Tags removes the tag from that set at once. The tags and sets are
// invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
struct DetailMyTagsTests {
    private static let refusal = "No matching tag found"
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [glasses])

    @MainActor
    @Test
    func addToMyTagsOpensAddTagForTheLastChosenSetWithTheTagFilledIn() async throws {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2))
        store.exhaustivity = .off

        await store.send(.addTagToMyTagsTapped(name: "artist:sample artist"))
        let editor = try #require(store.state.destination?.myTagEditor)
        #expect(editor.name == "artist:sample artist")
        #expect(!editor.isNameEditable)
        #expect(editor.tagSetID == 2)
        #expect(editor.kind == .watched)
    }

    @MainActor
    @Test
    func nothingCachedOpensNothingAndAnAddedTagSaysSo() async {
        let empty = makeStore(myTags: nil)
        await empty.send(.addTagToMyTagsTapped(name: "artist:sample artist"))

        let store = makeStore(myTags: MyTags(tagSets: [Self.set1]))
        store.exhaustivity = .off
        await store.send(.addTagToMyTagsTapped(name: "artist:sample artist"))
        await store.send(.destination(.presented(.myTagEditor(.delegate(.saved)))))
        #expect(store.state.toast == .success(caption: .myTagsAdded))
    }

    @MainActor
    @Test
    func removingRemovesTheTagFromTheLastChosenSetAtOnce() async {
        let calls = LockIsolated<[String]>([])
        let emptied = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2)) {
            $0.removeTags = { (host: GalleryHost, tagIDs: [Int], tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(tagIDs) \(tagSetID)") })
                return Self.page(emptied)
            }
        }

        await store.send(.removeTagFromMyTags(tagID: 101))
        await store.receive(\.removeTagFromMyTagsDone.success) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, emptied], selectedTagSetID: 2) })
            $0.toast = .success(caption: .RLocalizable.myTagsRemoved)
        }
        #expect(calls.value == ["E-Hentai [101] 2"])
    }

    @MainActor
    @Test
    func aRefusedRemoveTakesThePageAndShowsTheAlert() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1])) {
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) in
                Self.page(Self.set1, message: Self.refusal)
            }
        }

        await store.send(.removeTagFromMyTags(tagID: 101))
        await store.receive(\.removeTagFromMyTagsDone.success) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1]) })
            $0.alert = .failure(title: .RLocalizable.myTagsRemoveFailed, message: Self.refusal)
        }
    }

    @MainActor
    @Test
    func aFailedRemoveLeavesTheCacheAndShowsTheAlert() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1])) {
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await store.send(.removeTagFromMyTags(tagID: 101))
        await store.receive(\.removeTagFromMyTagsDone.failure) {
            $0.alert = .failure(
                title: .RLocalizable.myTagsRemoveFailed, message: AppError.networkingFailed.alertText
            )
        }
    }

    @MainActor
    private func makeStore(
        myTags: MyTags?,
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<DetailReducer> {
        let defaults = UserDefaults.inMemory
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        return withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = DetailReducer.State(
                gallery: Gallery(
                    gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                    category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                    coverURL: nil, galleryURL: .mock
                )
            )
            state.$user.withLock({ $0.myTags = myTags })
            return TestStore(initialState: state, reducer: DetailReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = defaults
                $0.myTagsClient = myTagsClient
            }
        }
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
