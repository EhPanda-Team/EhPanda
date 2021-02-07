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
    @State var hudConfig = TTProgressHUDConfig()
    
    var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }
    
    var ehURL: URL {
        URL(string: Defaults.URL.ehentai)!
    }
    var exURL: URL {
        URL(string: Defaults.URL.exhentai)!
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
            if !value.lString.isEmpty {
                notVerifiedView
            } else {
                verifiedView
            }
        }
    }
    
    // MARK: AccountSettingView本体
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
                        if didLogin {
                            Text("ログイン済み")
                                .foregroundColor(.gray)
                        } else {
                            Button("ログイン", action: onLoginTap)
                        }

                        Button(action: onLogoutTap) {
                            Text("ログアウト")
                                .foregroundColor(.red)
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
        toggleWebView()
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
            type: .Success,
            title: "成功".lString(),
            caption: "クリップボードにコピーしました".lString(),
            shouldAutoHide: true,
            autoHideInterval: 2
        )
        hudVisible.toggle()
    }
    
    func toggleWebView() {
        store.dispatch(.toggleSettingViewSheetState(state: .webview))
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

// MARK: 定義
public struct CookieValue {
    let rawValue: String
    let lString: String
}
