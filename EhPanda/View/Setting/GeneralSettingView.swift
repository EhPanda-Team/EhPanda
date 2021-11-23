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

    private var isTranslatesTagsVisible: Bool {
        guard let preferredLanguage = Locale.preferredLanguages.first else { return false }
        let isLanguageSupported = TranslatableLanguage.allCases.map(\.languageCode).contains(
            where: preferredLanguage.contains
        )
        return isLanguageSupported && !settings.tagTranslator.contents.isEmpty
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Language")
                    Spacer()
                    Button(language, action: tryNavigateToSystemSetting).foregroundStyle(.tint)
                }
                if isTranslatesTagsVisible {
                    Toggle(isOn: settingBinding.translatesTags) {
                        Text("Translates tags")
                    }
                }
                NavigationLink("Logs", destination: LogsView())
            }
            Section("Navigation".localized) {
                Toggle("Redirects links to the selected host", isOn: settingBinding.redirectsLinksToSelectedHost)
                Toggle("Detects links from the clipboard", isOn: settingBinding.detectsLinksFromPasteboard)
            }
            Section("Security".localized) {
                HStack {
                    Text("Auto-Lock")
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        .opacity((passcodeNotSet && setting.autoLockPolicy != .never) ? 1 : 0)
                    Picker(
                        selection: settingBinding.autoLockPolicy,
                        label: Text(setting.autoLockPolicy.descriptionKey)
                    ) {
                        ForEach(AutoLockPolicy.allCases) { policy in
                            Text(policy.descriptionKey).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Toggle("App switcher blur", isOn: settingBinding.allowsResignActiveBlur)
            }
            Section("Cache".localized) {
                Button {
                    store.dispatch(.setSettingViewActionSheetState(.clearImageCaches))
                } label: {
                    HStack {
                        Text("Clear image caches")
                        Spacer()
                        Text(setting.diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .onAppear(perform: checkPasscodeExistence)
        .navigationBarTitle("General")
    }
}

private extension GeneralSettingView {
    var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }
    var language: String {
        Locale.current.localizedString(forLanguageCode: Locale.current.languageCode ?? "") ?? "(null)"
    }

    func checkPasscodeExistence() {
        var error: NSError?

        guard !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
        passcodeNotSet = true
    }

    func tryNavigateToSystemSetting() {
        guard let settingURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingURL, options: [:])
    }
}
