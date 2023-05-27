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
    private let store: StoreOf<GeneralSettingReducer>
    @ObservedObject private var viewStore: ViewStoreOf<GeneralSettingReducer>
    private let tagTranslatorLoadingState: LoadingState
    private let tagTranslatorEmpty: Bool
    private let tagTranslatorHasCustomTranslations: Bool
    @Binding private var enablesTagsExtension: Bool
    @Binding private var translatesTags: Bool
    @Binding private var showsTagsSearchSuggestion: Bool
    @Binding private var showsImagesInTags: Bool
    @Binding private var redirectsLinksToSelectedHost: Bool
    @Binding private var detectsLinksFromClipboard: Bool
    @Binding private var backgroundBlurRadius: Double
    @Binding private var autoLockPolicy: AutoLockPolicy

    init(
        store: StoreOf<GeneralSettingReducer>,
        tagTranslatorLoadingState: LoadingState, tagTranslatorEmpty: Bool,
        tagTranslatorHasCustomTranslations: Bool, enablesTagsExtension: Binding<Bool>,
        translatesTags: Binding<Bool>, showsTagsSearchSuggestion: Binding<Bool>,
        showsImagesInTags: Binding<Bool>, redirectsLinksToSelectedHost: Binding<Bool>,
        detectsLinksFromClipboard: Binding<Bool>, backgroundBlurRadius: Binding<Double>,
        autoLockPolicy: Binding<AutoLockPolicy>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.tagTranslatorLoadingState = tagTranslatorLoadingState
        self.tagTranslatorEmpty = tagTranslatorEmpty
        self.tagTranslatorHasCustomTranslations = tagTranslatorHasCustomTranslations
        _enablesTagsExtension = enablesTagsExtension
        _translatesTags = translatesTags
        _showsTagsSearchSuggestion = showsTagsSearchSuggestion
        _showsImagesInTags = showsImagesInTags
        _redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        _detectsLinksFromClipboard = detectsLinksFromClipboard
        _backgroundBlurRadius = backgroundBlurRadius
        _autoLockPolicy = autoLockPolicy
    }

    private var language: String {
        Locale.current.language.languageCode.map(\.identifier).flatMap(Locale.current.localizedString(forLanguageCode:))
        ?? L10n.Localizable.GeneralSettingView.Value.defaultLanguageDescription
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L10n.Localizable.GeneralSettingView.Title.language)
                    Spacer()
                    Button(language) {
                        viewStore.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                Button(L10n.Localizable.GeneralSettingView.Button.logs) {
                    viewStore.send(.setNavigation(.logs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section(L10n.Localizable.GeneralSettingView.Section.Title.tags) {
                HStack {
                    Text(L10n.Localizable.GeneralSettingView.Title.enablesTagsExtension)
                    Spacer()
                    ZStack {
                        Image(systemSymbol: .exclamationmarkTriangleFill).foregroundStyle(.yellow)
                            .opacity(
                                translatesTags && tagTranslatorEmpty
                                && tagTranslatorLoadingState != .loading ? 1 : 0
                            )
                        ProgressView().tint(nil).opacity(tagTranslatorLoadingState == .loading ? 1 : 0)
                    }
                    Toggle("", isOn: $enablesTagsExtension).frame(width: 50)
                }
                if enablesTagsExtension && !tagTranslatorEmpty {
                    Toggle(L10n.Localizable.GeneralSettingView.Title.translatesTags, isOn: $translatesTags)
                    Toggle(
                        L10n.Localizable.GeneralSettingView.Title.showsTagsSearchSuggestion,
                        isOn: $showsTagsSearchSuggestion
                    )
                    Toggle(L10n.Localizable.GeneralSettingView.Title.showsImagesInTags, isOn: $showsImagesInTags)
                }
                FilePicker(
                    types: [.json], allowMultiple: false,
                    title: L10n.Localizable.GeneralSettingView.Button.importCustomTranslations
                ) { urls in
                    if let url = urls.first {
                        viewStore.send(.onTranslationsFilePicked(url))
                    }
                }
                if tagTranslatorHasCustomTranslations {
                    Button(
                        L10n.Localizable.GeneralSettingView.Button.removeCustomTranslations,
                        role: .destructive, action: { viewStore.send(.setNavigation(.removeCustomTranslations)) }
                    )
                    .confirmationDialog(
                        message: L10n.Localizable.ConfirmationDialog.Title.removeCustomTranslations,
                        unwrapping: viewStore.binding(\.$route),
                        case: /GeneralSettingReducer.Route.removeCustomTranslations
                    ) {
                        Button(L10n.Localizable.ConfirmationDialog.Button.remove, role: .destructive) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                viewStore.send(.onRemoveCustomTranslations)
                            }
                        }
                    }
                }
            }
            Section(L10n.Localizable.GeneralSettingView.Section.Title.navigation) {
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.redirectsLinksToTheSelectedHost,
                    isOn: $redirectsLinksToSelectedHost
                )
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.detectsLinksFromClipboard,
                    isOn: $detectsLinksFromClipboard
                )
            }
            Section(L10n.Localizable.GeneralSettingView.Section.Title.security) {
                HStack {
                    Picker(
                        L10n.Localizable.GeneralSettingView.Title.autoLock,
                        selection: $autoLockPolicy
                    ) {
                        ForEach(AutoLockPolicy.allCases) { policy in
                            Text(policy.value).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    if viewStore.passcodeNotSet && autoLockPolicy != .never {
                        Image(systemSymbol: .exclamationmarkTriangleFill).foregroundStyle(.yellow)
                    }
                }
                VStack(alignment: .leading) {
                    Text(L10n.Localizable.GeneralSettingView.Title.backgroundBlurRadius)
                    HStack {
                        Image(systemSymbol: .eye)
                        Slider(value: $backgroundBlurRadius, in: 0...100, step: 10)
                        Image(systemSymbol: .eyeSlash)
                    }
                }
            }
            Section(L10n.Localizable.GeneralSettingView.Section.Title.caches) {
                Button {
                    viewStore.send(.setNavigation(.clearCache))
                } label: {
                    HStack {
                        Text(L10n.Localizable.GeneralSettingView.Button.clearImageCaches)
                        Spacer()
                        Text(viewStore.diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
                .confirmationDialog(
                    message: L10n.Localizable.ConfirmationDialog.Title.clear,
                    unwrapping: viewStore.binding(\.$route),
                    case: /GeneralSettingReducer.Route.clearCache
                ) {
                    Button(L10n.Localizable.ConfirmationDialog.Button.clear, role: .destructive) {
                        viewStore.send(.clearWebImageCache)
                    }
                }
            }
        }
        .animation(.default, value: tagTranslatorHasCustomTranslations)
        .animation(.default, value: tagTranslatorLoadingState)
        .animation(.default, value: enablesTagsExtension)
        .animation(.default, value: tagTranslatorEmpty)
        .onAppear {
            viewStore.send(.checkPasscodeSetting)
            viewStore.send(.calculateWebImageDiskCache)
        }
        .background(navigationLink)
        .navigationTitle(L10n.Localizable.GeneralSettingView.Title.general)
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /GeneralSettingReducer.Route.logs) { _ in
            LogsView(store: store.scope(state: \.logsState, action: GeneralSettingReducer.Action.logs))
        }
    }
}

struct GeneralSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GeneralSettingView(
                store: .init(
                    initialState: .init(),
                    reducer: GeneralSettingReducer()
                ),
                tagTranslatorLoadingState: .idle,
                tagTranslatorEmpty: false,
                tagTranslatorHasCustomTranslations: false,
                enablesTagsExtension: .constant(false),
                translatesTags: .constant(false),
                showsTagsSearchSuggestion: .constant(false),
                showsImagesInTags: .constant(false),
                redirectsLinksToSelectedHost: .constant(false),
                detectsLinksFromClipboard: .constant(false),
                backgroundBlurRadius: .constant(10),
                autoLockPolicy: .constant(.never)
            )
        }
    }
}
