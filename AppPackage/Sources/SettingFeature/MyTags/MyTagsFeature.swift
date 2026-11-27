public import AppComponents
public import AppModels
import AppTools
public import ComposableArchitecture
import CookieClient
public import Foundation
public import MyTagEditor
import MyTagsClient
import Resources
public import SwiftUI

/// The native My Tags page (port of PR 462 item 10, design approved 2026-11-22).
///
/// It reads every tag set when presented, on Retry, when the site's page in the web view closes and after a sign-in,
/// and the chosen set's page when the picker changes it or on pull to refresh. Enabled and the default colour go to
/// the site as they change, the colour after a second without another change, so a drag in the system picker sends
/// one request; a refusal or a failure puts the set back as the site has it and shows the alert. A row opens Edit
/// Tag, Add Tag the same form empty, and a swipe removes the tag at once. Every write takes the page the site
/// answered with into the cached My Tags. The edit API's credentials of the last page read stay in this state and are
/// never persisted.
///
/// New Tag Set asks for a name in an alert, then has the site create the set from the form of the set shown; the
/// page then chooses the new set and reads it, and a refusal or a failure shows the alert on the row (quick
/// 261126-pfh).
///
/// Delete Tag Set shows while the shown set's page offers deleting it, and stays, disabled, while its own failure
/// alert is up. It asks in a confirmation, then has the site delete the set; the page then chooses the site's first
/// set and shows it, and a refusal or a failure shows the alert on the row (quick 261126-udx).
@Reducer
public struct MyTagsFeature: Sendable {
    @Reducer
    public enum Destination {
        case editor(MyTagEditorFeature)
        /// The site's own My Tags page, the fallback when this page cannot read it.
        @ReducerCaseIgnored
        case browser(URL)
    }

    /// A control whose request failed, so the alert shows on it.
    public enum AlertSource: Equatable, Sendable {
        case enabled
        case defaultColor
        case tag(Int)
        /// The New Tag Set row, whose create was refused or failed.
        case newTagSet
        /// The Delete Tag Set row, whose delete was refused or failed.
        case deleteTagSet
    }

    /// The New Tag Set alert's action besides Cancel.
    public enum NewTagSetAlert: Equatable, Sendable {
        case create
    }

    /// The Delete Tag Set confirmation's action besides Cancel; it names the set it was opened for (U-3).
    public enum DeleteTagSetDialog: Equatable, Sendable {
        case delete(tagSetID: Int)
    }

    public enum Delegate: Equatable, Sendable {
        case pushLogin
    }

    private enum CancelID {
        case fetch
        case observeLogin
        case updateTagSet
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.user) public var user: User
        @SharedReader(.setting) public var setting: Setting
        @Presents public var destination: Destination.State?
        @Presents public var alert: AppAlertState<Never>?
        @Presents public var toast: AppAlertState<Never>?
        /// The alert that names a new tag set (N-2 of quick 261126-pfh).
        @Presents public var newTagSetAlert: AppAlertState<NewTagSetAlert>?
        /// The confirmation that deletes the shown tag set (U-3 of quick 261126-udx).
        @Presents public var deleteTagSetDialog: ConfirmationDialogState<DeleteTagSetDialog>?
        public var alertSource: AlertSource?
        public var loadingState: LoadingState = .idle
        /// The edit API's credentials of the last page read; in memory only.
        public var apiuid: Int?
        public var apikey: String?
        /// The tag set as the site last had it while an Enabled or colour change is on its way.
        public var confirmedTagSet: MyTagSet?
        /// The name typed into the New Tag Set alert; emptied each time the alert opens.
        public var newTagSetName = ""
        /// A create or a delete of a tag set is on its way (U-4 of quick 261126-udx): New Tag Set and Delete Tag Set
        /// are disabled, and another create or delete is refused, until the site answers. One flag serves both: a
        /// delete answered while a create is on its way would confuse the create's search for its new id, and a
        /// create answered while a delete is on its way would confuse the delete's check that its set is gone.
        public var isChangingTagSets = false

