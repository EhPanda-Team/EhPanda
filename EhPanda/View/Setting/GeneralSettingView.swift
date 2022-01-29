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
                    Text(R.string.localizable.commonLanguage())
                    Spacer()
                    Button(language) {
                        viewStore.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                HStack {
                    Text(R.string.localizable.generalSettingViewTitleTranslatesTags())
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
                Button(R.string.localizable.logsViewTitleLogs()) {
                    viewStore.send(.setNavigation(.logs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section(R.string.localizable.generalSettingViewSectionTitleNavigation()) {
                Toggle(
                    R.string.localizable.generalSettingViewTitleRedirectsLinksToSelectedHost(),
                    isOn: $redirectsLinksToSelectedHost
                )
                Toggle(
                    R.string.localizable.generalSettingViewTitleDetectsLinksFromClipboard(),
                    isOn: $detectsLinksFromClipboard
                )
            }
            Section(R.string.localizable.generalSettingViewSectionTitleSecurity()) {
                HStack {
                    Text(R.string.localizable.generalSettingViewTitleAutoLock())
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
                    Text(R.string.localizable.generalSettingViewTitleAppSwitcherBlurRadius())
                    HStack {
                        Image(systemSymbol: .eye)
                        Slider(value: $backgroundBlurRadius, in: 0...100, step: 10)
                        Image(systemSymbol: .eyeSlash)
                    }
                }
            }
            Section(R.string.localizable.generalSettingViewSectionTitleCaches()) {
                Button {
                    viewStore.send(.setNavigation(.clearCache))
                } label: {
                    HStack {
                        Text(R.string.localizable.generalSettingViewButtonClearImageCaches())
                        Spacer()
                        Text(viewStore.diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .confirmationDialog(
            message: R.string.localizable.confirmationDialogTitleAreYouSureTo(
                R.string.localizable.commonClear().lowercased()
            ),
            unwrapping: viewStore.binding(\.$route),
            case: /GeneralSettingState.Route.clearCache
        ) {
            Button(R.string.localizable.commonClear(), role: .destructive) {
                viewStore.send(.clearWebImageCache)
            }
        }
        .onAppear {
            viewStore.send(.checkPasscodeSetting)
            viewStore.send(.calculateWebImageDiskCache)
        }
        .background(navigationLink)
        .navigationTitle(R.string.localizable.enumSettingStateRouteValueGeneral())
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
