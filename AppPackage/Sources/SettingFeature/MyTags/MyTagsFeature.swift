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
        public var alertSource: AlertSource?
        public var loadingState: LoadingState = .idle
        /// The edit API's credentials of the last page read; in memory only.
        public var apiuid: Int?
        public var apikey: String?
        /// The tag set as the site last had it while an Enabled or colour change is on its way.
        public var confirmedTagSet: MyTagSet?

        public init() {}

        public var selectedTagSet: MyTagSet? { user.myTags?.selectedTagSet }
        public var selectedTagSetID: Int { selectedTagSet?.id ?? 1 }
        public var isTagSetEnabled: Bool { selectedTagSet?.isEnabled ?? false }
        public var tagSetColor: SiteColor? { selectedTagSet?.color }
        public var tagSetWellColor: Color { selectedTagSet?.color?.color ?? .clear }
        /// The site's page the browser sheet shows; get-only, so the sheet binds through `browserChanged`.
        public var browserURL: URL? { destination?.browser }
    }

    public enum Action {
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Never>)
        case toast(PresentationAction<Never>)
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
            case .alert, .toast, .delegate:
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
                return fetchTagSet(state)

            case .refresh:
                return fetchTagSet(state)

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
    }

    private func fetchTagSet(_ state: State) -> Effect<Action> {
        let host = state.setting.galleryHost
        let tagSetID = state.selectedTagSetID
        return .run { send in
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
