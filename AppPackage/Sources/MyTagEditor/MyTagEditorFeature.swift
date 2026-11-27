public import AppComponents
public import AppModels
public import ComposableArchitecture
import Foundation
import MyTagsClient
import Resources
public import SwiftUI

/// Add Tag and Edit Tag, one form for both (port of PR 462 item 10, design approved 2026-11-22).
///
/// Confirm sends the change to the site and closes the sheet once the site took it; a refusal or a failure keeps it
/// open with the alert on the control that sent it. An add or a remove takes the page the site answered with into
/// the cached My Tags, and an edit changes the cached tag once the edit API accepts it, so a host only reports the
/// outcome (`Delegate`). Close discards the changes without asking.
///
/// Add Tag lists the site's suggestions for the typed tag, as the site's own tag field does: it asks 200 ms after the
/// text last changed, a change cancels the question on its way, and nothing is asked while fewer than two characters
/// follow the namespace; a failed question shows no rows and no alert (G-1 of quick 261126-wzg).
@Reducer
public struct MyTagEditorFeature: Sendable {
    public enum Mode: Equatable, Sendable {
        case add
        /// The tag as it was, with the edit API's credentials of the page that opened it.
        case edit(MyTag, apiuid: Int, apikey: String)
    }

    /// A control that sends a request: confirm, or Remove from My Tags.
    public enum Control: Equatable, Sendable {
        case confirm
        case remove
    }

    /// What the Color section's footer says.
    public enum ColorFooter: Equatable, Sendable {
        /// The hex field holds neither nothing nor a code; said in red (G-2 of quick 261126-wzg).
        case invalidCode
        /// The tag has a colour of its own.
        case ownColor
        /// The tag takes its set's default colour.
        case tagSetColor
        /// Neither the tag nor its set has a colour.
        case noColor
    }

    @CasePathable
    public enum Delegate: Equatable, Sendable {
        case saved
        case removed
    }

    private enum CancelID {
        case suggestions
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.user) public var user: User
        @SharedReader(.setting) public var setting: Setting
        @Presents public var alert: AppAlertState<Never>?
        /// The control whose request failed, so the alert shows on it.
        public var alertSource: Control?
        /// The control whose request is on its way.
        public var running: Control?
        public let mode: Mode
        public let tagSetID: Int
        /// The tag set's default colour, which a tag without its own takes.
        public let tagSetColor: SiteColor?
        /// False for Edit Tag, whose tag the site cannot rename, and for an add from a tag's context menu.
        public let isNameEditable: Bool
        public var name: String
        public var kind: MyTagKind
        public var color: SiteColor?
        /// The hex field's text, kept here so confirm can wait while it is not a code (G-2 of quick 261126-wzg).
        public var colorText: String
        public var weight: Int
        /// The weight field's text. A number typed moves `weight` at once, clamped into the site's range; submit or
        /// leaving the field writes `weight` back, so an empty or unreadable text returns to it (G-3 of quick
        /// 261126-wzg).
        public var weightText: String
        /// The site's last answer for the typed tag, every entry as the site gave it (G-1 of quick 261126-wzg). It
        /// stays while the next answer is on its way, so the rows narrow as the text grows, as the site's list does.
        public var siteSuggestionAnswer: [SiteTagSuggestion] = []

        /// Add Tag for `tagSet`: a new tag starts Normal (owner decision, 2026-11-26), without a colour of its own, at
        /// the site's default weight.
        public init(adding name: String = "", isNameEditable: Bool = true, tagSet: MyTagSet) {
            self.mode = .add
            self.tagSetID = tagSet.id
            self.tagSetColor = tagSet.color
            self.isNameEditable = isNameEditable
            self.name = name
            self.kind = .flagged
            self.color = nil
            self.colorText = ""
            self.weight = MyTag.defaultWeight
            self.weightText = String(MyTag.defaultWeight)
        }

