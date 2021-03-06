//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import TTProgressHUD

struct AccountSettingView: View {
    @EnvironmentObject var store: Store
    @State var inEditMode = false
    
    @State var hudVisible = false
    @State var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )
    
    var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }
    
    var ehURL: URL {
        Defaults.URL.ehentai.safeURL()
    }
    var exURL: URL {
        Defaults.URL.exhentai.safeURL()
    }
    var yayKey: String {
        Defaults.Cookie.yay
    }
    var igneousKey: String {
        Defaults.Cookie.igneous
    }
    var memberIDKey: String {
        Defaults.Cookie.ipb_member_id
    }
    var passHashKey: String {
        Defaults.Cookie.ipb_pass_hash
    }
    var yay: CookieValue {
        getCookieValue(url: exURL, key: yayKey)
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
    func verifyView(
        _ value: CookieValue,
        _ isYay: Bool = false
    ) -> some View {
        Group {
            if !value.lString.isEmpty {
                if isYay && value.rawValue.isEmpty {
                    verifiedView
                } else {
                    notVerifiedView
                }
            } else {
                verifiedView
            }
        }
    }
    
    // MARK: AccountSettingView
    var body: some View {
        ZStack {
            Form {
                if let settingBinding = settingBinding {
                    Section {
                        Picker(
                            selection: settingBinding.galleryType,
                            label: Text("ギャラリー"),
                            content: {
                                let galleryTypes: [GalleryType] = [.eh, .ex]
                                ForEach(galleryTypes, id: \.self) {
                                    Text($0.rawValue.lString())
                                }
                            })
                            .pickerStyle(SegmentedPickerStyle())
                        if !didLogin {
                            Button("ログイン", action: onLoginTap)
                                .withArrow()
                        } else {
                            Button("ログアウト", action: onLogoutTap)
                                .foregroundColor(.red)
                        }
                        if didLogin {
                            Group {
                                Button("アカウント設定", action: onConfigTap)
                                    .withArrow()
                                Button("タグの購読を管理", action: onMyTagsTap)
                                    .withArrow()
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
                    Button("クッキーをコピー", action: copyEhCookies)
                }
                Section(header: Text("ExHentai")) {
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: yayKey,
                        value: yay,
                        verifyView: verifyView(yay, true),
                        editChangedAction: onYayEditingChanged
                    )
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
                    Button("クッキーをコピー", action: copyExCookies)
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .navigationBarTitle("アカウント")
        .navigationBarItems(trailing:
            Button(inEditMode ? "完了" : "編集", action: onEditButtonTap)
        )
        
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
    func onYayEditingChanged(_ value: String) {
        setCookieValue(url: exURL, key: yayKey, value: value)
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
            type: .Success,
            title: "成功".lString(),
            caption: "クリップボードにコピーしました".lString(),
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
    var inEditModeBinding: Binding<Bool>
    var inEditMode: Bool {
        inEditModeBinding.wrappedValue
    }
    @State var content: String
    
    let key: String
    let value: String
    let verifyView: VerifyView
    let editChangedAction: ((String)->())
    
    init(
        inEditMode: Binding<Bool>,
        key: String,
        value: CookieValue,
        verifyView: VerifyView,
        editChangedAction: @escaping ((String)->())
    ) {
        self.inEditModeBinding = inEditMode
        _content = State(initialValue: value.rawValue)
        
        self.key = key
        self.value = value.lString.isEmpty
            ? value.rawValue : value.lString
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
    
    func onContentChanged(_ value: String) {
        editChangedAction(value)
    }
}

// MARK: Definition
public struct CookieValue {
    let rawValue: String
    let lString: String
}
