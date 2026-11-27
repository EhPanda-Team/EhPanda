import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import HapticsClient
import MyTagEditor
import MyTagsClient
import Resources
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

// The My Tags page when the site answers as signed out (quick 261126-wzf): a read, a write and Edit Tag's request show
// Log In instead of the error or an alert, and a sign-in reads every set again. The tags, sets and credentials are
// invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsSessionTests {
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])
    private static let response = MyTagsResponse(
        myTags: MyTags(tagSets: [set1, set2]), apiuid: 1234567, apikey: "0123456789abcdef"
    )

    // A read answered as signed out shows Log In rather than the error, and the next read starts by loading, which
    // clears it (W-5).
    @MainActor
    @Test
    func aReadAnsweredAsSignedOutShowsLogInUntilAReadSucceeds() async {
        let reads = LockIsolated(0)
        let store = makeStore {
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) -> MyTagsResponse in
                reads.withValue({ $0 += 1 })
                guard reads.value > 1 else { throw .loginRequired }
                return Self.response
            }
        }

        await store.send(.fetchMyTags) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchMyTagsDone.failure) {
            $0.loadingState = .failed(.loginRequired)
        }
        #expect(store.state.isSessionExpired)
        #expect(store.state.alert == nil)

        await store.send(.fetchMyTags) {
            $0.loadingState = .loading
        }
        #expect(!store.state.isSessionExpired)
        await store.receive(\.fetchMyTagsDone.success) {
            $0.loadingState = .idle
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
    }

    // A chosen set's read answered as signed out shows Log In too (W-5).
    @MainActor
    @Test
    func aSetsReadAnsweredAsSignedOutShowsLogIn() async {
        let store = makeStore {
            $0.fetchTagSet = { (_: GalleryHost, _: Int) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
        }

        await store.send(.tagSetSelected(2)) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.failure) {
            $0.loadingState = .failed(.loginRequired)
        }
        #expect(store.state.isSessionExpired)
    }

    // A write answered as signed out shows Log In and no alert; a write that changed the set at once still puts it
    // back, and the tag set rows are released (W-5).
    @MainActor
    @Test
    func aWriteAnsweredAsSignedOutShowsLogInWithoutAnAlert() async {
        let off = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [Self.glasses])
        let store = makeStore {
            $0.updateTagSet = { (_: GalleryHost, _: Int, _: Bool, _: SiteColor?) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
        }

        await store.send(.enabledChanged(false)) {
            $0.confirmedTagSet = Self.set1
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [off, Self.set2]) })
        }
        await store.receive(\.updateTagSetDone) {
            $0.confirmedTagSet = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
            $0.loadingState = .failed(.loginRequired)
        }

        await store.send(.removeSwiped(Self.glasses))
        await store.receive(\.removeTagDone)

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Fixture Holds")) {
            $0.newTagSetName = "Fixture Holds"
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
            $0.isChangingTagSets = true
        }
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
        }
        #expect(store.state.isSessionExpired)
        #expect(store.state.alert == nil)
    }

    // Edit Tag keeps its alert, and the page beneath shows Log In (W-5).
    @MainActor
    @Test
    func editTagsEndedSessionShowsLogInBeneathIt() async {
        let store = makeStore(credentials: true)
        store.exhaustivity = .off

        await store.send(.tagTapped(Self.glasses))
        await store.send(.destination(.presented(.editor(.delegate(.signedOut)))))
        #expect(store.state.isSessionExpired)
        #expect(store.state.destination?.editor != nil)
    }

    // Log In opens the login page; once it is done, the My Tags page on the stack reads every set again, whatever its
    // cookies said before (W-5).
    @MainActor
    @Test
    func aSignInReadsTheMyTagsPageOnTheStackAgain() async throws {
        var state = SettingReducer.State()
        state.path.append(.myTags(.init()))
        let store = TestStore(initialState: state, reducer: SettingReducer.init) {
            $0.analyticsClient = .noop
            $0.cookieClient = .noop
            $0.hapticsClient = .noop
            $0.myTagsClient.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
        }
        store.exhaustivity = .off
        let myTagsID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: myTagsID, action: .myTags(.delegate(.pushLogin)))))
        let loginID = try #require(store.state.path.ids.last)
        #expect(store.state.path[id: loginID]?.is(\.login) == true)
        await store.send(.path(.element(id: loginID, action: .login(.loginDone(.success(nil))))))
        await store.receive(\.path[id: myTagsID].myTags.fetchMyTags)
        await store.receive(\.path[id: myTagsID].myTags.fetchMyTagsDone.success)
        #expect(store.state.user.myTags == Self.response.myTags)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    private func makeStore(
        credentials: Bool = false,
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        var state = MyTagsFeature.State()
        state.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
        if credentials {
            state.apiuid = 1234567
            state.apikey = "0123456789abcdef"
        }
        return TestStore(initialState: state, reducer: MyTagsFeature.init) {
            $0.myTagsClient = myTagsClient
        }
    }

    /// The New Tag Set alert as N-2 and N-3 of quick 261126-pfh specify it.
    private static var newTagSetAlert: AppAlertState<MyTagsFeature.NewTagSetAlert> {
        AppAlertState(
            title: {
                TextState(localized: .myTagsNewTagSetTitle)
            },
            textField: AppAlertTextFieldState(
                placeholder: TextState(localized: .myTagsNewTagSetName),
                requiresText: true
            ),
            actions: {
                ButtonState(action: .create) {
                    TextState(localized: .myTagsNewTagSetCreate)
                }
                ButtonState(role: .cancel) {
                    TextState(localized: .RLocalizable.cancel)
                }
            },
            message: {
                TextState(localized: .myTagsNewTagSetMessage)
            }
        )
    }
}
