//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct GeneralSettingView: View {
    private let store: Store<GeneralSettingState, GeneralSettingAction>
    @ObservedObject private var viewStore: ViewStore<GeneralSettingState, GeneralSettingAction>
    private let tagTranslatorLoadingState: LoadingState
    private let tagTranslatorEmpty: Bool
    @Binding private var translatesTags: Bool
    @Binding private var redirectsLinksToSelectedHost: Bool
    @Binding private var detectsLinksFromPasteboard: Bool
    @Binding private var backgroundBlurRadius: Double
    @Binding private var autoLockPolicy: AutoLockPolicy

    init(
        store: Store<GeneralSettingState, GeneralSettingAction>,
        tagTranslatorLoadingState: LoadingState, tagTranslatorEmpty: Bool, translatesTags: Binding<Bool>,
        redirectsLinksToSelectedHost: Binding<Bool>, detectsLinksFromPasteboard: Binding<Bool>,
        backgroundBlurRadius: Binding<Double>, autoLockPolicy: Binding<AutoLockPolicy>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.tagTranslatorLoadingState = tagTranslatorLoadingState
        self.tagTranslatorEmpty = tagTranslatorEmpty
        _translatesTags = translatesTags
        _redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        _detectsLinksFromPasteboard = detectsLinksFromPasteboard
        _backgroundBlurRadius = backgroundBlurRadius
        _autoLockPolicy = autoLockPolicy
    }

    private var language: String {
        Locale.current.localizedString(forLanguageCode: Locale.current.languageCode ?? "") ?? "(null)"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Language")
                    Spacer()
                    Button(language) {
                        viewStore.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                HStack {
                    Text("Translates tags")
                    Spacer()
                    ZStack {
                        Image(systemSymbol: .exclamationmarkTriangleFill).foregroundStyle(.yellow)
                            .opacity(
                                translatesTags && tagTranslatorEmpty
                                && tagTranslatorLoadingState != .loading ? 1 : 0
                            )
                        ProgressView().tint(nil).opacity(tagTranslatorLoadingState == .loading ? 1 : 0)
                    }
                    Toggle("", isOn: $translatesTags).frame(width: 50)
                }
                Button("Logs") {
                    viewStore.send(.setNavigation(.logs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section("Navigation".localized) {
                Toggle("Redirects links to the selected host", isOn: $redirectsLinksToSelectedHost)
                Toggle("Detects links from the clipboard", isOn: $detectsLinksFromPasteboard)
            }
            Section("Security".localized) {
                HStack {
                    Text("Auto-Lock")
                    Spacer()
                    Image(systemSymbol: .exclamationmarkTriangleFill).foregroundStyle(.yellow)
                        .opacity((viewStore.passcodeNotSet && autoLockPolicy != .never) ? 1 : 0)
                    Picker(selection: $autoLockPolicy, label: Text(autoLockPolicy.descriptionKey)) {
                        ForEach(AutoLockPolicy.allCases) { policy in
                            Text(policy.descriptionKey).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading) {
                    Text("App switcher blur")
                    HStack {
                        Image(systemSymbol: .eye)
                        Slider(value: $backgroundBlurRadius, in: 0...100, step: 10)
                        Image(systemSymbol: .eyeSlash)
                    }
                }
            }
            Section("Cache".localized) {
                Button {
                    viewStore.send(.setClearDialogPresented(true))
                } label: {
                    HStack {
                        Text("Clear image caches")
                        Spacer()
                        Text(viewStore.diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .confirmationDialog(
            "Are you sure to clear?", isPresented: viewStore.binding(\.$clearDialogPresented), titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                viewStore.send(.clearWebImageCache)
            }
        }
        .onAppear {
            viewStore.send(.checkPasscodeSetting)
            viewStore.send(.calculateWebImageDiskCache)
        }
        .background(navigationLinks)
        .navigationBarTitle("General")
    }
}

// MARK: NavigationLinks
private extension GeneralSettingView {
    var navigationLinks: some View {
        ForEach(GeneralSettingRoute.allCases) { route in
            NavigationLink("", tag: route, selection: viewStore.binding(\.$route)) {
                switch route {
                case .logs:
                    LogsView(store: store.scope(state: \.logsState, action: GeneralSettingAction.logs))
                }
            }
        }
    }
}

// MARK: Definition
enum GeneralSettingRoute: Int, Identifiable, CaseIterable {
    var id: Int { rawValue }

    case logs
}
