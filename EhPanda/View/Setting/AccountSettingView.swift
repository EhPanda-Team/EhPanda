//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import TTProgressHUD

struct AccountSettingView: View {
    @EnvironmentObject private var store: Store
    @State private var inEditMode = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )

    // MARK: AccountSettingView
    var body: some View {
        ZStack {
            Form {
                if let settingBinding = settingBinding {
                    Section {
                        Picker(
                            selection: settingBinding.galleryType,
                            label: Text("Gallery"),
                            content: {
                                let galleryTypes: [GalleryType] = [.ehentai, .exhentai]
                                ForEach(galleryTypes, id: \.self) {
                                    Text($0.rawValue.localized())
                                }
                            })
                            .pickerStyle(SegmentedPickerStyle())
                        if !didLogin {
                            Button("Login", action: onLoginTap)
                                .withArrow()
                        } else {
                            Button("Logout", action: onLogoutTap)
                                .foregroundColor(.red)
                        }
                        if didLogin {
                            Group {
                                Button("Account configuration", action: onConfigTap)
                                    .withArrow()
                                Button("Manage tags subscription", action: onMyTagsTap)
                                    .withArrow()
                                Toggle(
                                    "Show new dawn greeting",
                                    isOn: settingBinding.showNewDawnGreeting
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                Section(header: Text("E-Hentai")) {
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: memberIDKey,
                        value: ehMemberID,
                        verifyView: verifyView(ehMemberID),
                        editChangedAction: onEhMemberIDEditingChanged
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: passHashKey,
                        value: ehPassHash,
                        verifyView: verifyView(ehPassHash),
                        editChangedAction: onEhPassHashEditingChanged
                    )
                    Button("Copy cookies", action: copyEhCookies)
                }
                Section(header: Text("ExHentai")) {
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: igneousKey,
                        value: igneous,
                        verifyView: verifyView(igneous),
                        editChangedAction: onIgneousEditingChanged
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: memberIDKey,
                        value: exMemberID,
                        verifyView: verifyView(exMemberID),
                        editChangedAction: onExMemberIDEditingChanged
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: passHashKey,
                        value: exPassHash,
                        verifyView: verifyView(exPassHash),
                        editChangedAction: onExPassHashEditingChanged
                    )
                    Button("Copy cookies", action: copyExCookies)
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .navigationBarTitle("Account")
        .navigationBarItems(trailing:
            Button(inEditMode ? "Finish" : "Edit", action: onEditButtonTap)
        )
    }
}

private extension AccountSettingView {
    var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }

    var ehURL: URL {
        Defaults.URL.ehentai.safeURL()
    }
    var exURL: URL {
        Defaults.URL.exhentai.safeURL()
    }
    var igneousKey: String {
        Defaults.Cookie.igneous
    }
    var memberIDKey: String {
        Defaults.Cookie.ipbMemberId
    }
    var passHashKey: String {
        Defaults.Cookie.ipbPassHash
    }
    var igneous: CookieValue {
        getCookieValue(url: exURL, key: igneousKey)
    }
    var ehMemberID: CookieValue {
        getCookieValue(url: ehURL, key: memberIDKey)
    }
    var exMemberID: CookieValue {
        getCookieValue(url: exURL, key: memberIDKey)
    }
    var ehPassHash: CookieValue {
        getCookieValue(url: ehURL, key: passHashKey)
    }
    var exPassHash: CookieValue {
        getCookieValue(url: exURL, key: passHashKey)
    }

    var verifiedView: some View {
        Image(systemName: "checkmark.circle")
            .foregroundColor(.green)
    }
    var notVerifiedView: some View {
        Image(systemName: "xmark.circle")
            .foregroundColor(.red)
    }
    func verifyView(_ value: CookieValue) -> some View {
        Group {
            if !value.localizedString.isEmpty {
                if value.rawValue.isEmpty {
                    verifiedView
                } else {
                    notVerifiedView
                }
            } else {
                verifiedView
            }
        }
    }

    func onEditButtonTap() {
        inEditMode.toggle()
    }
    func onLoginTap() {
        toggleWebViewLogin()
    }
    func onConfigTap() {
        toggleWebViewConfig()
    }
    func onMyTagsTap() {
        toggleWebViewMyTags()
    }
    func onLogoutTap() {
        toggleLogout()
    }

    func onEhMemberIDEditingChanged(_ value: String) {
        setCookieValue(url: ehURL, key: memberIDKey, value: value)
    }
    func onEhPassHashEditingChanged(_ value: String) {
        setCookieValue(url: ehURL, key: passHashKey, value: value)
    }
    func onIgneousEditingChanged(_ value: String) {
        setCookieValue(url: exURL, key: igneousKey, value: value)
    }
    func onExMemberIDEditingChanged(_ value: String) {
        setCookieValue(url: exURL, key: memberIDKey, value: value)
    }
    func onExPassHashEditingChanged(_ value: String) {
        setCookieValue(url: exURL, key: passHashKey, value: value)
    }

    func setCookieValue(url: URL, key: String, value: String) {
        if checkExistence(url: url, key: key) {
            editCookie(url: url, key: key, value: value)
        } else {
            setCookie(url: url, key: key, value: value)
        }
    }
    func copyEhCookies() {
        let cookies = "\(memberIDKey): \(ehMemberID.rawValue)"
            + "\n\(passHashKey): \(ehPassHash.rawValue)"
        saveToPasteboard(cookies)
        showCopiedHUD()
    }
    func copyExCookies() {
        let cookies = "\(igneousKey): \(igneous.rawValue)"
            + "\n\(memberIDKey): \(exMemberID.rawValue)"
            + "\n\(passHashKey): \(exPassHash.rawValue)"
        saveToPasteboard(cookies)
        showCopiedHUD()
    }

    func showCopiedHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .success,
            title: "Success".localized(),
            caption: "Copied to clipboard".localized(),
            shouldAutoHide: true,
            autoHideInterval: 2,
            hapticsEnabled: false
        )
        hudVisible.toggle()
    }

    func toggleWebViewLogin() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewLogin))
    }
    func toggleWebViewConfig() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewConfig))
    }
    func toggleWebViewMyTags() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewMyTags))
    }
    func toggleLogout() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .logout))
    }
}

// MARK: CookieRow
private struct CookieRow<VerifyView: View>: View {
    private var inEditModeBinding: Binding<Bool>
    private var inEditMode: Bool {
        inEditModeBinding.wrappedValue
    }
    @State private var content: String

    private let key: String
    private let value: String
    private let verifyView: VerifyView
    private let editChangedAction: (String) -> Void

    init(
        inEditMode: Binding<Bool>,
        key: String,
        value: CookieValue,
        verifyView: VerifyView,
        editChangedAction: @escaping (String) -> Void
    ) {
        self.inEditModeBinding = inEditMode
        _content = State(initialValue: value.rawValue)

        self.key = key
        self.value = value.localizedString.isEmpty
            ? value.rawValue : value.localizedString
        self.verifyView = verifyView
        self.editChangedAction = editChangedAction
    }

    var body: some View {
        HStack {
            Text(key)
            Spacer()
            if inEditMode {
                TextField(
                    value,
                    text: $content,
                    onEditingChanged: { _ in },
                    onCommit: {}
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
                .onChange(of: content, perform: onContentChanged)
            } else {
                Text(value)
                    .lineLimit(1)
            }
            verifyView
        }
    }

    private func onContentChanged(_ value: String) {
        editChangedAction(value)
    }
}

// MARK: Definition
struct CookieValue {
    let rawValue: String
    let localizedString: String
}
