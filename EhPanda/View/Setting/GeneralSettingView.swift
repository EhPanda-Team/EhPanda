//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import Kingfisher
import LocalAuthentication

struct GeneralSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var passcodeNotSet = false

    var body: some View {
        if let setting = setting,
           let settingBinding = settingBinding
        {
            Form {
                Section {
                    NavigationLink(destination: FilterView()) {
                        Text("Filters")
                    }
                    HStack {
                        Text("Language")
                        Spacer()
                        Button(language, action: toSettingLanguage)
                    }
                    Toggle(isOn: settingBinding.closeSlideMenuAfterSelection) {
                        Text("Close slide menu after selection")
                    }
                    Toggle(isOn: settingBinding.detectGalleryFromPasteboard) {
                        Text("Detect link from the clipboard")
                    }
                    if setting.detectGalleryFromPasteboard {
                        Toggle(isOn: settingBinding.allowsDetectionWhenNoChange) {
                            Text("Allows detection even when no change")
                        }
                    }
                }
                Section(header: Text("Security")) {
                    HStack {
                        Text("Auto-Lock")
                        Spacer()
                        if passcodeNotSet,
                           setting.autoLockPolicy != .never
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                        }
                        Picker(
                            selection: settingBinding.autoLockPolicy,
                            label: Text(setting.autoLockPolicy.rawValue.localized())
                        ) {
                            ForEach(AutoLockPolicy.allCases) { policy in
                                Text(policy.rawValue.localized()).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle(isOn: settingBinding.allowsResignActiveBlur, label: {
                        Text("App switcher blur")
                    })
                }
                Section(header: Text("Cache")) {
                    Button(action: toggleClearImgCaches) {
                        HStack {
                            Text("Clear image caches")
                            Spacer()
                            Text(setting.diskImageCacheSize)
                        }
                        .foregroundColor(.primary)
                    }
                    Button(action: toggleClearWebCaches) {
                        HStack {
                            Text("Clear web caches")
                            Spacer()
                            Text(browsingCaches())
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitle("General")
            .onAppear(perform: onAppear)
        }
    }
}

private extension GeneralSettingView {
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
