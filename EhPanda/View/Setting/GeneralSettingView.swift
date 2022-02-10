//
//  GeneralSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import FilePicker
import ComposableArchitecture

struct GeneralSettingView: View {
    private let store: Store<GeneralSettingState, GeneralSettingAction>
    @ObservedObject private var viewStore: ViewStore<GeneralSettingState, GeneralSettingAction>
    private let tagTranslatorLoadingState: LoadingState
    private let tagTranslatorEmpty: Bool
    private let tagTranslatorHasCustomTranslations: Bool
    @Binding private var translatesTags: Bool
    @Binding private var redirectsLinksToSelectedHost: Bool
    @Binding private var detectsLinksFromClipboard: Bool
    @Binding private var backgroundBlurRadius: Double
    @Binding private var autoLockPolicy: AutoLockPolicy

    init(
        store: Store<GeneralSettingState, GeneralSettingAction>,
        tagTranslatorLoadingState: LoadingState, tagTranslatorEmpty: Bool,
        tagTranslatorHasCustomTranslations: Bool, translatesTags: Binding<Bool>,
        redirectsLinksToSelectedHost: Binding<Bool>, detectsLinksFromClipboard: Binding<Bool>,
        backgroundBlurRadius: Binding<Double>, autoLockPolicy: Binding<AutoLockPolicy>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.tagTranslatorLoadingState = tagTranslatorLoadingState
        self.tagTranslatorEmpty = tagTranslatorEmpty
        self.tagTranslatorHasCustomTranslations = tagTranslatorHasCustomTranslations
        _translatesTags = translatesTags
        _redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        _detectsLinksFromClipboard = detectsLinksFromClipboard
        _backgroundBlurRadius = backgroundBlurRadius
        _autoLockPolicy = autoLockPolicy
    }

    private var language: String {
        Locale.current.localizedString(forLanguageCode: Locale.current.languageCode ?? "")
        ?? R.string.localizable.generalSettingViewValueDefaultLanguageDescription()
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(R.string.localizable.generalSettingViewTitleLanguage())
                    Spacer()
                    Button(language) {
                        viewStore.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                Button(R.string.localizable.generalSettingViewButtonLogs()) {
                    viewStore.send(.setNavigation(.logs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section(R.string.localizable.generalSettingViewSectionTitleTagsTranslation()) {
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
                FilePicker(
                    types: [.json], allowMultiple: false,
                    title: R.string.localizable.generalSettingViewButtonImportCustomTranslations()
                ) { urls in
                    if let url = urls.first {
                        viewStore.send(.onTranslationsFilePicked(url))
                    }
                }
                if tagTranslatorHasCustomTranslations {
                    Button(
                        R.string.localizable.generalSettingViewButtonRemoveCustomTranslations(),
                        role: .destructive, action: { viewStore.send(.setNavigation(.removeCustomTranslations)) }
                    )
                    .confirmationDialog(
                        message: R.string.localizable.confirmationDialogTitleRemoveCustomTranslations(),
                        unwrapping: viewStore.binding(\.$route),
                        case: /GeneralSettingState.Route.removeCustomTranslations
                    ) {
                        Button(R.string.localizable.confirmationDialogButtonRemove(), role: .destructive) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                viewStore.send(.onRemoveCustomTranslations)
                            }
                        }
                    }
                }
            }
            Section(R.string.localizable.generalSettingViewSectionTitleNavigation()) {
                Toggle(
                    R.string.localizable.generalSettingViewTitleRedirectsLinksToTheSelectedHost(),
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
                    Picker(selection: $autoLockPolicy, label: Text(autoLockPolicy.value)) {
                        ForEach(AutoLockPolicy.allCases) { policy in
                            Text(policy.value).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading) {
                    Text(R.string.localizable.generalSettingViewTitleBackgroundBlurRadius())
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
                .confirmationDialog(
                    message: R.string.localizable.confirmationDialogTitleClear(),
                    unwrapping: viewStore.binding(\.$route),
                    case: /GeneralSettingState.Route.clearCache
                ) {
                    Button(R.string.localizable.confirmationDialogButtonClear(), role: .destructive) {
                        viewStore.send(.clearWebImageCache)
                    }
                }
            }
        }
        .animation(.default, value: tagTranslatorHasCustomTranslations)
        .animation(.default, value: tagTranslatorLoadingState)
        .animation(.default, value: tagTranslatorEmpty)
        .onAppear {
            viewStore.send(.checkPasscodeSetting)
            viewStore.send(.calculateWebImageDiskCache)
        }
        .background(navigationLink)
        .navigationTitle(R.string.localizable.generalSettingViewTitleGeneral())
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
                tagTranslatorHasCustomTranslations: false,
                translatesTags: .constant(false),
                redirectsLinksToSelectedHost: .constant(false),
                detectsLinksFromClipboard: .constant(false),
                backgroundBlurRadius: .constant(10),
                autoLockPolicy: .constant(.never)
            )
        }
    }
}
