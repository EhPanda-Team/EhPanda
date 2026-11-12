import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
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
                    Text(.enhancedTags)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemSymbol: .exclamationmarkTriangleFill)
                        .foregroundStyle(.yellow)
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

                    AppToggle(.enhancedTags, isOn: Binding($setting.enableTagsExtension))
                        .labelsHidden()
                        .padding(.leading, 20)
                }
                if setting.enableTagsExtension && !tagTranslatorEmpty {
                    AppToggle(.translateTags, isOn: Binding($setting.translateTags))
                    AppToggle(
                        .showTagSuggestions,
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
                    .openLinksOnSelectedSite,
                    isOn: Binding($setting.redirectLinksToSelectedHost)
                )
                AppToggle(
                    .detectLinksInClipboard,
                    isOn: Binding($setting.detectLinksFromClipboard)
                )
            }
            Section(.cache) {
                Button {
                    store.send(.clearImageCacheButtonTapped)
                } label: {
                    HStack {
                        Text(.clearImageCache)
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
            analyticsSection
        }
        .animation(rowAnimation, value: tagTranslatorHasCustomTranslations)
        .animation(rowAnimation, value: setting.enableTagsExtension)
        .animation(rowAnimation, value: tagTranslatorEmpty)
        .animation(rowAnimation, value: store.analyticsLevel)
        .onChange(of: setting.enableTagsExtension) { _, _ in
            store.send(.delegate(.enableTagsExtensionChanged))
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.general)
    }

    /// The analytics level, the privacy page and, as the footer, what the selected level shares (UI-SPEC C-9, D-07).
    /// A pick goes to the reducer, which stores and applies it at once with no confirmation (DD-09a); this view never
    /// calls the analytics client. With no level chosen yet, the picker shows no selection and there is no footer.
    private var analyticsSection: some View {
        Section {
            analyticsLevelPicker
            privacyPolicyRow
        } header: {
            Text(.analytics)
        } footer: {
            if let level = store.analyticsLevel {
                Text(level.levelDescription)
            }
        }
    }

    /// A menu picker like Appearance's Theme. At accessibility sizes it follows the Language row above: the label on
    /// its own line, the picker trailing below it.
    @ViewBuilder private var analyticsLevelPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack {
                Text(.shareAnalyticsData)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)

                levelPicker
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            levelPicker
        }
    }

    private var levelPicker: some View {
        Picker(.shareAnalyticsData, selection: $store.analyticsLevel.sending(\.analyticsLevelPicked)) {
            ForEach(AnalyticsLevel.allCases, id: \.self) { level in
                Text(level.name)
                    .tag(Optional(level))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("setting_analytics_level")
    }

    /// Opens the website's privacy page in the default browser, like every other external link in the app.
    @ViewBuilder private var privacyPolicyRow: some View {
        if let url = URL(string: String(localized: .RConstant.contactPrivacyPolicy)) {
            Link(destination: url) {
                HStack {
                    Text(.RLocalizable.consentPrivacyLink)
                    Spacer()
                    Image(systemSymbol: .arrowUpRight)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("setting_privacy_policy")
        }
    }
}

private extension AnalyticsLevel {
    var name: LocalizedStringResource {
        switch self {
        case .minimal: .RLocalizable.consentLevelMinimal
        case .basic: .RLocalizable.consentLevelBasic
        case .full: .RLocalizable.consentLevelFull
        }
    }

    var levelDescription: LocalizedStringResource {
        switch self {
        case .minimal: .RLocalizable.consentLevelMinimalDescription
        case .basic: .RLocalizable.consentLevelBasicDescription
        case .full: .RLocalizable.consentLevelFullDescription
        }
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
