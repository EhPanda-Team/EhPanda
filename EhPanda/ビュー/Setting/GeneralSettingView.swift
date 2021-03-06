//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import Kingfisher
import LocalAuthentication

struct GeneralSettingView: View {
    @EnvironmentObject var store: Store
    @State var passcodeNotSet = false
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }
    var language: String {
        if let code = Locale.current.languageCode,
           let lang = Locale.current.localizedString(
            forLanguageCode: code
           )
        {
            return lang
        } else {
            return "(null)"
        }
    }
    
    var body: some View {
        if let setting = setting,
           let settingBinding = settingBinding
        {
            Form {
                Section {
                    HStack {
                        Text("言語")
                        Spacer()
                        Button(language, action: toSettingLanguage)
                    }
                    Toggle(isOn: settingBinding.closeSlideMenuAfterSelection) {
                        Text("選択後スライドメニューを閉じる")
                    }
                    if exx {
                        Toggle(isOn: settingBinding.detectGalleryFromPasteboard) {
                            Text("クリップボードからリンクを探知")
                        }
                        if setting.detectGalleryFromPasteboard {
                            Toggle(isOn: settingBinding.allowsDetectionWhenNoChange) {
                                Text("変化なしの場合でも探知を有効化")
                            }
                        }
                    }
                }
                Section(header: Text("セキュリティ")) {
                    HStack {
                        Text("自動ロック")
                        Spacer()
                        if passcodeNotSet,
                           setting.autoLockPolicy != .never
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                        }
                        Picker(
                            selection: settingBinding.autoLockPolicy,
                            label: Text(setting.autoLockPolicy.rawValue.lString())
                        ) {
                            ForEach(AutoLockPolicy.allCases) { policy in
                                Text(policy.rawValue.lString()).tag(policy)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    Toggle(isOn: settingBinding.allowsResignActiveBlur, label: {
                        Text("アプリスイッチャーぼかし")
                    })
                }
                Section(header: Text("キャッシュ")) {
                    Button(action: toggleClearImgCaches) {
                        HStack {
                            Text("画像キャッシュを削除")
                            Spacer()
                            Text(setting.diskImageCacheSize)
                        }
                        .foregroundColor(.primary)
                    }
                    Button(action: toggleClearWebCaches) {
                        HStack {
                            Text("ウェブキャッシュを削除")
                            Spacer()
                            Text(browsingCaches())
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitle("一般")
            .onAppear(perform: onAppear)
        }
    }
    
    func onAppear() {
        checkPasscodeExistence()
    }
    
    func checkPasscodeExistence() {
        let context = LAContext()
        var error: NSError?

        if !context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &error
        ) {
            passcodeNotSet = true
        }
    }
    
    func toSettingLanguage() {
        if let settingURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingURL, options: [:])
        }
    }
    
    func toggleClearImgCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearImgCaches))
    }
    func toggleClearWebCaches() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .clearWebCaches))
    }
}