        public init() {}

        public var selectedTagSet: MyTagSet? { user.myTags?.selectedTagSet }
        public var selectedTagSetID: Int { selectedTagSet?.id ?? 1 }
        public var isTagSetEnabled: Bool { selectedTagSet?.isEnabled ?? false }
        public var tagSetColor: SiteColor? { selectedTagSet?.color }
        public var tagSetWellColor: Color { selectedTagSet?.color?.color ?? .clear }
        /// Whether the shown set's page offers deleting it (U-1 of quick 261126-udx), which Delete Tag Set needs to be
        /// shown and enabled; a set read back from storage, with no page of it read since, offers nothing.
        public var canDeleteTagSet: Bool { selectedTagSet?.isDeletable ?? false }
        /// Delete Tag Set shows while the shown set is offered, and also while its own failure alert is up (U-2a of
        /// quick 261126-udx): the alert is anchored on the row, so an answer that withdraws the offer must not take
        /// the row, and the refusal with it, away before the alert is dismissed. Shown that way it is disabled.
        public var showsDeleteTagSetRow: Bool {
            canDeleteTagSet || (alertSource == .deleteTagSet && alert != nil)
        }
        /// The site's page the browser sheet shows; get-only, so the sheet binds through `browserChanged`.
        public var browserURL: URL? { destination?.browser }
    }

    public enum Action {
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Never>)
        case toast(PresentationAction<Never>)
        case newTagSetAlert(PresentationAction<NewTagSetAlert>)
        case deleteTagSetDialog(PresentationAction<DeleteTagSetDialog>)
        case delegate(Delegate)
        /// Sent when the page is presented.
        case onPresented
        case loginSucceeded
        case fetchMyTags
        case fetchMyTagsDone(Result<MyTagsResponse, AppError>)
        case tagSetSelected(Int)
        case refresh
        case fetchTagSetDone(Result<MyTagsPage, AppError>)
        case enabledChanged(Bool)
        case defaultColorChanged(SiteColor?)
        case defaultWellColorChanged(Color)
        case updateTagSetDone(AlertSource, Result<MyTagsPage, AppError>)
        case addTagTapped
        case tagTapped(MyTag)
        case removeSwiped(MyTag)
        case removeTagDone(tagID: Int, result: Result<MyTagsPage, AppError>)
        case newTagSetTapped
        case newTagSetNameChanged(String)
        case createTagSetDone(knownTagSetIDs: [Int], result: Result<MyTagsPage, AppError>)
        case deleteTagSetTapped
        case deleteTagSetDone(tagSetID: Int, result: Result<MyTagsPage, AppError>)
        case openInBrowserTapped
        case browserChanged(URL?)
    }

    @Dependency(\.continuousClock) private var clock
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.myTagsClient) private var myTagsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert, .toast, .delegate, .newTagSetAlert(.dismiss), .deleteTagSetDialog(.dismiss):
                return .none

            case .onPresented:
                // Subscribe before returning the effect so a login during presentation is not missed.
                let changes = cookieClient.cookiesDidChange()
                let initiallyLoggedIn = cookieClient.didLogin
                let observeLogin: Effect<Action> = .run { send in
                    var wasLoggedIn = initiallyLoggedIn
                    for await _ in changes {
                        let isLoggedIn = cookieClient.didLogin
                        if !wasLoggedIn && isLoggedIn {
                            await send(.loginSucceeded)
                        }
                        wasLoggedIn = isLoggedIn
                    }
                }
                .cancellable(id: CancelID.observeLogin, cancelInFlight: true)
                guard initiallyLoggedIn else { return observeLogin }
                return .merge(observeLogin, .send(.fetchMyTags))

            case .loginSucceeded:
                return .send(.fetchMyTags)

            case .fetchMyTags:
                state.loadingState = .loading
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.fetchMyTags(host)
                    }
                    await send(.fetchMyTagsDone(result))
                }
                .cancellable(id: CancelID.fetch, cancelInFlight: true)

            case .fetchMyTagsDone(.success(let response)):
                state.loadingState = .idle
                state.apiuid = response.apiuid
                state.apikey = response.apikey
                state.$user.withLock({ $0.myTags = response.myTags.selecting($0.myTags?.selectedTagSetID) })
                return .none

            case .fetchMyTagsDone(.failure(let error)), .fetchTagSetDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            // The choice is kept with the cache, so Add to My Tags adds to the set last chosen here.
            case .tagSetSelected(let tagSetID):
                guard tagSetID != state.selectedTagSetID else { return .none }
                state.$user.withLock({ $0.myTags = $0.myTags?.selecting(tagSetID) })
                state.loadingState = .loading
                return fetchTagSet(state.selectedTagSetID, host: state.setting.galleryHost)

            case .refresh:
                return fetchTagSet(state.selectedTagSetID, host: state.setting.galleryHost)

            case .fetchTagSetDone(.success(let page)):
                state.loadingState = .idle
                take(page, into: &state)
                return .none

            case .enabledChanged(let isEnabled):
                return changeTagSet(&state, source: .enabled, waits: false) { $0.isEnabled = isEnabled }

            case .defaultColorChanged(let color):
                return changeTagSet(&state, source: .defaultColor, waits: true) { $0.color = color }

            case .defaultWellColorChanged(let color):
                return changeTagSet(&state, source: .defaultColor, waits: true) { $0.color = SiteColor(color) }

            // The page the site answered with is the set as it now is, so it also puts back a change it refused.
            case .updateTagSetDone(let source, .success(let page)):
                state.confirmedTagSet = nil
                take(page, into: &state)
                guard let message = page.message else { return .none }
                return presentAlert(&state, source, title: .RLocalizable.myTagsSaveFailed, message: message)

            case .updateTagSetDone(let source, .failure(let error)):
                if let confirmed = state.confirmedTagSet {
                    state.$user.withLock({ $0.myTags = $0.myTags?.updating(confirmed) })
                }
                state.confirmedTagSet = nil
                return presentAlert(&state, source, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)

            case .addTagTapped:
                guard let tagSet = state.selectedTagSet else { return .none }
                state.destination = .editor(MyTagEditorFeature.State(tagSet: tagSet))
                return .none

            case .tagTapped(let tag):
                guard let tagSet = state.selectedTagSet, let apiuid = state.apiuid, let apikey = state.apikey
                else { return .none }
                state.destination = .editor(
                    MyTagEditorFeature.State(editing: tag, tagSet: tagSet, apiuid: apiuid, apikey: apikey)
                )
                return .none

            case .removeSwiped(let tag):
                guard let tagSetID = state.selectedTagSet?.id else { return .none }
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.removeTags(host, [tag.id], tagSetID)
                    }
                    // The row leaves with the list's animation.
                    await send(.removeTagDone(tagID: tag.id, result: result), animation: .default)
                }

            case .removeTagDone(let tagID, .success(let page)):
                take(page, into: &state)
                guard let message = page.message else { return .none }
                return presentAlert(&state, .tag(tagID), title: .RLocalizable.myTagsRemoveFailed, message: message)

            case .removeTagDone(let tagID, .failure(let error)):
                return presentAlert(
                    &state, .tag(tagID), title: .RLocalizable.myTagsRemoveFailed, message: error.alertText
                )

            // The name starts empty each time (N-2); Create waits for one (N-3).
            case .newTagSetTapped:
                state.newTagSetName = ""
                state.newTagSetAlert = AppAlertState(
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
                return .none

            case .newTagSetNameChanged(let name):
                state.newTagSetName = name
                return .none

            // A blank name is refused here too, though Create waits for one (N-3), and so is a create while a create
            // or a delete is on its way (U-4 of quick 261126-udx): a create is not safe to send twice
            // (`CreateMyTagSetRequest`). The sets the cache has now are the ones the site's answer is read against
            // (N-5).
            case .newTagSetAlert(.presented(.create)):
                let name = state.newTagSetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !state.isChangingTagSets, let shownTagSet = state.selectedTagSet
                else { return .none }
                state.isChangingTagSets = true
                let knownTagSetIDs = state.user.myTags?.tagSets.map(\.id) ?? []
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.createTagSet(host, name, shownTagSet)
                    }
                    await send(.createTagSetDone(knownTagSetIDs: knownTagSetIDs, result: result))
                }

            // The new set is the one id the answer's picker lists that the cache lacked before the post (N-5). It is
            // chosen, kept with the cache as a choice in the picker is, and read, so the loading view shows until its
            // page arrives with the name, Enabled and colour the site gave it; that read puts it in the picker (N-6).
            // A reason on the page, or no new id, fails the create. More than one new id means a set was also made
            // elsewhere meanwhile: none is chosen, and every set is read again so each shows with its name.
            case .createTagSetDone(let knownTagSetIDs, .success(let page)):
                state.isChangingTagSets = false
                take(page, into: &state)
                if let message = page.message {
                    return presentAlert(&state, .newTagSet, title: .myTagsCreateTagSetFailed, message: message)
                }
                let newTagSetIDs = page.tagSetIDs.filter({ !knownTagSetIDs.contains($0) })
                guard let newTagSetID = newTagSetIDs.first else {
                    // Neither the new set nor a reason: the page was read (no parse failure), so all the app knows
                    // is that the set is not there.
                    return presentAlert(
                        &state, .newTagSet, title: .myTagsCreateTagSetFailed, message: AppError.unknown.alertText
                    )
                }
                guard newTagSetIDs.count == 1 else { return .send(.fetchMyTags) }
                state.$user.withLock({ $0.myTags = $0.myTags?.selecting(newTagSetID) })
                state.loadingState = .loading
                return fetchTagSet(newTagSetID, host: state.setting.galleryHost)

            case .createTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentAlert(
                    &state, .newTagSet, title: .myTagsCreateTagSetFailed, message: error.alertText
                )

            // The confirmation names the set it was opened for, the one the page shows (U-3).
            case .deleteTagSetTapped:
                guard let tagSet = state.selectedTagSet else { return .none }
                state.deleteTagSetDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .RLocalizable.delete)
                } actions: {
                    ButtonState(role: .destructive, action: .delete(tagSetID: tagSet.id)) {
                        TextState(localized: .RLocalizable.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .myTagsDeleteTagSetMessage)
                }
                return .none

            // Only the set the confirmation names is deleted, while it is still the one shown and its page still
            // offers it, and not while a create or a delete is on its way (U-4). The form is the shown set's own.
            case .deleteTagSetDialog(.presented(.delete(let tagSetID))):
                guard !state.isChangingTagSets, let tagSet = state.selectedTagSet,
                      tagSet.id == tagSetID, tagSet.isDeletable
                else { return .none }
                state.isChangingTagSets = true
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.deleteTagSet(host, tagSet)
                    }
                    await send(.deleteTagSetDone(tagSetID: tagSetID, result: result))
                }

            // The answer is taken into the cache, so a set the site dropped leaves the picker (U-6). The delete took
            // when the page gives no reason and its picker no longer lists the set: the page then chooses the site's
            // first set, kept with the cache as a choice in the picker is, and shows it, from the answer when that is
            // the set it shows, else through a read with the loading view. A reason, or the set still listed, fails
            // the delete and keeps the choice.
            case .deleteTagSetDone(let tagSetID, .success(let page)):
                state.isChangingTagSets = false
                take(page, into: &state)
                if let message = page.message {
                    return presentAlert(&state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: message)
                }
                guard !page.tagSetIDs.contains(tagSetID) else {
                    // Neither gone nor a reason: as with a create whose answer lists no new set, all the app knows
                    // is that the site did not do it.
                    return presentAlert(
                        &state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: AppError.unknown.alertText
                    )
                }
                // The picker always lists the page's own set, so the fallback names the set the answer shows.
                let firstTagSetID = page.tagSetIDs.first ?? page.tagSet.id
                state.$user.withLock({ $0.myTags = $0.myTags?.selecting(firstTagSetID) })
                guard firstTagSetID != page.tagSet.id else { return .none }
                state.loadingState = .loading
                return fetchTagSet(firstTagSetID, host: state.setting.galleryHost)

            case .deleteTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentAlert(
                    &state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: error.alertText
                )

            case .destination(.presented(.editor(.delegate(.removed)))):
                state.toast = .success(caption: .RLocalizable.myTagsRemoved)
                return .none

            case .openInBrowserTapped:
                state.destination = .browser(Defaults.URL.myTags(host: state.setting.galleryHost))
                return .none

            // The browser is a state-only destination, so closing it arrives here as nil rather than as a dismiss.
            // Closing the site's page reads My Tags again: the tags may have changed there.
            case .browserChanged(let url):
                guard url == nil, state.destination?.is(\.browser) == true else { return .none }
                state.destination = nil
                return .send(.fetchMyTags)

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$toast, action: \.toast)
        .ifLet(\.$newTagSetAlert, action: \.newTagSetAlert)
        .ifLet(\.$deleteTagSetDialog, action: \.deleteTagSetDialog)
    }

    /// Reads the set `tagSetID`'s page on `host`, in place of any read still on its way. It takes the id rather than
    /// reading the state's: right after a create, the new set is chosen but not yet in the cache, so the state's
    /// `selectedTagSetID` still names the first set.
    private func fetchTagSet(_ tagSetID: Int, host: GalleryHost) -> Effect<Action> {
        .run { send in
            let result = await Result.Swift::init { () async throws(AppError) in
                try await myTagsClient.fetchTagSet(host, tagSetID)
            }
            await send(.fetchTagSetDone(result))
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    /// Takes a page the site served into the cache, with its credentials.
    private func take(_ page: MyTagsPage, into state: inout State) {
        state.apiuid = page.apiuid
        state.apikey = page.apikey
        state.$user.withLock({ $0.myTags = $0.myTags?.applying(page) })
    }

    /// Puts the change into the cache at once, then sends the set as it now is; with `waits`, a second without another
    /// change first.
    private func changeTagSet(
        _ state: inout State,
        source: AlertSource,
        waits: Bool,
        change: (inout MyTagSet) -> Void
    ) -> Effect<Action> {
        guard var tagSet = state.selectedTagSet else { return .none }
        if state.confirmedTagSet == nil {
            state.confirmedTagSet = tagSet
        }
        change(&tagSet)
        state.$user.withLock({ $0.myTags = $0.myTags?.updating(tagSet) })
        let host = state.setting.galleryHost
        return .run { [tagSet] send in
            if waits {
                try await clock.sleep(for: .seconds(1))
            }
            let result = await Result.Swift::init { () async throws(AppError) in
                try await myTagsClient.updateTagSet(host, tagSet.id, tagSet.isEnabled, tagSet.color)
            }
            await send(.updateTagSetDone(source, result))
        }
        .cancellable(id: CancelID.updateTagSet, cancelInFlight: true)
    }

    private func presentAlert(
        _ state: inout State,
        _ source: AlertSource,
        title: LocalizedStringResource,
        message: String
    ) -> Effect<Action> {
        state.alertSource = source
        state.alert = .failure(title: title, message: message)
        return .none
    }
}

extension MyTagsFeature.Destination.State: Equatable, Sendable {}
