import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import Sharing
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    /// The three tag flags insert and remove whole rows of the Tags section — position motion, so
    /// the rows appear and disappear instantly under Reduce Motion (D-29). The cache-size readout's
    /// `numericText` crossfade is a digit change and keeps its own `.default` animation.
    private var rowAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    private var language: String {
        Locale.current.language.languageCode.map(\.identifier).flatMap(Locale.current.localizedString(forLanguageCode:))
            ?? String(localized: .defaultLanguageDescription)
    }

    var body: some View {
        Form {
            Section {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack {
                        Text(.RLocalizable.language)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(language) {
                            store.send(.navigateToSystemSetting)
                        }
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    HStack {
                        Text(.RLocalizable.language)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(language) {
                            store.send(.navigateToSystemSetting)
                        }
                        .foregroundStyle(.tint)
                    }
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

                    // The warning yellow, mixed toward black by 0.3 (`Color.mix`, perceptual):
                    // `.yellow` on the white row measured 1.51:1 in light, under the 3:1 a
                    // non-text glyph needs (dark 9.87, Increase Contrast 4.59 / 9.10). Darkened it
                    // reads 3.86 / 3.82 / 9.42 / 3.51 — the smallest twentieth with at least half
                    // a unit of margin in every variant (Phase 16 D-28).
                    Image(systemSymbol: .exclamationmarkTriangleFill)
                        .foregroundStyle(.yellow.mix(with: .black, by: 0.3))
                        .animation(.default) {
                            $0.visible(
                                setting.translateTags && tagTranslatorEmpty
                                && tagTranslatorLoadingState != .loading
                            )
                        }
                        // The glyph sits beside the row's own text and would otherwise be read by
                        // its symbol name; the spinner overlaid on it stays its own element.
                        .accessibilityHidden(true)
                        .overlay {
                            ProgressView()
                                .animation(.default) {
                                    $0.visible(tagTranslatorLoadingState == .loading)
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
            // The binding writes `Setting.isSharingAnalyticsData`, whose setter pins the underlying
            // optional; `AnalyticsClient.send` re-reads it per signal, so the toggle takes effect
            // immediately rather than at the next launch.
            Section {
                AppToggle(
                    .shareAnalyticsData,
                    isOn: Binding($setting.isSharingAnalyticsData)
                )
            } header: {
                Text(.analytics)
            } footer: {
                Text(.shareAnalyticsDataFooter)
            }
        }
        .animation(rowAnimation, value: tagTranslatorHasCustomTranslations)
        .animation(rowAnimation, value: setting.enableTagsExtension)
        .animation(rowAnimation, value: tagTranslatorEmpty)
        .onChange(of: setting.enableTagsExtension) { _, _ in
            store.send(.delegate(.enableTagsExtensionChanged))
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
