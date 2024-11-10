//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import ComposableArchitecture

struct AccountSettingView: View {
    @Bindable private var store: StoreOf<AccountSettingReducer>
    @Binding private var galleryHost: GalleryHost
    @Binding private var showsNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    init(
        store: StoreOf<AccountSettingReducer>,
        galleryHost: Binding<GalleryHost>, showsNewDawnGreeting: Binding<Bool>,
        bypassesSNIFiltering: Bool, blurRadius: Double
    ) {
        self.store = store
        _galleryHost = galleryHost
        _showsNewDawnGreeting = showsNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
    }

    // MARK: AccountSettingView
    var body: some View {
        Form {
            Section {
                Picker("", selection: $galleryHost) {
                    ForEach(GalleryHost.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                AccountSection(
                    route: $store.route,
                    showsNewDawnGreeting: $showsNewDawnGreeting,
                    bypassesSNIFiltering: bypassesSNIFiltering,
                    loginAction: { store.send(.setNavigation(.login)) },
                    logoutAction: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            store.send(.onLogoutConfirmButtonTapped)
                        }
                    },
                    logoutDialogAction: { store.send(.setNavigation(.logout)) },
                    configureAccountAction: { store.send(.setNavigation(.ehSetting)) },
                    manageTagsAction: { store.send(.setNavigation(.webView(Defaults.URL.myTags))) }
                )
            }
            CookieSection(
                ehCookiesState: $store.ehCookiesState,
                exCookiesState: $store.exCookiesState,
                copyAction: { store.send(.copyCookies($0)) }
            )
        }
        .progressHUD(
            config: store.hudConfig,
            unwrapping: $store.route,
            case: \.hud
        )
        .sheet(item: $store.route.sending(\.setNavigation).webView, id: \.absoluteString) { url in
            WebView(url: url)
                .autoBlur(radius: blurRadius)
        }
        .onAppear { store.send(.loadCookies) }
        .background(navigationLinks)
        .navigationTitle(L10n.Localizable.AccountSettingView.Title.account)
    }
}

// MARK: NavigationLinks
private extension AccountSettingView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: $store.route, case: \.login) { _ in
            LoginView(
                store: store.scope(state: \.loginState, action: \.login),
                bypassesSNIFiltering: bypassesSNIFiltering, blurRadius: blurRadius
            )
        }
        NavigationLink(unwrapping: $store.route, case: \.ehSetting) { _ in
            EhSettingView(
                store: store.scope(state: \.ehSettingState, action: \.ehSetting),
                bypassesSNIFiltering: bypassesSNIFiltering, blurRadius: blurRadius
            )
        }
    }
}

// MARK: AccountSection
private struct AccountSection: View {
    @Binding private var route: AccountSettingReducer.Route?
    @Binding private var showsNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let loginAction: () -> Void
    private let logoutAction: () -> Void
    private let logoutDialogAction: () -> Void
    private let configureAccountAction: () -> Void
    private let manageTagsAction: () -> Void

    init(
        route: Binding<AccountSettingReducer.Route?>,
        showsNewDawnGreeting: Binding<Bool>, bypassesSNIFiltering: Bool,
        loginAction: @escaping () -> Void, logoutAction: @escaping () -> Void,
        logoutDialogAction: @escaping () -> Void,
        configureAccountAction: @escaping () -> Void,
        manageTagsAction: @escaping () -> Void
    ) {
        _route = route
        _showsNewDawnGreeting = showsNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.loginAction = loginAction
        self.logoutAction = logoutAction
        self.logoutDialogAction = logoutDialogAction
        self.configureAccountAction = configureAccountAction
        self.manageTagsAction = manageTagsAction
    }

    var body: some View {
        if !CookieUtil.didLogin {
            Button(L10n.Localizable.AccountSettingView.Button.login, action: loginAction)
        } else {
            Button(
                L10n.Localizable.ConfirmationDialog.Button.logout,
                role: .destructive, action: logoutDialogAction
            )
            .confirmationDialog(
                message: L10n.Localizable.ConfirmationDialog.Title.logout,
                unwrapping: $route,
                case: \.logout
            ) {
                Button(
                    L10n.Localizable.ConfirmationDialog.Button.logout,
                    role: .destructive, action: logoutAction
                )
            }
            Group {
                Button(
                    L10n.Localizable.AccountSettingView.Button.accountConfiguration,
                    action: configureAccountAction
                )
                .withArrow()
                if !bypassesSNIFiltering {
                    Button(
                        L10n.Localizable.AccountSettingView.Button.tagsManagement,
                        action: manageTagsAction
                    )
                    .withArrow()
                }
                Toggle(L10n.Localizable.AccountSettingView.Title.showsNewDawnGreeting, isOn: $showsNewDawnGreeting)
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: CookieSection
private struct CookieSection: View {
    @Binding private var ehCookiesState: CookiesState
    @Binding private var exCookiesState: CookiesState
    private let copyAction: (GalleryHost) -> Void

    init(
        ehCookiesState: Binding<CookiesState>,
        exCookiesState: Binding<CookiesState>,
        copyAction: @escaping (GalleryHost) -> Void
    ) {
        _ehCookiesState = ehCookiesState
        _exCookiesState = exCookiesState
        self.copyAction = copyAction
    }

    var body: some View {
        Section(GalleryHost.ehentai.rawValue) {
            CookieRow(cookieState: $ehCookiesState.memberID)
            CookieRow(cookieState: $ehCookiesState.passHash)
            Button(L10n.Localizable.AccountSettingView.Button.copyCookies) {
                copyAction(.ehentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
        Section(GalleryHost.exhentai.rawValue) {
            CookieRow(cookieState: $exCookiesState.igneous)
            CookieRow(cookieState: $exCookiesState.memberID)
            CookieRow(cookieState: $exCookiesState.passHash)
            Button(L10n.Localizable.AccountSettingView.Button.copyCookies) {
                copyAction(.exhentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @Binding private var cookieState: CookieState

    init(cookieState: Binding<CookieState>) {
        _cookieState = cookieState
    }

    var body: some View {
        HStack {
            Text(cookieState.key)
            Spacer()
            TextField(cookieState.value.placeholder, text: $cookieState.editingText)
                .submitLabel(.done).disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.none)
            Image(systemSymbol: cookieState.value.isInvalid ? .xmarkCircle : .checkmarkCircle)
                .foregroundStyle(cookieState.value.isInvalid ? .red : .green)
        }
    }
}

struct AccountSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountSettingView(
                store: .init(initialState: .init(), reducer: AccountSettingReducer.init),
                galleryHost: .constant(.ehentai),
                showsNewDawnGreeting: .constant(false),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