        /// Edit Tag for `tag` of `tagSet`, saved through the edit API with the page's credentials.
        public init(editing tag: MyTag, tagSet: MyTagSet, apiuid: Int, apikey: String) {
            self.mode = .edit(tag, apiuid: apiuid, apikey: apikey)
            self.tagSetID = tagSet.id
            self.tagSetColor = tagSet.color
            self.isNameEditable = false
            self.name = tag.name
            self.kind = tag.kind
            self.color = tag.color
            self.colorText = tag.color?.hex ?? ""
            self.weight = tag.weight
            self.weightText = String(tag.weight)
        }

        public var isAdding: Bool { mode == .add }

        /// Add: the field holds a tag. Edit: something changed. Neither while a request is on its way, nor while the
        /// hex field holds an invalid code (G-2 of quick 261126-wzg).
        public var canConfirm: Bool {
            guard running == nil, !isColorTextInvalid else { return false }
            switch mode {
            case .add:
                return !trimmedName.isEmpty
            case .edit(let tag, _, _):
                return edited(tag) != tag
            }
        }

        /// The colour the well shows: the tag's own, else its set's; picking one sets the tag's own.
        public var wellColor: Color {
            get { (color ?? tagSetColor)?.color ?? .clear }
            set { color = SiteColor(newValue) }
        }

        /// Whether the hex field holds neither nothing nor a code (G-2 of quick 261126-wzg).
        public var isColorTextInvalid: Bool {
            HexColorField.isInvalidCode(colorText)
        }

        /// The Color section's footer: while the code is invalid, that it is (G-2 of quick 261126-wzg); else which
        /// colour applies.
        public var colorFooter: ColorFooter {
            if isColorTextInvalid {
                return .invalidCode
            }
            if color != nil {
                return .ownColor
            }
            return tagSetColor == nil ? .noColor : .tagSetColor
        }

        /// The site's suggestions under the tag field: the entries of its last answer whose name holds the field's
        /// query at the start of a word, as the site's list keeps them; none while the query is too short (G-1 of
        /// quick 261126-wzg).
        public var siteSuggestions: [SiteTagSuggestion] {
            guard let query = TagSuggestQuery(name) else { return [] }
            return siteSuggestionAnswer.filter({ $0.matches(query) })
        }

        var trimmedName: String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// `tag` with the form's state, colour and weight.
        func edited(_ tag: MyTag) -> MyTag {
            var edited = tag
            edited.kind = kind
            edited.color = color
            edited.weight = weight
            return edited
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case alert(PresentationAction<Never>)
        case closeTapped
        case confirmTapped
        case addDone(Result<MyTagsPage, AppError>)
        case updateDone(MyTag, Result<MyTagEditReply, AppError>)
        case removeTapped
        case removeDone(Result<MyTagsPage, AppError>)
        case suggestDone(Result<[SiteTagSuggestion], AppError>)
        case suggestionChosen(String)
        case weightFieldCommitted
        case delegate(Delegate)
    }

