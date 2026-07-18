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
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(language) {
                        store.send(.navigateToSystemSetting)
                    }
                    .foregroundStyle(.tint)
                }
                Button(.appActivityLogs) {
                    store.send(.delegate(.pushAppActivityLogs))
                }
                .foregroundStyle(.primary).withArrow()
            }
            Section(.tags) {
                HStack {
                    Text(.enableTagsExtension)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemSymbol: .exclamationmarkTriangleFill)
                        .foregroundStyle(.yellow)
                        .animation(.default) {
                            $0.opacity(
                                setting.translateTags && tagTranslatorEmpty
                                && tagTranslatorLoadingState != .loading ? 1 : 0
                            )
                        }
                        .overlay {
                            ProgressView()
                                .animation(.default) {
                                    $0.opacity(tagTranslatorLoadingState == .loading ? 1 : 0)
                                }
                        }

                    AppToggle(.enableTagsExtension, isOn: Binding($setting.enableTagsExtension))
                        .labelsHidden()
                        .frame(width: 50)
                        .padding(.leading, 20)
                }
                if setting.enableTagsExtension && !tagTranslatorEmpty {
                    AppToggle(.translateTags, isOn: Binding($setting.translateTags))
                    AppToggle(
                        .showTagsSearchSuggestion,
                        isOn: Binding($setting.showTagsSearchSuggestion)
                    )
                    AppToggle(.showImagesInTags, isOn: Binding($setting.showImagesInTags))
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
                AppToggle(
                    .redirectLinksToTheSelectedHost,
                    isOn: Binding($setting.redirectLinksToSelectedHost)
                )
                AppToggle(
                    .detectLinksFromClipboard,
                    isOn: Binding($setting.detectLinksFromClipboard)
                )
            }
            Section(.caches) {
                Button {
                    store.send(.clearImageCachesButtonTapped)
                } label: {
                    HStack {
                        Text(.clearImageCaches)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(store.diskImageCacheSize)
                            .foregroundStyle(.tint)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.default, value: store.diskImageCacheSize)
                    }
                }
                .foregroundStyle(.primary)
                .confirmationDialog(
                    $store.scope(\.$clearCacheDialog, action: \.clearCacheDialog)
                )
            }
        }
        .animation(.default, value: tagTranslatorHasCustomTranslations)
        .animation(.default, value: tagTranslatorLoadingState)
        .animation(.default, value: setting.enableTagsExtension)
        .animation(.default, value: tagTranslatorEmpty)
        .onChange(of: setting.enableTagsExtension) { _, _ in
            store.send(.delegate(.enableTagsExtensionChanged))
        }
        .onAppear {
            store.send(.calculateWebImageDiskCache)
        }
        .navigationTitle(.general)
    }
}

#Preview("Initial") {
    NavigationStack {
        GeneralSettingView(
            store: .init(initialState: .init(), reducer: GeneralSettingReducer.init),
            tagTranslatorLoadingState: .idle
        )
    }
}
