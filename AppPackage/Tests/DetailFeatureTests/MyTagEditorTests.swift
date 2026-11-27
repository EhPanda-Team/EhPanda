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
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions and the
// colour code's check (quick 261126-wzg). The tags, sets and suggestions are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagEditorTests {
    private static let refusal = "No matching tag found"
    private static let slate = SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0)
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let navy = SiteColor(red: 0x1F, green: 0x3A, blue: 0x93)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let artist = MyTag(
        id: 201, name: "artist:sample artist", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: slate, tags: [])
    private static let sampleGlasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )
    private static let sampleFrames = SiteTagSuggestion(
        id: 9002,
        tag: SiteTag(namespace: .female, name: "sample glass frames"),
        canonical: SiteTag(namespace: .female, name: "sample spectacles")
    )
    private static let unsampleGlow = SiteTagSuggestion(
        id: 9003, tag: SiteTag(namespace: .other, name: "unsample glow"), canonical: nil
    )

    @MainActor
    @Test
    func aNewTagStartsNormalAtTheDefaultWeightAndNeedsAName() {
        var state = MyTagEditorFeature.State(tagSet: Self.set2)
        #expect(state.kind == .flagged)
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
        #expect(calls.value == ["E-Hentai artist:sample artist flagged  -5 2"])
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

    // The site's tag completer asks 200 ms after the text last changed, and its list keeps the answer's entries whose
    // name holds the text at the start of a word (G-1, G-4 of quick 261126-wzg).
    @MainActor
    @Test
    func theSuggestionsAreAskedForOnceTheTextRestsAndListTheWordStartMatches() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (host: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(query.text)") })
                return [Self.sampleGlasses, Self.sampleFrames, Self.unsampleGlow]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(199))
        #expect(calls.value.isEmpty)
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames, Self.unsampleGlow]
        }
        #expect(calls.value == ["E-Hentai sample gl"])
        #expect(store.state.siteSuggestions == [Self.sampleGlasses, Self.sampleFrames])
    }

    // A change of the text cancels the question it replaces, and the wait starts again (G-1, G-4).
    @MainActor
    @Test
    func aChangedTextCancelsTheQuestionItReplaces() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses, Self.sampleFrames]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(150))
        await store.send(.binding(.set(\.name, "sample gla"))) {
            $0.name = "sample gla"
        }
        await clock.advance(by: .milliseconds(150))
        #expect(calls.value.isEmpty)
        await clock.advance(by: .milliseconds(50))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames]
        }
        #expect(calls.value == ["sample gla"])
    }

    // Nothing is asked while fewer than two characters follow the namespace, and going back under two clears the
    // rows (G-1, G-4).
    @MainActor
    @Test
    func fewerThanTwoCharactersAfterTheNamespaceAskNothing() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses]
            }
        }

        await store.send(.binding(.set(\.name, "s"))) {
            $0.name = "s"
        }
        await store.send(.binding(.set(\.name, "female:s"))) {
            $0.name = "female:s"
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value.isEmpty)
        await store.send(.binding(.set(\.name, "female:sa"))) {
            $0.name = "female:sa"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses]
        }
        #expect(store.state.siteSuggestions == [Self.sampleGlasses])
        await store.send(.binding(.set(\.name, "female:s"))) {
            $0.name = "female:s"
            $0.siteSuggestionAnswer = []
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value == ["female:sa"])
    }

    // The question carries the text as the site's completer sends it: a loose namespace written out, the quotes
    // removed (G-1, G-4).
    @MainActor
    @Test(arguments: [
        ("f:sample", "female:sample"),
        ("x:sample", "mixed:sample"),
        ("mis:sample", "temp:sample"),
        ("co:sample", "cosplayer:sample"),
        ("lo:sample", "location:sample"),
        ("lang:sample", "language:sample"),
        (#""a:sample""#, "artist:sample"),
        ("sample", "sample")
    ])
    func aLooseNamespaceIsWrittenOutBeforeTheQuestion(typed: String, sent: String) async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return []
            }
        }

        await store.send(.binding(.set(\.name, typed))) {
            $0.name = typed
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success)
        #expect(calls.value == [sent])
    }

    // An alias's row puts its canonical tag in the field, and the site's rows go until the text changes again (G-1,
    // G-4).
    @MainActor
    @Test
    func choosingAnAliasPutsItsCanonicalTagInTheField() async throws {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses, Self.sampleFrames]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames]
        }
        let alias = try #require(store.state.siteSuggestions.first(where: { $0.canonical != nil }))
        await store.send(.suggestionChosen(alias.insertedTag.fullName)) {
            $0.name = "female:sample spectacles"
            $0.siteSuggestionAnswer = []
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value == ["sample gl"])
        #expect(store.state.siteSuggestions.isEmpty)
        #expect(store.state.canConfirm)
    }

    // A failed question shows no rows and no alert (G-1, G-4).
    @MainActor
    @Test
    func aFailedQuestionShowsNoRowsAndNoAlert() async {
        let answers = LockIsolated<[Result<[SiteTagSuggestion], AppError>]>([
            .success([Self.sampleGlasses]), .failure(.networkingFailed)
        ])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) in
                try answers.withValue({ $0.removeFirst() }).get()
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses]
        }
        await store.send(.binding(.set(\.name, "sample gla"))) {
            $0.name = "sample gla"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.failure) {
            $0.siteSuggestionAnswer = []
        }
        #expect(store.state.siteSuggestions.isEmpty)
        #expect(store.state.alert == nil)
    }

    // Empty text, spaces alone, or six hex digits with or without `#` and spaces around them is no invalid code (G-2
    // of quick 261126-wzg).
    @Test(arguments: ["", "  ", "#1F3A93", "1f3a93", " #1F3A93 "])
    func anEmptyTextOrACodeIsNoInvalidCode(text: String) {
        #expect(!HexColorField.isInvalidCode(text))
    }

    @Test(arguments: ["#", "#1F3A9", "#1F3A930", "#GGGGGG", "1F 3A93"])
    func anythingElseIsAnInvalidCode(text: String) {
        #expect(HexColorField.isInvalidCode(text))
    }

    // While the hex field holds an invalid code, the Color footer says so and confirm waits; an empty or a valid
    // text shows the footer of the colour in use and lets confirm go (G-2, G-4).
    @MainActor
    @Test
    func anInvalidCodeTakesTheColorFooterAndHoldsConfirmBack() async {
        let store = makeStore(state: { MyTagEditorFeature.State(adding: "artist:sample artist", tagSet: Self.set2) })
        #expect(store.state.colorFooter == .tagSetColor)
        #expect(store.state.canConfirm)

        await store.send(.binding(.set(\.colorText, "#1F3A9"))) {
            $0.colorText = "#1F3A9"
        }
        #expect(store.state.colorFooter == .invalidCode)
        #expect(!store.state.canConfirm)

        // The field writes the colour of a valid code itself, as it does in the sheet.
        await store.send(.binding(.set(\.colorText, "#1F3A93"))) {
            $0.colorText = "#1F3A93"
        }
        await store.send(.binding(.set(\.color, Self.navy))) {
            $0.color = Self.navy
        }
        #expect(store.state.colorFooter == .ownColor)
        #expect(store.state.canConfirm)

        await store.send(.binding(.set(\.colorText, "  "))) {
            $0.colorText = "  "
        }
        #expect(store.state.colorFooter == .ownColor)
        #expect(store.state.canConfirm)
    }

    // An edit waits for a valid code too, whatever else changed; a tag's own colour starts in the field (G-2, G-4).
    @MainActor
    @Test
    func anEditWithAnInvalidCodeCannotBeConfirmed() async {
        var coloured = Self.glasses
        coloured.color = Self.slate
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: coloured, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            }
        )
        #expect(store.state.colorText == "#A0B0C0")
        #expect(store.state.colorFooter == .ownColor)

        await store.send(.binding(.set(\.kind, .hidden))) {
            $0.kind = .hidden
        }
        #expect(store.state.canConfirm)
        await store.send(.binding(.set(\.colorText, "zz"))) {
            $0.colorText = "zz"
        }
        #expect(store.state.colorFooter == .invalidCode)
        #expect(!store.state.canConfirm)
        await store.send(.confirmTapped)
        await store.send(.binding(.set(\.colorText, ""))) {
            $0.colorText = ""
        }
        #expect(store.state.canConfirm)
    }

    @MainActor
    private func makeStore(
        state: () -> MyTagEditorFeature.State,
        dismissed: LockIsolated<Int> = LockIsolated(0),
        clock: any Clock<Duration> = TestClock(),
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagEditorFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        let initial = state()
        initial.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
        return TestStore(initialState: initial, reducer: MyTagEditorFeature.init) {
            $0.continuousClock = clock
            $0.dismiss = DismissEffect { dismissed.withValue({ $0 += 1 }) }
            $0.myTagsClient = myTagsClient
        }
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
