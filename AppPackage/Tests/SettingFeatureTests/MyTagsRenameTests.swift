import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import MyTagsClient
import Resources
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

// Rename Tag Set on the My Tags page (quick 261126-wzf): the alert and what Rename waits for, the post, the new name
// shown at once, and the old name put back on a refusal or a failure. The sets and credentials are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsRenameTests {
    private static let refusal = "Sample rename refusal from the site"
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [])
    private static let holds = MyTagSet(id: 2, name: "Fixture Holds", isEnabled: false, color: green, tags: [])

    // The row opens the alert with the shown set's name, which each opening starts with again (W-1).
    @MainActor
    @Test
    func theRowOpensTheAlertWithTheSetsName() async {
        let store = makeStore()

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged("Leftover")) {
            $0.renameTagSetName = "Leftover"
        }
        await store.send(.renameTagSetAlert(.dismiss)) {
            $0.renameTagSetAlert = nil
        }
        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
    }

    // Rename waits while the name is blank or, trimmed, still the set's own; Cancel never waits (W-1).
    @MainActor
    @Test
    func renameWaitsForANewNameAndCancelNeverWaits() async throws {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.renameTagSetTapped)
        let alert = try #require(store.state.renameTagSetAlert)
        let field = try #require(alert.textField)
        let renameButton = try #require(alert.buttons.first(where: { $0.role == nil }))
        let cancelButton = try #require(alert.buttons.first(where: { $0.role == .cancel }))
        for unchanged in ["", "   ", "Fixture Picks", " Fixture Picks \n"] {
            #expect(!field.enablesButton(role: renameButton.role, text: unchanged))
            #expect(field.enablesButton(role: cancelButton.role, text: unchanged))
        }
        #expect(field.enablesButton(role: renameButton.role, text: " Fixture Holds "))
        #expect(field.enablesButton(role: renameButton.role, text: "fixture picks"))
    }

    // The picker shows the new name at once, and the site's answer keeps it; the set's own form is posted with the
    // trimmed name (W-1 to W-3).
    @MainActor
    @Test
    func aNewNameShowsAtOnceIsPostedAndTakesTheAnswer() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore {
            $0.renameTagSet = { (host: GalleryHost, name: String, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("rename \(host.rawValue) [\(name)] \(tagSet.id) \(tagSet.name)") })
                return Self.page(Self.holds)
            }
        }

        await rename(to: "  Fixture Holds \n", in: store)
        #expect(store.state.selectedTagSet == Self.holds)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.holds], selectedTagSetID: 2))
        #expect(calls.value == ["rename E-Hentai [Fixture Holds] 2 Fixture Picks"])
    }

    // A refusal leaves the set as the site has it, under its old name, with the site's reason on the row (W-3).
    @MainActor
    @Test
    func aRefusedRenamePutsTheOldNameBackWithTheSitesReasonOnTheRow() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2, message: Self.refusal)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: Self.refusal)
        }
    }

    // An answer that shows the set under a name other than the new one, with no reason, fails the rename with the
    // unknown error, and the picker shows the name the site has (W-3).
    @MainActor
    @Test
    func aRenameWhoseAnswerShowsAnotherNameShowsTheUnknownError() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.unknown.alertText)
        }
    }

    // An answer that shows another set says nothing of the renamed set's name, so the old name returns, with the
    // unknown error (W-3).
    @MainActor
    @Test
    func aRenameWhoseAnswerShowsAnotherSetPutsTheOldNameBack() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.unknown.alertText)
        }
    }

    @MainActor
    @Test
    func aFailedRenamePutsTheOldNameBackWithTheErrorOnTheRow() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.networkingFailed.alertText)
        }
    }

    // A blank name or the set's own is refused here too, though Rename waits for a new one (W-1).
    @MainActor
    @Test(arguments: ["", "   ", "Fixture Picks", " Fixture Picks \n"])
    func aBlankOrUnchangedNameSendsNothing(name: String) async {
        let store = makeStore()

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        // The set's own name is already the alert's starting value, so that send changes nothing.
        if name == "Fixture Picks" {
            await store.send(.renameTagSetNameChanged(name))
        } else {
            await store.send(.renameTagSetNameChanged(name)) {
                $0.renameTagSetName = name
            }
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: 2)))) {
            $0.renameTagSetAlert = nil
        }
    }

    // One such request at a time (W-1): a rename while a create, a rename or a delete is on its way sends nothing, and
    // so does a rename of a set no longer shown.
    @MainActor
    @Test(arguments: zip([true, false], [2, 1]))
    func aRenameWhileATagSetChangeIsOnItsWayOrOfASetNotShownSendsNothing(
        isChangingTagSets: Bool,
        renamedTagSetID: Int
    ) async {
        let store = makeStore(isChangingTagSets: isChangingTagSets)

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged("Fixture Holds")) {
            $0.renameTagSetName = "Fixture Holds"
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: renamedTagSetID)))) {
            $0.renameTagSetAlert = nil
        }
    }

    /// A page with set 2 shown and chosen, as every test here starts.
    @MainActor
    private func makeStore(
        isChangingTagSets: Bool = false,
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        var state = MyTagsFeature.State()
        state.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
        state.isChangingTagSets = isChangingTagSets
        return TestStore(initialState: state, reducer: MyTagsFeature.init) {
            $0.myTagsClient = myTagsClient
        }
    }

    /// Opens Rename Tag Set on set 2, types `name` and taps Rename, asserting each step: the in-flight flag rises and
    /// the picker shows the trimmed name at once. `name`, trimmed, is neither blank nor the set's own.
    @MainActor
    private func rename(to name: String, in store: TestStoreOf<MyTagsFeature>) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged(name)) {
            $0.renameTagSetName = name
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: 2)))) {
            $0.renameTagSetAlert = nil
            $0.isChangingTagSets = true
            $0.$user.withLock({ $0.myTags = $0.myTags?.renaming(2, to: trimmed) })
        }
    }

    /// The Rename Tag Set alert as W-1 specifies it, opened for set 2.
    private static var renameTagSetAlert: AppAlertState<MyTagsFeature.RenameTagSetAlert> {
        AppAlertState(
            title: {
                TextState(localized: .myTagsRenameTagSetTitle)
            },
            textField: AppAlertTextFieldState(
                placeholder: TextState(localized: .myTagsNewTagSetName),
                requiresText: true,
                editedValue: "Fixture Picks"
            ),
            actions: {
                ButtonState(action: .rename(tagSetID: 2)) {
                    TextState(localized: .myTagsRename)
                }
                ButtonState(role: .cancel) {
                    TextState(localized: .RLocalizable.cancel)
                }
            },
            message: {
                TextState(localized: .myTagsRenameTagSetMessage)
            }
        )
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