    @Dependency(\.continuousClock) private var clock
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.myTagsClient) private var myTagsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.name):
                // The site's tag completer (G-1 of quick 261126-wzg): it asks 200 ms after the text last changed, a
                // change cancels the question on its way, and a text with fewer than two characters after the
                // namespace asks nothing and shows no rows.
                guard let query = TagSuggestQuery(state.name) else {
                    state.siteSuggestionAnswer = []
                    return .cancel(id: CancelID.suggestions)
                }
                let host = state.setting.galleryHost
                return .run { send in
                    try await clock.sleep(for: .milliseconds(200))
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.suggestTags(host, query)
                    }
                    await send(.suggestDone(result))
                }
                .cancellable(id: CancelID.suggestions, cancelInFlight: true)

            case .binding(\.weightText):
                // Three characters at most, as the site's field takes; a number moves the Stepper at once, clamped
                // into the site's range (G-3 of quick 261126-wzg).
                if state.weightText.count > 3 {
                    state.weightText = String(state.weightText.prefix(3))
                }
                if let typed = Int(state.weightText) {
                    state.weight = min(max(typed, MyTag.weightRange.lowerBound), MyTag.weightRange.upperBound)
                }
                return .none

            case .binding(\.weight):
                // The field follows the Stepper (G-3 of quick 261126-wzg).
                state.weightText = String(state.weight)
                return .none

            case .binding, .alert, .delegate:
                return .none

            case .closeTapped:
                return .run(operation: { _ in await dismiss() })

            case .confirmTapped:
                guard state.canConfirm else { return .none }
                state.running = .confirm
                let host = state.setting.galleryHost
                let tagSetID = state.tagSetID
                switch state.mode {
                case .add:
                    let draft = MyTagDraft(
                        name: state.trimmedName, kind: state.kind, color: state.color, weight: state.weight
                    )
                    // The field is sent as it is, so its suggestions are no longer wanted (G-1 of quick 261126-wzg).
                    state.siteSuggestionAnswer = []
                    return .merge(
                        .cancel(id: CancelID.suggestions),
                        .run { send in
                            let result = await Result.Swift::init { () async throws(AppError) in
                                try await myTagsClient.addTag(host, draft, tagSetID)
                            }
                            await send(.addDone(result))
                        }
                    )

                case .edit(let tag, let apiuid, let apikey):
                    let edited = state.edited(tag)
                    return .run { send in
                        let result = await Result.Swift::init { () async throws(AppError) in
                            try await myTagsClient.updateTag(host, apiuid, apikey, edited)
                        }
                        await send(.updateDone(edited, result))
                    }
                }

            case .addDone(.success(let page)):
                state.running = nil
                state.$user.withLock({ $0.myTags = $0.myTags?.applying(page) })
                if let message = page.message {
                    return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: message)
                }
                return finish(.saved)

            case .addDone(.failure(let error)):
                state.running = nil
                return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)

            case .updateDone(let edited, .success(.accepted)):
                state.running = nil
                let tagSetID = state.tagSetID
                state.$user.withLock({ $0.myTags = $0.myTags?.updating(edited, inTagSet: tagSetID) })
                return finish(.saved)

            case .updateDone(_, .success(.refused(let reason))):
                state.running = nil
                return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: reason)

            case .updateDone(_, .failure(let error)):
                state.running = nil
                return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)

            case .removeTapped:
                guard case .edit(let tag, _, _) = state.mode, state.running == nil else { return .none }
                state.running = .remove
                let host = state.setting.galleryHost
                let tagSetID = state.tagSetID
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.removeTags(host, [tag.id], tagSetID)
                    }
                    await send(.removeDone(result))
                }

            case .removeDone(.success(let page)):
                state.running = nil
                state.$user.withLock({ $0.myTags = $0.myTags?.applying(page) })
                if let message = page.message {
                    return presentAlert(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, message: message)
                }
                return finish(.removed)

            case .removeDone(.failure(let error)):
                state.running = nil
                return presentAlert(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, message: error.alertText)

            case .suggestDone(.success(let suggestions)):
                state.siteSuggestionAnswer = suggestions
                return .none

            case .suggestDone(.failure):
                // A failed question shows no rows and no alert (G-1 of quick 261126-wzg).
                state.siteSuggestionAnswer = []
                return .none

            case .suggestionChosen(let tag):
                // A chosen row fills the field, an alias's canonical tag for an alias; the site's rows go until the
                // text changes again (G-1 of quick 261126-wzg).
                state.name = tag
                state.siteSuggestionAnswer = []
                return .cancel(id: CancelID.suggestions)

            case .weightFieldCommitted:
                // Submit or leaving the weight field shows the weight in force: the typed number clamped, or the last
                // weight for an empty or unreadable text (G-3 of quick 261126-wzg).
                state.weightText = String(state.weight)
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Tells the host how it went, then closes the sheet.
    private func finish(_ outcome: Delegate) -> Effect<Action> {
        .run { send in
            await send(.delegate(outcome))
            await dismiss()
        }
    }

    private func presentAlert(
        _ state: inout State,
        _ source: Control,
        title: LocalizedStringResource,
        message: String
    ) -> Effect<Action> {
        state.alertSource = source
        state.alert = .failure(title: title, message: message)
        return .none
    }
}
