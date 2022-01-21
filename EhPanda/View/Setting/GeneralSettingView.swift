//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import ComposableArchitecture

struct GeneralSettingView: View {
    private let store: Store<GeneralSettingState, GeneralSettingAction>
    @ObservedObject private var viewStore: ViewStore<GeneralSettingState, GeneralSettingAction>
    private let tagTranslatorLoadingState: LoadingState
    private let tagTranslatorEmpty: Bool
    @Binding private var translatesTags: Bool
    @Binding private var redirectsLinksToSelectedHost: Bool
    @Binding private var detectsLinksFromClipboard: Bool
    @Binding private var backgroundBlurRadius: Double
    @Binding private var autoLockPolicy: AutoLockPolicy

    init(
        store: Store<GeneralSettingState, GeneralSettingAction>,
        tagTranslatorLoadingState: LoadingState, tagTranslatorEmpty: Bool, translatesTags: Binding<Bool>,
        redirectsLinksToSelectedHost: Binding<Bool>, detectsLinksFromClipboard: Binding<Bool>,
        backgroundBlurRadius: Binding<Double>, autoLockPolicy: Binding<AutoLockPolicy>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.tagTranslatorLoadingState = tagTranslatorLoadingState
        self.tagTranslatorEmpty = tagTranslatorEmpty
        _translatesTags = translatesTags
        _redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        _detectsLinksFromClipboard = detectsLinksFromClipboard
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
                Toggle("Detects links from the clipboard", isOn: $detectsLinksFromClipboard)
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
                    viewStore.send(.setNavigation(.clearCache))
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
            message: "Are you sure to clear?",
            unwrapping: viewStore.binding(\.$route),
            case: /GeneralSettingState.Route.clearCache
        ) {
            Button("Clear", role: .destructive) {
                viewStore.send(.clearWebImageCache)
            }
        }
        .onAppear {
            viewStore.send(.checkPasscodeSetting)
            viewStore.send(.calculateWebImageDiskCache)
        }
        .background(navigationLink)
        .navigationTitle("General")
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /GeneralSettingState.Route.logs) { _ in
            LogsView(store: store.scope(state: \.logsState, action: GeneralSettingAction.logs))
        }
    }
}

struct GeneralSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GeneralSettingView(
                store: .init(
                    initialState: .init(),
                    reducer: generalSettingReducer,
                    environment: GeneralSettingEnvironment(
                        fileClient: .live,
                        loggerClient: .live,
                        libraryClient: .live,
                        databaseClient: .live,
                        uiApplicationClient: .live,
                        authorizationClient: .live
                    )
                ),
                tagTranslatorLoadingState: .idle,
                tagTranslatorEmpty: false,
                translatesTags: .constant(false),
                redirectsLinksToSelectedHost: .constant(false),
                detectsLinksFromClipboard: .constant(false),
                backgroundBlurRadius: .constant(10),
                autoLockPolicy: .constant(.never)
            )
        }
    }
}
