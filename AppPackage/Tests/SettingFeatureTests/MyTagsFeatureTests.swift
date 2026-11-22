import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import MyTagEditor
import MyTagsClient
import Resources
@testable import SettingFeature
import Sharing
import Testing

// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): reading, choosing a tag set, its Enabled flag
// and default colour, Add Tag and Edit Tag, removing, the site's page as the fallback, and the Account row that opens
// it. The tags, sets and credentials are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
struct MyTagsFeatureTests {
    private static let refusal = "No matching tag found"
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let slate = SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [])
    private static let response = MyTagsResponse(
        myTags: MyTags(tagSets: [set1, set2]), apiuid: 1234567, apikey: "0123456789abcdef"
    )

    @MainActor
    // The shared user is a reference: the read's answer can land before the read's own step is asserted, so this
    // test checks the end state rather than each step.
    @Test
    func presentingSignedInReadsEveryTagSetAndKeepsTheChoice() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1], selectedTagSetID: 2)) {
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
        }
        store.exhaustivity = .off

        await store.send(.onPresented)
        await store.receive(\.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.success)
        #expect(store.state.loadingState == .idle)
        #expect(store.state.apiuid == 1234567)
        #expect(store.state.apikey == "0123456789abcdef")
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2))
    }

    @MainActor
    @Test
    func presentingSignedOutReadsNothing() async {
        let store = makeStore(myTags: nil, signedIn: false)

        await store.send(.onPresented)
    }

    @MainActor
    @Test
    func aFailedReadShowsTheError() async {
        let store = makeStore(myTags: nil) {
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) -> MyTagsResponse in throw .networkingFailed }
        }

        await store.send(.fetchMyTags) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchMyTagsDone.failure) {
            $0.loadingState = .failed(.networkingFailed)
        }
    }

    @MainActor
    @Test
    func choosingATagSetKeepsTheChoiceAndReadsThatSet() async {
        let calls = LockIsolated<[String]>([])
        let read = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: Self.green, tags: [Self.glasses])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.fetchTagSet = { (host: GalleryHost, tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(tagSetID)") })
                return Self.page(read)
            }
        }

        await store.send(.tagSetSelected(2)) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.success) {
            $0.loadingState = .idle
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, read], selectedTagSetID: 2) })
        }
        await store.send(.tagSetSelected(2))
        #expect(calls.value == ["E-Hentai 2"])
    }

    @MainActor
    @Test
    func pullToRefreshReadsTheChosenSetWithoutTheLoadingView() async {
        let emptied = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.fetchTagSet = { (_: GalleryHost, _: Int) async throws(AppError) in Self.page(emptied) }
        }

        await store.send(.refresh)
        await store.receive(\.fetchTagSetDone.success) {
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [emptied, Self.set2]) })
        }
    }

    @MainActor
    @Test
    func turningATagSetOffSendsItAtOnceAndTakesThePage() async {
        let calls = LockIsolated<[String]>([])
        let off = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [Self.glasses])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.updateTagSet = { (host, tagSetID, isEnabled, color) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(tagSetID) \(isEnabled) \(color?.hex ?? "")") })
                return Self.page(off)
            }
        }

        await store.send(.enabledChanged(false)) {
            $0.confirmedTagSet = Self.set1
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [off, Self.set2]) })
        }
        await store.receive(\.updateTagSetDone) {
            $0.confirmedTagSet = nil
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        #expect(calls.value == ["E-Hentai 1 false "])
    }

    @MainActor
    @Test
    func aFailedTagSetChangePutsTheSetBackWithTheAlertOnItsControl() async {
        let off = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [Self.glasses])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.updateTagSet = { (_: GalleryHost, _: Int, _: Bool, _: SiteColor?) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await store.send(.enabledChanged(false)) {
            $0.confirmedTagSet = Self.set1
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [off, Self.set2]) })
        }
        await store.receive(\.updateTagSetDone) {
            $0.confirmedTagSet = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
            $0.alertSource = .enabled
            $0.alert = .failure(title: .RLocalizable.myTagsSaveFailed, message: AppError.networkingFailed.alertText)
        }
    }

    @MainActor
    @Test
    func aDefaultColourWaitsForTheLastChangeAndIsSentOnce() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let green1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: Self.green, tags: [Self.glasses])
        let slate1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: Self.slate, tags: [Self.glasses])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]), clock: clock) {
            $0.updateTagSet = { (_, tagSetID, isEnabled, color) async throws(AppError) in
                calls.withValue({ $0.append("\(tagSetID) \(isEnabled) \(color?.hex ?? "")") })
                return Self.page(slate1)
            }
        }

        await store.send(.defaultColorChanged(Self.green)) {
            $0.confirmedTagSet = Self.set1
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [green1, Self.set2]) })
        }
        await store.send(.defaultWellColorChanged(Self.slate.color)) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [slate1, Self.set2]) })
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.updateTagSetDone) {
            $0.confirmedTagSet = nil
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        #expect(calls.value == ["1 true #A0B0C0"])
    }

    @MainActor
    @Test
    func addTagOpensAnEmptyAddTagForTheChosenSet() async throws {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2))
        store.exhaustivity = .off

        await store.send(.addTagTapped)
        let editor = try #require(store.state.destination?.editor)
        #expect(editor.isAdding)
        #expect(editor.isNameEditable)
        #expect(editor.name.isEmpty)
        #expect(editor.tagSetID == 2)
        #expect(editor.tagSetColor == Self.green)
    }

    @MainActor
    @Test
    func aRowOpensEditTagOnlyOnceTheCredentialsAreRead() async throws {
        let unread = makeStore(myTags: MyTags(tagSets: [Self.set1]))
        await unread.send(.tagTapped(Self.glasses))

        let store = makeStore(myTags: MyTags(tagSets: [Self.set1]), credentials: true)
        store.exhaustivity = .off
        await store.send(.tagTapped(Self.glasses))
        let editor = try #require(store.state.destination?.editor)
        #expect(editor.mode == .edit(Self.glasses, apiuid: 1234567, apikey: "0123456789abcdef"))
    }

    @MainActor
    @Test
    func swipingRemovesTheTagAtOnceAndTakesThePage() async {
        let calls = LockIsolated<[String]>([])
        let emptied = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.removeTags = { (host: GalleryHost, tagIDs: [Int], tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(tagIDs) \(tagSetID)") })
                return Self.page(emptied)
            }
        }

        await store.send(.removeSwiped(Self.glasses))
        await store.receive(\.removeTagDone) {
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [emptied, Self.set2]) })
        }
        #expect(calls.value == ["E-Hentai [101] 1"])
    }

    @MainActor
    @Test
    func aRefusedRemoveShowsTheAlertOnTheRow() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) in
                Self.page(Self.set1, message: Self.refusal)
            }
        }

        await store.send(.removeSwiped(Self.glasses))
        await store.receive(\.removeTagDone) {
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .tag(101)
            $0.alert = .failure(title: .RLocalizable.myTagsRemoveFailed, message: Self.refusal)
        }
    }

    @MainActor
    @Test
    func removingInEditTagSaysRemoved() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1]), credentials: true)
        store.exhaustivity = .off

        await store.send(.tagTapped(Self.glasses))
        await store.send(.destination(.presented(.editor(.delegate(.removed)))))
        #expect(store.state.toast == .success(caption: .RLocalizable.myTagsRemoved))
    }

    @MainActor
    @Test
    func closingTheSitesPageReadsMyTagsAgain() async throws {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1])) {
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
        }
        store.exhaustivity = .off

        await store.send(.openInBrowserTapped)
        #expect(store.state.destination?.browser == URL(string: "https://e-hentai.org/mytags"))
        await store.send(.browserChanged(nil))
        await store.receive(\.fetchMyTags)
        await store.receive(\.fetchMyTagsDone.success)
        #expect(store.state.destination == nil)
    }

    // The Account screen's My Tags row opens the native page, which reads My Tags on presentation.
    @MainActor
    @Test
    func theAccountRowPushesThePageWhichReads() async throws {
        let defaults = UserDefaults.inMemory
        let store = withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            var state = SettingReducer.State()
            state.path.append(.account(.init()))
            return TestStore(initialState: state, reducer: SettingReducer.init) {
                $0.analyticsClient = .noop
                $0.cookieClient = .previewLoggedIn
                $0.defaultAppStorage = defaults
                $0.myTagsClient.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
            }
        }
        store.exhaustivity = .off
        let accountID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: accountID, action: .account(.delegate(.pushMyTags)))))
        let id = try #require(store.state.path.ids.last)
        #expect(store.state.path.count == 2)
        #expect(store.state.path[id: id]?.is(\.myTags) == true)
        await store.receive(\.path[id: id].myTags.onPresented)
        await store.receive(\.path[id: id].myTags.fetchMyTagsDone.success)
        #expect(store.state.user.myTags == Self.response.myTags)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    private func makeStore(
        myTags: MyTags?,
        signedIn: Bool = true,
        credentials: Bool = false,
        clock: any Clock<Duration> = TestClock(),
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        let defaults = UserDefaults.inMemory
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        return withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            var state = MyTagsFeature.State()
            state.$user.withLock({ $0.myTags = myTags })
            if credentials {
                state.apiuid = 1234567
                state.apikey = "0123456789abcdef"
            }
            return TestStore(initialState: state, reducer: MyTagsFeature.init) {
                $0.continuousClock = clock
                $0.cookieClient = signedIn ? .previewLoggedIn : .noop
                $0.defaultAppStorage = defaults
                $0.myTagsClient = myTagsClient
            }
        }
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
