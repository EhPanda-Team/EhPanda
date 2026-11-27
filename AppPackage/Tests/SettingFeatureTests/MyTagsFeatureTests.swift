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
import TestingSupport

// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): reading, choosing a tag set, its Enabled flag
// and default colour, Add Tag and Edit Tag, removing, New Tag Set (quick 261126-pfh), Delete Tag Set (quick
// 261126-udx), the site's page as the fallback, and the Account row that opens it. The tags, sets and credentials are
// invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsFeatureTests {
    private static let refusal = "No matching tag found"
    private static let createRefusal = "Sample refusal from the site"
    private static let deleteRefusal = "Sample delete refusal from the site"
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let slate = SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [])
    private static let set3 = MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [])
    private static let offeredSet2 = MyTagSet(
        id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [], isDeletable: true
    )
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
        var state = SettingReducer.State()
        state.path.append(.account(.init()))
        let store = TestStore(initialState: state, reducer: SettingReducer.init) {
            $0.analyticsClient = .noop
            $0.cookieClient = .previewLoggedIn
            $0.myTagsClient.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
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
    @Test
    func theRowOpensTheAlertWithAnEmptyName() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]))

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Leftover")) {
            $0.newTagSetName = "Leftover"
        }
        await store.send(.newTagSetAlert(.dismiss)) {
            $0.newTagSetAlert = nil
        }
        await store.send(.newTagSetTapped) {
            $0.newTagSetName = ""
            $0.newTagSetAlert = Self.newTagSetAlert
        }
    }

    // The alert's field holds Create until a name is typed, and never Cancel (N-3); an alert whose field does not
    // ask for it, as the page jump's, holds nothing.
    @MainActor
    @Test
    func createWaitsForANameAndCancelNeverWaits() async throws {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1]))
        store.exhaustivity = .off

        await store.send(.newTagSetTapped)
        let alert = try #require(store.state.newTagSetAlert)
        let field = try #require(alert.textField)
        let createButton = try #require(alert.buttons.first(where: { $0.role == nil }))
        let cancelButton = try #require(alert.buttons.first(where: { $0.role == .cancel }))
        for blank in ["", "   ", " \n\t "] {
            #expect(!field.enablesButton(role: createButton.role, text: blank))
            #expect(field.enablesButton(role: cancelButton.role, text: blank))
        }
        #expect(field.enablesButton(role: createButton.role, text: " Fixture Holds "))
        #expect(AppAlertTextFieldState(placeholder: TextState(verbatim: "Page")).enablesButton(role: nil, text: ""))
    }

    @MainActor
    @Test
    func aNameIsPostedAndTheNewSetIsChosenAndRead() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (host: GalleryHost, name: String, shownTagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("create \(host.rawValue) [\(name)] \(shownTagSet.id)") })
                return Self.page(Self.set1, tagSetIDs: [1, 2, 3])
            }
            $0.fetchTagSet = { (host: GalleryHost, tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("read \(host.rawValue) \(tagSetID)") })
                return Self.page(Self.set3, tagSetIDs: [1, 2, 3])
            }
        }
        // The cache is a shared reference, so a step's closure would already see the later read's answer; the cache
        // is checked at the end, as the presenting test does.
        store.exhaustivity = .off

        await create("  Fixture Holds \n", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.success) {
            $0.loadingState = .idle
        }
        #expect(
            store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.set2, Self.set3], selectedTagSetID: 3)
        )
        #expect(store.state.selectedTagSet == Self.set3)
        #expect(calls.value == ["create E-Hentai [Fixture Holds] 1", "read E-Hentai 3"])
    }

    @MainActor
    @Test
    func aRefusedCreateShowsTheSitesReasonOnTheRowAndChoosesNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1, message: Self.createRefusal)
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: Self.createRefusal)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    @MainActor
    @Test
    func aCreateWhoseAnswerListsNoNewSetShowsTheUnknownError() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: AppError.unknown.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    @MainActor
    @Test
    func aFailedCreateShowsTheErrorOnTheRowAndChoosesNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: AppError.networkingFailed.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    // Two new ids mean a set was also made elsewhere meanwhile: none is chosen, and every set is read again.
    @MainActor
    @Test
    func aCreateWhoseAnswerListsTwoNewSetsReadsEverySetAgain() async {
        let set4 = MyTagSet(id: 4, name: "Fixture Extras", isEnabled: false, color: nil, tags: [])
        let everySet = MyTags(tagSets: [Self.set1, Self.set2, Self.set3, set4])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1, tagSetIDs: [1, 2, 3, 4])
            }
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) in
                MyTagsResponse(myTags: everySet, apiuid: 1234567, apikey: "0123456789abcdef")
            }
        }
        // The cache is a shared reference, so a step's closure would already see the later read's answer; the cache
        // is checked at the end, as the presenting test does.
        store.exhaustivity = .off

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        await store.receive(\.fetchMyTags) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchMyTagsDone.success) {
            $0.loadingState = .idle
        }
        #expect(store.state.user.myTags == everySet)
    }

    @MainActor
    @Test(arguments: ["", "   ", " \n\t "])
    func aBlankNameSendsNothing(name: String) async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]))

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        // The empty name is already the alert's starting value, so that send changes nothing.
        if name.isEmpty {
            await store.send(.newTagSetNameChanged(name))
        } else {
            await store.send(.newTagSetNameChanged(name)) {
                $0.newTagSetName = name
            }
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
        }
    }

    @MainActor
    @Test
    func aSecondCreateWhileOneIsOnItsWaySendsNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]), isChangingTagSets: true)

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Fixture Holds")) {
            $0.newTagSetName = "Fixture Holds"
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
        }
    }

    // The row follows the shown set's page (U-1): none for set 2 as the cache holds it, with no page of it read; then
    // the row for its page that offers deleting it; then none for set 1, whose page does not.
    @MainActor
    @Test
    func theDeleteRowShowsOnlyWhileTheShownSetsPageOffersIt() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2)) {
            $0.fetchTagSet = { (_: GalleryHost, tagSetID: Int) async throws(AppError) in
                Self.page(tagSetID == 2 ? Self.offeredSet2 : Self.set1)
            }
        }
        store.exhaustivity = .off
        #expect(!store.state.canDeleteTagSet)

        await store.send(.refresh)
        await store.receive(\.fetchTagSetDone.success)
        #expect(store.state.canDeleteTagSet)

        await store.send(.tagSetSelected(1))
        await store.receive(\.fetchTagSetDone.success)
        #expect(!store.state.canDeleteTagSet)
    }

    @MainActor
    @Test
    func theDeleteRowOpensTheConfirmationAndCancelSendsNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2))

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: 2)
        }
        await store.send(.deleteTagSetDialog(.dismiss)) {
            $0.deleteTagSetDialog = nil
        }
    }

    @MainActor
    @Test
    func aConfirmedDeleteChoosesTheFirstSetTheAnswerShows() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (host: GalleryHost, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("delete \(host.rawValue) \(tagSet.id)") })
                return Self.page(Self.set1, tagSetIDs: [1])
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1], selectedTagSetID: 1) })
        }
        #expect(!store.state.canDeleteTagSet)
        #expect(calls.value == ["delete E-Hentai 2"])
    }

    @MainActor
    @Test
    func aConfirmedDeleteReadsTheFirstSetWhenTheAnswerShowsAnother() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2, Self.set3], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (host: GalleryHost, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("delete \(host.rawValue) \(tagSet.id)") })
                return Self.page(Self.set3, tagSetIDs: [1, 3])
            }
            $0.fetchTagSet = { (host: GalleryHost, tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("read \(host.rawValue) \(tagSetID)") })
                return Self.page(Self.set1, tagSetIDs: [1, 3])
            }
        }
        // The cache is a shared reference, so a step's closure would already see the later read's answer; the cache
        // is checked at the end, as the presenting test does.
        store.exhaustivity = .off

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.success) {
            $0.loadingState = .idle
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.set3], selectedTagSetID: 1))
        #expect(calls.value == ["delete E-Hentai 2", "read E-Hentai 1"])
    }

    @MainActor
    @Test
    func aRefusedDeleteShowsTheSitesReasonOnTheRowAndKeepsTheSet() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.offeredSet2, message: Self.deleteRefusal)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: Self.deleteRefusal)
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2))
        #expect(store.state.canDeleteTagSet)
        #expect(store.state.showsDeleteTagSetRow)
    }

    // A refusal whose answer no longer offers deleting the set still shows on the row (U-2a): the row stays, disabled
    // as the set is no longer offered, until its alert is dismissed, and then follows the offer again.
    @MainActor
    @Test
    func aRefusalThatWithdrawsTheOfferKeepsTheRowUntilItsAlertIsDismissed() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2, message: Self.deleteRefusal)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: Self.deleteRefusal)
        }
        #expect(!store.state.canDeleteTagSet)
        #expect(store.state.showsDeleteTagSetRow)

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(!store.state.showsDeleteTagSetRow)
    }

    @MainActor
    @Test
    func aDeleteWhoseAnswerStillListsTheSetShowsTheUnknownError() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: AppError.unknown.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == 2)
    }

    @MainActor
    @Test
    func aFailedDeleteShowsTheErrorOnTheRowAndKeepsTheSet() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: AppError.networkingFailed.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == 2)
    }

    // One flag holds both rows while a create or a delete is on its way (U-4); a create and a delete both raise it
    // (`create(_:in:)`, `confirmDelete(of:in:)`), and `aSecondCreateWhileOneIsOnItsWaySendsNothing` is the create's
    // side.
    @MainActor
    @Test
    func aDeleteWhileACreateOrADeleteIsOnItsWaySendsNothing() async {
        let store = makeStore(
            myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2), isChangingTagSets: true
        )

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: 2)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: 2)))) {
            $0.deleteTagSetDialog = nil
        }
    }

    // The confirmation names its set (U-3): a set no longer shown, or one whose page does not offer deleting it, is
    // not deleted.
    @MainActor
    @Test(arguments: zip([2, 1], [1, 1]))
    func aDeleteOfASetNotShownOrNotOfferedSendsNothing(shownTagSetID: Int, confirmedTagSetID: Int) async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: shownTagSetID))

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: shownTagSetID)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: confirmedTagSetID)))) {
            $0.deleteTagSetDialog = nil
        }
    }

    @MainActor
    private func makeStore(
        myTags: MyTags?,
        signedIn: Bool = true,
        credentials: Bool = false,
        isChangingTagSets: Bool = false,
        clock: any Clock<Duration> = TestClock(),
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        var state = MyTagsFeature.State()
        state.$user.withLock({ $0.myTags = myTags })
        if credentials {
            state.apiuid = 1234567
            state.apikey = "0123456789abcdef"
        }
        state.isChangingTagSets = isChangingTagSets
        return TestStore(initialState: state, reducer: MyTagsFeature.init) {
            $0.continuousClock = clock
            $0.cookieClient = signedIn ? .previewLoggedIn : .noop
            $0.myTagsClient = myTagsClient
        }
    }

    /// Opens New Tag Set, types `name` and taps Create, asserting each step; `name` is not blank.
    @MainActor
    private func create(_ name: String, in store: TestStoreOf<MyTagsFeature>) async {
        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged(name)) {
            $0.newTagSetName = name
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
            $0.isChangingTagSets = true
        }
    }

    /// The New Tag Set alert as N-2 and N-3 specify it.
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

    /// Taps Delete Tag Set on the shown set `tagSetID` and confirms, asserting each step; the set's page offers it.
    @MainActor
    private func confirmDelete(of tagSetID: Int, in store: TestStoreOf<MyTagsFeature>) async {
        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: tagSetID)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: tagSetID)))) {
            $0.deleteTagSetDialog = nil
            $0.isChangingTagSets = true
        }
    }

    /// The Delete Tag Set confirmation as U-3 specifies it, opened for the set `tagSetID`.
    private static func deleteTagSetDialog(
        for tagSetID: Int
    ) -> ConfirmationDialogState<MyTagsFeature.DeleteTagSetDialog> {
        ConfirmationDialogState(titleVisibility: .hidden) {
            TextState(localized: .RLocalizable.delete)
        } actions: {
            ButtonState(role: .destructive, action: .delete(tagSetID: tagSetID)) {
                TextState(localized: .RLocalizable.delete)
            }
            ButtonState(role: .cancel) {
                TextState(localized: .RLocalizable.cancel)
            }
        } message: {
            TextState(localized: .myTagsDeleteTagSetMessage)
        }
    }

    private static func page(_ tagSet: MyTagSet, tagSetIDs: [Int] = [1, 2], message: String? = nil) -> MyTagsPage {
        MyTagsPage(
            tagSet: tagSet, tagSetIDs: tagSetIDs, apiuid: 1234567, apikey: "0123456789abcdef", message: message
        )
    }
}
