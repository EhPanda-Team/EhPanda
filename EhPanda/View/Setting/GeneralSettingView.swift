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
                    HStack {
                        Text("Language")
                        Spacer()
                        Button(language, action: toSettingLanguage)
                    }
                    Toggle(
                        "Close slide menu after selection",
                        isOn: settingBinding.closeSlideMenuAfterSelection
                    )
                    Toggle(
                        "Detect link from the clipboard",
                        isOn: settingBinding.detectGalleryFromPasteboard
                    )
                    Toggle(
                        "Allows detection even when no change",
                        isOn: settingBinding.allowsDetectionWhenNoChange
                    )
                    .disabled(!setting.detectGalleryFromPasteboard)
                }
                Section(header: Text("Security")) {
                    HStack {
                        Text("Auto-Lock")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            .opacity((passcodeNotSet && setting.autoLockPolicy != .never) ? 1 : 0)
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
                    Toggle(
                        "App switcher blur",
                        isOn: settingBinding.allowsResignActiveBlur
                    )
                }
                Section(header: Text("Cache")) {
                    Button(action: toggleClearImgCaches) {
                        HStack {
                            Text("Clear image caches")
                            Spacer()
                            Text(setting.diskImageCacheSize)
                                .foregroundStyle(.tint)
                        }
                        .foregroundColor(.primary)
                    }
                }
                Section(header: Text("Advanced")) {
                    NavigationLink("Logs", destination: LogsView())
                    NavigationLink("Filters", destination: FilterView())
                }
            }
            .navigationBarTitle("General")
            .task(checkPasscodeExistence)
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
        store.dispatch(.toggleSettingViewActionSheet(state: .clearImgCaches))
    }
}
