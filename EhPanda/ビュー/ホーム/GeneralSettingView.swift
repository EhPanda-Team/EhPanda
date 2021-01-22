//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import Kingfisher

struct GeneralSettingView: View {
    @EnvironmentObject var store: Store
    
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
                    Toggle(isOn: settingBinding.closeSlideMenuAfterSelection, label: {
                        Text("選択後スライドメニューを閉じる")
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
