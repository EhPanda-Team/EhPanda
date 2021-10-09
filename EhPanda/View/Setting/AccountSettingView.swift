//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import TTProgressHUD

struct AccountSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    private let ehURL = Defaults.URL.ehentai.safeURL()
    private let exURL = Defaults.URL.exhentai.safeURL()
    private let igneousKey = Defaults.Cookie.igneous
    private let memberIDKey = Defaults.Cookie.ipbMemberId
    private let passHashKey = Defaults.Cookie.ipbPassHash

    // MARK: AccountSettingView
    var body: some View {
        ZStack {
            Form {
                Section {
                    Picker(
                        selection: settingBinding.galleryHost,
                        label: Text("Gallery"),
                        content: {
                            ForEach(GalleryHost.allCases) {
                                Text($0.rawValue.localized).tag($0)
                            }
                        }
                    )
                    .pickerStyle(.segmented)
                    if !AuthorizationUtil.didLogin {
                        NavigationLink("Login", destination: LoginView())
                            .foregroundStyle(.tint)
                    } else {
                        Button("Logout", role: .destructive, action: toggleLogout)
                    }
                    if AuthorizationUtil.didLogin {
                        Group {
                            NavigationLink("Account configuration", destination: EhSettingView())
                            if !setting.bypassesSNIFiltering {
                                Button("Manage tags subscription", action: toggleWebViewMyTags).withArrow()
                            }
                            Toggle(
                                "Show new dawn greeting",
                                isOn: settingBinding.showNewDawnGreeting
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
                Section(header: Text("E-Hentai")) {
                    CookieRow(
                        key: memberIDKey,
                        value: ehMemberID,
                        submitAction: onEhEditingChange
                    )
                    CookieRow(
                        key: passHashKey,
                        value: ehPassHash,
                        submitAction: onEhEditingChange
                    )
                    Button("Copy cookies", action: copyEhCookies)
                        .foregroundStyle(.tint)
                        .font(.subheadline)
                }
                Section(header: Text("ExHentai")) {
                    CookieRow(
                        key: igneousKey,
                        value: igneous,
                        submitAction: onExEditingChange
                    )
                    CookieRow(
                        key: memberIDKey,
                        value: exMemberID,
                        submitAction: onExEditingChange
                    )
                    CookieRow(
                        key: passHashKey,
                        value: exPassHash,
                        submitAction: onExEditingChange
                    )
                    Button("Copy cookies", action: copyExCookies)
                        .foregroundStyle(.tint)
                        .font(.subheadline)
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .navigationBarTitle("Account")
    }
}

private extension AccountSettingView {
    var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }

    // MARK: Cookies Methods
    var igneous: CookieValue {
        CookiesUtil.get(for: exURL, key: igneousKey)
    }
    var ehMemberID: CookieValue {
        CookiesUtil.get(for: ehURL, key: memberIDKey)
    }
    var exMemberID: CookieValue {
        CookiesUtil.get(for: exURL, key: memberIDKey)
    }
    var ehPassHash: CookieValue {
        CookiesUtil.get(for: ehURL, key: passHashKey)
    }
    var exPassHash: CookieValue {
        CookiesUtil.get(for: exURL, key: passHashKey)
    }
    func onEhEditingChange(key: String, value: String) {
        setCookieValue(url: ehURL, key: key, value: value)
    }
    func onExEditingChange(key: String, value: String) {
        setCookieValue(url: exURL, key: key, value: value)
    }
    func setCookieValue(url: URL, key: String, value: String) {
        if CookiesUtil.checkExistence(for: url, key: key) {
            CookiesUtil.edit(for: url, key: key, value: value)
        } else {
            CookiesUtil.set(for: url, key: key, value: value)
        }
    }
    func copyEhCookies() {
        let cookies = "\(memberIDKey): \(ehMemberID.rawValue)"
            + "\n\(passHashKey): \(ehPassHash.rawValue)"
        PasteboardUtil.save(value: cookies)
        showCopiedHUD()
    }
    func copyExCookies() {
        let cookies = "\(igneousKey): \(igneous.rawValue)"
            + "\n\(memberIDKey): \(exMemberID.rawValue)"
            + "\n\(passHashKey): \(exPassHash.rawValue)"
        PasteboardUtil.save(value: cookies)
        showCopiedHUD()
    }
    func showCopiedHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .success,
            title: "Success".localized,
            caption: "Copied to clipboard".localized,
            shouldAutoHide: true,
            autoHideInterval: 1
        )
        hudVisible.toggle()
    }

    // MARK: Dispatch Methods
    func toggleWebViewMyTags() {
        store.dispatch(.toggleSettingViewSheet(state: .webviewMyTags))
    }
    func toggleLogout() {
        store.dispatch(.toggleSettingViewActionSheet(state: .logout))
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @State private var content: String

    private let key: String
    private let value: String
    private let cookieValue: CookieValue
    private let submitAction: (String, String) -> Void
    private var notVerified: Bool {
        !cookieValue.localizedString.isEmpty
            && !cookieValue.rawValue.isEmpty
    }

    init(
        key: String, value: CookieValue,
        submitAction: @escaping (String, String) -> Void
    ) {
        _content = State(initialValue: value.rawValue)

        self.key = key
        self.value = value.localizedString.isEmpty
            ? value.rawValue : value.localizedString
        self.cookieValue = value
        self.submitAction = submitAction
    }

    var body: some View {
        HStack {
            Text(key)
            Spacer()
            ZStack {
                TextField(value, text: $content)
                    .submitLabel(.done)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.none)
                    .onChange(of: content) {
                        submitAction(key, $0)
                    }
            }
            ZStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                    .opacity(notVerified ? 0 : 1)
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
                    .opacity(notVerified ? 1 : 0)
            }
        }
    }

    private func onTextSubmit() {
        submitAction(key, content)
    }
}

// MARK: Definition
struct CookieValue {
    let rawValue: String
    let localizedString: String
}
