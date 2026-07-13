import SwiftUI
import AppModels
import Sharing
import Resources
import UniformTypeIdentifiers
import ComposableArchitecture
import AppComponents

struct GeneralSettingView: View {
    @Bindable private var store: StoreOf<GeneralSettingReducer>
    @Shared(.setting) private var setting: Setting
    // `tagTranslator` is the in-memory shared table, so its derived flags are read here directly rather
    // than threaded from the parent; only the parent-owned fetch `loadingState` is passed in.
    @SharedReader(.tagTranslator) private var tagTranslator: TagTranslator
    private let tagTranslatorLoadingState: LoadingState

    init(store: StoreOf<GeneralSettingReducer>, tagTranslatorLoadingState: LoadingState) {
        self.store = store
        self.tagTranslatorLoadingState = tagTranslatorLoadingState
    }

    private var tagTranslatorEmpty: Bool { tagTranslator.translations.isEmpty }
    private var tagTranslatorHasCustomTranslations: Bool { tagTranslator.hasCustomTranslations }

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
                Button(.appActivityLogs) {
                    store.send(.delegate(.pushAppActivityLogs))
                }
                .foregroundColor(.primary).withArrow()
            }
            Section(.tags) {
                HStack {
                    Text(.enablesTagsExtension)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Image(systemSymbol: .exclamationmarkTriangleFill)
                            .foregroundStyle(.yellow)
                            .opacity(
                                setting.translatesTags && tagTranslatorEmpty
                                    && tagTranslatorLoadingState != .loading ? 1 : 0
                            )
                        ProgressView()
                            .tint(nil)
                            .opacity(tagTranslatorLoadingState == .loading ? 1 : 0)
                    }

                    Toggle(.enablesTagsExtension, isOn: Binding($setting.enablesTagsExtension))
                        .labelsHidden()
                        .frame(width: 50)
                        .padding(.leading, 20)
                }
                if setting.enablesTagsExtension && !tagTranslatorEmpty {
                    Toggle(.translatesTags, isOn: Binding($setting.translatesTags))
                    Toggle(
                        .showsTagsSearchSuggestion,
                        isOn: Binding($setting.showsTagsSearchSuggestion)
                    )
                    Toggle(.showsImagesInTags, isOn: Binding($setting.showsImagesInTags))
                }
                Button(.importCustomTranslations) {
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
                        .removeCustomTranslations,
                        role: .destructive, action: { store.send(.removeCustomTranslationsButtonTapped) }
                    )
                    .confirmationDialog(
                        $store.scope(\.$removeTranslationsDialog, action: \.removeTranslationsDialog)
                    )
                }
            }
            Section(.navigation) {
                Toggle(
                    .redirectsLinksToTheSelectedHost,
                    isOn: Binding($setting.redirectsLinksToSelectedHost)
                )
                Toggle(
                    .detectsLinksFromClipboard,
                    isOn: Binding($setting.detectsLinksFromClipboard)
                )
            }
            Section(.caches) {
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
                    $store.scope(\.$clearCacheDialog, action: \.clearCacheDialog)
                )
            }
        }
        .animation(.default, value: tagTranslatorHasCustomTranslations)
        .animation(.default, value: tagTranslatorLoadingState)
        .animation(.default, value: setting.enablesTagsExtension)
        .animation(.default, value: tagTranslatorEmpty)
        .onChange(of: setting.enablesTagsExtension) { _, _ in
            store.send(.delegate(.enablesTagsExtensionChanged))
        }
        .onAppear {
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
                tagTranslatorLoadingState: .idle
            )
        }
    }
}
