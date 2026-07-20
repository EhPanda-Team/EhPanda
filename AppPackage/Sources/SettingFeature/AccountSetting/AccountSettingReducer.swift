import AppComponents
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import CookieClient
import Foundation
import HapticsClient
import Resources

@Reducer
public struct AccountSettingReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case webView(URL)
    }

    public enum Dialog: Equatable, Sendable {
        case confirmLogout
    }

    // Pushes handled by SettingReducer, which owns the Setting navigation stack.
    public enum Delegate: Equatable, Sendable {
        case pushLogin
        case pushEhSetting
    }

    private enum CancelID { case observeCookies }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        @Presents public var toast: AppAlertState<Never>?
        public var ehCookiesState: CookiesState = .empty(.ehentai)
        public var exCookiesState: CookiesState = .empty(.exhentai)

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case presentWebView(URL)
        case confirmationDialog(PresentationAction<Dialog>)
        case delegate(Delegate)
        case onPresented
        case logoutButtonTapped
        case onLogoutConfirmButtonTapped
        case loadCookies
        case copyCookies(GalleryHost)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.ehCookiesState) { _, state in
                .run(operation: { [value = state.ehCookiesState] _ in cookieClient.setCookies(state: value) })
            }
            .onChange(of: \.exCookiesState) { _, state in
                .run(operation: { [value = state.exCookiesState] _ in cookieClient.setCookies(state: value) })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toast:
                return .none

            case .destination:
                return .none

            case .presentWebView(let url):
                state.destination = .webView(url)
                return .none

            case .delegate:
                return .none

            // Fires once, when SettingReducer pushes this screen. It does not need to re-fire on the
            // way back from the login/logout flows: the jar subscription below outlives those pushes
            // (the element stays on the stack, so its effects are not cancelled) and reloads the
            // cookie rows on every jar change, while the login/logout state on screen is read live
            // from `@SharedReader(.didLogin)`, which the same jar feeds.
            case .onPresented:
                return .merge(
                    .send(.loadCookies),
                    .run { send in
                        for await _ in cookieClient.cookiesDidChange() {
                            await send(.loadCookies)
                        }
                    }
                    .cancellable(id: CancelID.observeCookies, cancelInFlight: true)
                )

            case .logoutButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .logout)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmLogout) {
                        TextState(localized: .logout)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .logoutDescription)
                }
                return .none

            case .confirmationDialog(.presented(.confirmLogout)):
                return .send(.onLogoutConfirmButtonTapped)

            case .confirmationDialog:
                return .none

            // Kept as a no-op trigger: SettingReducer pattern-matches this case to clear the jar
            // and reset the shared user; the cookiesDidChange subscription above then reloads this
            // screen once the clear actually lands. (An eager `.send(.loadCookies)` here raced the
            // parent's `.run` clear effect and snapshotted the pre-logout cookies.)
            case .onLogoutConfirmButtonTapped:
                return .none

            case .loadCookies:
                state.ehCookiesState.applyJarSnapshot(cookieClient.loadCookiesState(host: .ehentai))
                state.exCookiesState.applyJarSnapshot(cookieClient.loadCookiesState(host: .exhentai))
                return .none

            case .copyCookies(let host):
                state.toast = .copiedToClipboardSucceeded
                let cookiesDescription = cookieClient.getCookiesDescription(host: host)
                return .merge(
                    .run(operation: { _ in clipboardClient.saveText(cookiesDescription) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )

            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.webView,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
        .ifLet(\.$toast, action: \.toast)
    }
}

extension AccountSettingReducer.Destination.State: Equatable, Sendable {}
extension AccountSettingReducer.Destination.Action: Equatable, Sendable {}

// Echo-guard. The jar notifies for this screen's own write-backs too: every keystroke commits
// through the `.onChange` → `setCookies` path, which trims whitespace before writing. Reloading on
// that echo would replace the focused TextField's text — dropping a just-typed trailing space and
// jumping the cursor. So each cookie buffer only accepts a jar snapshot its own pending write-back
// could NOT have produced. Guarding per cookie (not per host) keeps an external igneous refresh
// from clobbering a concurrently-edited sibling field; the key comparison forces the very first
// load over the keyless `.empty` placeholder state.
extension CookiesState {
    fileprivate mutating func applyJarSnapshot(_ fresh: CookiesState) {
        igneous.applyJarSnapshot(fresh.igneous)
        memberID.applyJarSnapshot(fresh.memberID)
        passHash.applyJarSnapshot(fresh.passHash)
    }
}

extension CookieState {
    fileprivate mutating func applyJarSnapshot(_ fresh: CookieState) {
        guard key != fresh.key
            || editingText.trimmingCharacters(in: .whitespaces) != fresh.value.rawValue
        else { return }
        self = fresh
    }
}
