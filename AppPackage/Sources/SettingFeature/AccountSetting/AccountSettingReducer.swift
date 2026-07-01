import Foundation
import AppModels
import Resources
import ComposableArchitecture
import HapticsClient
import ClipboardClient
import CookieClient
import TTProgressHUDExt

@Reducer
public struct AccountSettingReducer: Sendable {
    // Transient copied-to-clipboard toast. Not navigation — drives the progressHUD overlay only.
    @CasePathable
    public enum HUD: Equatable, Sendable {
        case copiedToClipboard
    }

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

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var hud: HUD?
        public var ehCookiesState: CookiesState = .empty(.ehentai)
        public var exCookiesState: CookiesState = .empty(.exhentai)
        public var hudConfig: ProgressHUDConfigState = .copiedToClipboardSucceeded

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case presentWebView(URL)
        case confirmationDialog(PresentationAction<Dialog>)
        case delegate(Delegate)
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

            case .destination:
                return .none

            case .presentWebView(let url):
                state.destination = .webView(url)
                return .none

            case .delegate:
                return .none

            case .logoutButtonTapped:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmLogout) {
                        TextState(L10n.Localizable.ConfirmationDialog.Button.logout)
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.Button.cancel)
                    }
                } message: {
                    TextState(L10n.Localizable.ConfirmationDialog.Title.logout)
                }
                return .none

            case .confirmationDialog(.presented(.confirmLogout)):
                return .send(.onLogoutConfirmButtonTapped)

            case .confirmationDialog:
                return .none

            case .onLogoutConfirmButtonTapped:
                return .send(.loadCookies)

            case .loadCookies:
                state.ehCookiesState = cookieClient.loadCookiesState(host: .ehentai)
                state.exCookiesState = cookieClient.loadCookiesState(host: .exhentai)
                return .none

            case .copyCookies(let host):
                state.hud = .copiedToClipboard
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
    }
}

extension AccountSettingReducer.Destination.State: Equatable, Sendable {}
extension AccountSettingReducer.Destination.Action: Equatable, Sendable {}
