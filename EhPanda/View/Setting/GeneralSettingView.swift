//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import Kingfisher
import SwiftyBeaver
import LocalAuthentication

struct GeneralSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var passcodeNotSet = false
    @State private var diskImageCacheSize = "0 KB"
    @State private var clearDialogPresented = false

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
                VStack(alignment: .leading) {
                    Text("App switcher blur")
                    HStack {
                        Image(systemName: "eye")
                        Slider(value: settingBinding.backgroundBlurRadius, in: 0...100, step: 10)
                        Image(systemName: "eye.slash")
                    }
                }
            }
            Section("Cache".localized) {
                Button {
                    clearDialogPresented = true
                } label: {
                    HStack {
                        Text("Clear image caches")
                        Spacer()
                        Text(diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .confirmationDialog(
            "Are you sure to clear?",
            isPresented: $clearDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive, action: clearImageCaches)
        }
        .onAppear(perform: onStartTasks).navigationBarTitle("General")
    }
}
private extension GeneralSettingView {
    var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }
    var language: String {
        Locale.current.localizedString(forLanguageCode: Locale.current.languageCode ?? "") ?? "(null)"
    }

    func onStartTasks() {
        checkPasscodeExistence()
        calculateDiskCachesSize()
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

    func readableUnit<I: BinaryInteger>(bytes: I) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        return formatter.string(fromByteCount: Int64(bytes))
    }
    func calculateDiskCachesSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                diskImageCacheSize = readableUnit(bytes: size)
            case .failure(let error):
                SwiftyBeaver.error(error)
            }
        }
    }
    func clearImageCaches() {
        KingfisherManager.shared.cache.clearDiskCache()
        PersistenceController.removeImageURLs()
        calculateDiskCachesSize()
    }
}
