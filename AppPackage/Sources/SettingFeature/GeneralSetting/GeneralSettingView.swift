import SwiftUI
import AppModels
import Resources
import UniformTypeIdentifiers
import ComposableArchitecture
import AppComponents

struct GeneralSettingView: View {
    @Bindable private var store: StoreOf<GeneralSettingReducer>
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
            ?? String(localized: .defaultLanguageDescription)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(.RLocalizable.language)
                    Spacer()
                    Button(language) {
                        store.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                Button(String(localized: .appActivityLogs)) {
                    store.send(.delegate(.pushAppActivityLogs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section(String(localized: .tags)) {
                HStack {
                    Text(.enablesTagsExtension)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Image(systemSymbol: .exclamationmarkTriangleFill)
                            .foregroundStyle(.yellow)
                            .opacity(
                                translatesTags && tagTranslatorEmpty
                                    && tagTranslatorLoadingState != .loading ? 1 : 0
                            )
                        ProgressView()
                            .tint(nil)
                            .opacity(tagTranslatorLoadingState == .loading ? 1 : 0)
                    }

                    Toggle("", isOn: $enablesTagsExtension)
                        .frame(width: 50)
                        .padding(.leading, 20)
                }
                if enablesTagsExtension && !tagTranslatorEmpty {
                    Toggle(String(localized: .translatesTags), isOn: $translatesTags)
                    Toggle(
                        String(localized: .showsTagsSearchSuggestion),
                        isOn: $showsTagsSearchSuggestion
                    )
                    Toggle(String(localized: .showsImagesInTags), isOn: $showsImagesInTags)
                }
                Button(String(localized: .importCustomTranslations)) {
                    store.send(.importCustomTranslationsButtonTapped)
                }
                .fileImporter(
                    isPresented: $store.destination.importTranslations,
                    allowedContentTypes: [.json]
                ) { result in
                    if case .success(let url) = result {
                        store.send(.onTranslationsFilePicked(url))
                    }
                }
                if tagTranslatorHasCustomTranslations {
                    Button(
                        String(localized: .removeCustomTranslations),
                        role: .destructive, action: { store.send(.removeCustomTranslationsButtonTapped) }
                    )
                    .confirmationDialog(
                        $store.scope(state: \.removeTranslationsDialog, action: \.removeTranslationsDialog)
                    )
                }
            }
            Section(String(localized: .navigation)) {
                Toggle(
                    String(localized: .redirectsLinksToTheSelectedHost),
                    isOn: $redirectsLinksToSelectedHost
                )
                Toggle(
                    String(localized: .detectsLinksFromClipboard),
                    isOn: $detectsLinksFromClipboard
                )
            }
            Section(String(localized: .security)) {
                HStack {
                    Picker(
                        String(localized: .autoLock),
                        selection: $autoLockPolicy
                    ) {
                        ForEach(AutoLockPolicy.allCases) { policy in
                            Text(policy.value).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    if store.passcodeNotSet && autoLockPolicy != .never {
                        Image(systemSymbol: .exclamationmarkTriangleFill).foregroundStyle(.yellow)
                    }
                }
                VStack(alignment: .leading) {
                    Text(.backgroundBlurRadius)
                    HStack {
                        Image(systemSymbol: .eye)
                        Slider(value: $backgroundBlurRadius, in: 0...100, step: 10)
                        Image(systemSymbol: .eyeSlash)
                    }
                }
            }
            Section(String(localized: .caches)) {
                Button {
                    store.send(.clearImageCachesButtonTapped)
                } label: {
                    HStack {
                        Text(.clearImageCaches)
                        Spacer()
                        Text(store.diskImageCacheSize).foregroundStyle(.tint)
                    }
                    .foregroundColor(.primary)
                }
                .confirmationDialog(
                    $store.scope(state: \.clearCacheDialog, action: \.clearCacheDialog)
                )
            }
        }
        .animation(.default, value: tagTranslatorHasCustomTranslations)
        .animation(.default, value: tagTranslatorLoadingState)
        .animation(.default, value: enablesTagsExtension)
        .animation(.default, value: tagTranslatorEmpty)
        .onAppear {
            store.send(.checkPasscodeSetting)
            store.send(.calculateWebImageDiskCache)
        }
        .navigationTitle(.general)
    }
}

struct GeneralSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GeneralSettingView(
                store: .init(initialState: .init(), reducer: GeneralSettingReducer.init),
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
