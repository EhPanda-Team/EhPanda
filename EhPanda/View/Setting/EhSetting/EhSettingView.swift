//
//  EhSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/07.
//

import SwiftUI
import ComposableArchitecture

struct EhSettingView: View {
    private let store: StoreOf<EhSettingReducer>
    @ObservedObject private var viewStore: ViewStoreOf<EhSettingReducer>
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    init(store: StoreOf<EhSettingReducer>, bypassesSNIFiltering: Bool, blurRadius: Double) {
        self.store = store
        viewStore = ViewStore(store)
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
    }

    // MARK: EhSettingView
    var body: some View {
        ZStack {
            // workaround: Stay if-else approach
            if viewStore.loadingState == .loading || viewStore.submittingState == .loading {
                LoadingView()
                    .tint(nil)
            } else if case .failed(let error) = viewStore.loadingState {
                ErrorView(error: error, action: { viewStore.send(.fetchEhSetting) })
                    .tint(nil)
            }
            // Using `Binding.init` will crash the app
            else if let ehSetting = Binding(unwrapping: viewStore.binding(\.$ehSetting)),
                    let ehProfile = Binding(unwrapping: viewStore.binding(\.$ehProfile))
            {
                form(ehSetting: ehSetting, ehProfile: ehProfile)
                    .transition(.opacity.animation(.default))
            }
        }
        .onAppear {
            if viewStore.ehSetting == nil {
                viewStore.send(.fetchEhSetting)
            }
        }
        .onDisappear {
            if let profileSet = viewStore.ehSetting?.ehpandaProfile?.value {
                viewStore.send(.setDefaultProfile(profileSet))
            }
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /EhSettingReducer.Route.webView) { route in
            WebView(url: route.wrappedValue)
                .autoBlur(radius: blurRadius)
        }
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.EhSettingView.Title.hostSettings(AppUtil.galleryHost.rawValue))
    }
    // MARK: Form
    private func form(ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>) -> some View {
        Form {
            Group {
                EhProfileSection(
                    route: viewStore.binding(\.$route),
                    ehSetting: ehSetting,
                    ehProfile: ehProfile,
                    editingProfileName: viewStore.binding(\.$editingProfileName),
                    deleteAction: {
                        if let value = viewStore.ehProfile?.value {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                viewStore.send(.performAction(.delete, nil, value))
                            }
                        }
                    },
                    deleteDialogAction: { viewStore.send(.setNavigation(.deleteProfile)) },
                    performEhProfileAction: { viewStore.send(.performAction($0, $1, $2)) }
                )

                ImageLoadSettingsSection(ehSetting: ehSetting)
                ImageSizeSettingsSection(ehSetting: ehSetting)
                GalleryNameDisplaySection(ehSetting: ehSetting)
                ArchiverSettingsSection(ehSetting: ehSetting)
                FrontPageSettingsSection(ehSetting: ehSetting)
                FavoritesSection(ehSetting: ehSetting)
                RatingsSection(ehSetting: ehSetting)
                TagFilteringThresholdSection(ehSetting: ehSetting)
                TagWatchingThresholdSection(ehSetting: ehSetting)
            }
            Group {
                FilteredRemovalCountSection(ehSetting: ehSetting)
                ExcludedLanguagesSection(ehSetting: ehSetting)
                ExcludedUploadersSection(ehSetting: ehSetting)
                SearchResultCountSection(ehSetting: ehSetting)
                ThumbnailSettingsSection(ehSetting: ehSetting)
                ThumbnailScalingSection(ehSetting: ehSetting)
                ViewportOverrideSection(ehSetting: ehSetting)
                GalleryCommentsSection(ehSetting: ehSetting)
                GalleryTagsSection(ehSetting: ehSetting)
                GalleryPageNumberingSection(ehSetting: ehSetting)
            }
            Group {
                OriginalImagesSection(ehSetting: ehSetting)
                MultiplePageViewerSection(ehSetting: ehSetting)
            }
        }
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewStore.send(.setNavigation(.webView(Defaults.URL.uConfig)))
                } label: {
                    Image(systemSymbol: .globe)
                }
                .disabled(bypassesSNIFiltering)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewStore.send(.submitChanges)
                } label: {
                    Image(systemSymbol: .icloudAndArrowUp)
                }
                .disabled(viewStore.ehSetting == nil)
            }

            ToolbarItem(placement: .keyboard) {
                Button(L10n.Localizable.EhSettingView.ToolbarItem.Button.done) {
                    viewStore.send(.setKeyboardHidden)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: EhProfileSection
private struct EhProfileSection: View {
    @Binding private var route: EhSettingReducer.Route?
    @Binding private var ehSetting: EhSetting
    @Binding private var ehProfile: EhProfile
    @Binding private var editingProfileName: String
    private let deleteAction: () -> Void
    private let deleteDialogAction: () -> Void
    private let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    init(
        route: Binding<EhSettingReducer.Route?>, ehSetting: Binding<EhSetting>,
        ehProfile: Binding<EhProfile>, editingProfileName: Binding<String>,
        deleteAction: @escaping () -> Void, deleteDialogAction: @escaping () -> Void,
        performEhProfileAction: @escaping (EhProfileAction?, String?, Int) -> Void
    ) {
        _route = route
        _ehSetting = ehSetting
        _ehProfile = ehProfile
        _editingProfileName = editingProfileName
        self.deleteAction = deleteAction
        self.deleteDialogAction = deleteDialogAction
        self.performEhProfileAction = performEhProfileAction
    }

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.profileSettings) {
            Picker(L10n.Localizable.EhSettingView.Title.selectedProfile, selection: $ehProfile) {
                ForEach(ehSetting.ehProfiles) { ehProfile in
                    Text(ehProfile.name)
                        .tag(ehProfile)
                }
            }
            .pickerStyle(.menu)

            if !ehProfile.isDefault {
                Button(L10n.Localizable.EhSettingView.Button.setAsDefault) {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }

                Button(
                    L10n.Localizable.EhSettingView.Button.deleteProfile,
                    role: .destructive,
                    action: deleteDialogAction
                )
                .confirmationDialog(
                    message: L10n.Localizable.ConfirmationDialog.Title.delete,
                    unwrapping: $route,
                    case: /EhSettingReducer.Route.deleteProfile
                ) {
                    Button(
                        L10n.Localizable.ConfirmationDialog.Button.delete,
                        role: .destructive, action: deleteAction
                    )
                }
            }
        }
        .onChange(of: ehProfile) {
            performEhProfileAction(nil, nil, $0.value)
        }
        .textCase(nil)

        Section {
            SettingTextField(text: $editingProfileName, width: nil, alignment: .leading, background: .clear)
                .focused($isFocused)

            Button(L10n.Localizable.EhSettingView.Button.rename) {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .disabled(isFocused)

            if ehSetting.isCapableOfCreatingNewProfile {
                Button(L10n.Localizable.EhSettingView.Button.createNew) {
                    performEhProfileAction(.create, editingProfileName, ehProfile.value)
                }
                .disabled(isFocused)
            }
        }
    }
}

// MARK: ImageLoadSettingsSection
private struct ImageLoadSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.loadImagesThroughTheHathNetwork,
                selection: $ehSetting.loadThroughHathSetting
            ) {
                ForEach(ehSetting.capableLoadThroughHathSettings) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.imageLoadSettings)
        } footer: {
            Text(ehSetting.loadThroughHathSetting.description)
        }
        .textCase(nil)

        Section(
            L10n.Localizable.EhSettingView.Description.browsingCountry(
                ehSetting.localizedLiteralBrowsingCountry ?? ehSetting.literalBrowsingCountry
            )
            .localizedKey
        ) {
            Picker(L10n.Localizable.EhSettingView.Title.browsingCountry, selection: $ehSetting.browsingCountry) {
                ForEach(EhSetting.BrowsingCountry.allCases) { country in
                    Text(country.name)
                        .tag(country)
                        .foregroundColor(country == ehSetting.browsingCountry ? .accentColor : .primary)
                }
            }
        }
        .textCase(nil)
    }
}

// MARK: ImageSizeSettingsSection
private struct ImageSizeSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.imageResolution, selection: $ehSetting.imageResolution) {
                ForEach(ehSetting.capableImageResolutions) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.imageSizeSettings)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.imageResolution)
        }
        .textCase(nil)

        Section(L10n.Localizable.EhSettingView.Description.imageSize) {
            Text(L10n.Localizable.EhSettingView.Title.imageSize)

            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.horizontal,
                value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px"
            )

            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.vertical,
                value: $ehSetting.imageSizeHeight, range: 0...65535, unit: "px"
            )
        }
        .textCase(nil)
    }
}

// MARK: GalleryNameDisplaySection
private struct GalleryNameDisplaySection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.galleryName, selection: $ehSetting.galleryName) {
                ForEach(EhSetting.GalleryName.allCases) { name in
                    Text(name.value)
                        .tag(name)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.galleryNameDisplay)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.galleryName)
        }
        .textCase(nil)
    }
}

// MARK: ArchiverSettingsSection
private struct ArchiverSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.archiverBehavior, selection: $ehSetting.archiverBehavior) {
                ForEach(EhSetting.ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.archiverSettings)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.archiverBehavior)
        }
        .textCase(nil)
    }
}

// MARK: FrontPageSettingsSection
private struct FrontPageSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    private var categoryBindings: [Binding<Bool>] {
        $ehSetting.disabledCategories.map({ $0 })
    }

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.displayMode, selection: $ehSetting.displayMode) {
                ForEach(EhSetting.DisplayMode.allCases) { mode in
                    Text(mode.value)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.frontPageSettings)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.displayMode)
        }
        .textCase(nil)

        Section {
            Toggle(
                L10n.Localizable.EhSettingView.Section.Title.showSearchRangeIndicator,
                isOn: $ehSetting.showSearchRangeIndicator
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.showSearchRangeIndicator)
        }
        .textCase(nil)

        Section(L10n.Localizable.EhSettingView.Description.galleryCategory) {
            CategoryView(bindings: categoryBindings)
        }
        .textCase(nil)
    }
}

// MARK: FavoritesSection
private struct FavoritesSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState private var isFocused

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    private var tuples: [(Category, Binding<String>)] {
        Category.allFavoritesCases.enumerated().map { index, category in
            (category, $ehSetting.favoriteCategories[index])
        }
    }

    var body: some View {
        Section {
            ForEach(tuples, id: \.0) { category, nameBinding in
                HStack(spacing: 30) {
                    Circle()
                        .foregroundColor(category.color)
                        .frame(width: 10)

                    SettingTextField(text: nameBinding, width: nil, alignment: .leading, background: .clear)
                        .focused($isFocused)
                }
                .padding(.leading)
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.favorites)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.favoriteCategories)
        }
        .textCase(nil)

        Section(L10n.Localizable.EhSettingView.Description.favoritesSortOrder) {
            Picker(
                L10n.Localizable.EhSettingView.Title.favoritesSortOrder,
                selection: $ehSetting.favoritesSortOrder
            ) {
                ForEach(EhSetting.FavoritesSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: RatingsSection
private struct RatingsSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState var isFocused

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            LabeledContent(L10n.Localizable.EhSettingView.Title.ratingsColor) {
                SettingTextField(
                    text: $ehSetting.ratingsColor,
                    promptText: L10n.Localizable.EhSettingView.Promt.ratingsColor,
                    width: 80
                )
                .focused($isFocused)
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.ratings)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.ratingsColor)
        }
        .textCase(nil)
    }
}

// MARK: TagFilteringThresholdSection
private struct TagFilteringThresholdSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.tagFilteringThreshold,
                value: $ehSetting.tagFilteringThreshold, range: -9999...0
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.tagFilteringThreshold)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.tagFilteringThreshold)
        }
        .textCase(nil)
    }
}

// MARK: TagWatchingThresholdSection
private struct TagWatchingThresholdSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.tagWatchingThreshold,
                value: $ehSetting.tagWatchingThreshold, range: 0...9999
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.tagWatchingThreshold)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.tagWatchingThreshold)
        }
        .textCase(nil)
    }
}

// MARK: FilteredRemovalCountSection
private struct FilteredRemovalCountSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showFilteredRemovalCount,
                isOn: $ehSetting.showFilteredRemovalCount
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.filteredRemovalCount).newlineBold()
            + Text(L10n.Localizable.EhSettingView.Description.filteredRemovalCount)
        }
    }
}

// MARK: ExcludedLanguagesSection
private struct ExcludedLanguagesSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    private let languages = Language.allExcludedCases.map(\.value)
    private var languageBindings: [Binding<Bool>] {
        $ehSetting.excludedLanguages.map({ $0 })
    }
    private func rowBindings(index: Int) -> [Binding<Bool>] {
        [-1, 0, 1].map { num in
            let index = index * 3 + num
            if index != -1 {
                return languageBindings[index]
            } else {
                return .constant(false)
            }
        }
    }

    var body: some View {
        Section {
            HStack {
                Text("")
                    .frame(width: DeviceUtil.windowW * 0.25)

                ForEach(EhSetting.ExcludedLanguagesCategory.allCases) { category in
                    Color.clear
                        .overlay {
                            Text(category.value)
                                .lineLimit(1)
                                .font(.subheadline)
                                .fixedSize()
                        }
                }
            }

            ForEach(0..<(languageBindings.count / 3) + 1, id: \.self) { index in
                ExcludeRow(
                    title: languages[index],
                    bindings: rowBindings(index: index),
                    isFirstRow: index == 0
                )
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.excludedLanguages)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.excludedLanguages)
        }
        .textCase(nil)
    }
}

private struct ExcludeRow: View {
    private let title: String
    private let bindings: [Binding<Bool>]
    private let isFirstRow: Bool

    init(title: String, bindings: [Binding<Bool>], isFirstRow: Bool) {
        self.title = title
        self.bindings = bindings
        self.isFirstRow = isFirstRow
    }

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .font(.subheadline)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: DeviceUtil.windowW * 0.25)

            ForEach(0..<bindings.count, id: \.self) { index in
                let shouldHide = isFirstRow && index == 0
                ExcludeToggle(isOn: bindings[index]).opacity(shouldHide ? 0 : 1)
            }
        }
    }
}

private struct ExcludeToggle: View {
    @Binding private var isOn: Bool

    init(isOn: Binding<Bool>) {
        _isOn = isOn
    }

    var body: some View {
        Color.clear
            .overlay {
                Image(systemSymbol: isOn ? .nosign : .circle)
                    .foregroundColor(isOn ? .red : .primary)
                    .font(.title)
            }
        .onTapGesture {
            withAnimation { isOn.toggle() }
            HapticsUtil.generateFeedback(style: .soft)
        }
    }
}

// MARK: ExcludedUploadersSection
private struct ExcludedUploadersSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState var isFocused

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            TextEditor(text: $ehSetting.excludedUploaders)
                .textInputAutocapitalization(.none)
                .frame(maxHeight: DeviceUtil.windowH * 0.3)
                .disableAutocorrection(true)
                .focused($isFocused)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.excludedUploaders)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.excludedUploaders)
        } footer: {
            Text(
                L10n.Localizable.EhSettingView.Description.excludedUploadersCount(
                    "\(ehSetting.excludedUploaders.lineCount)", "\(1000)"
                )
                .localizedKey
            )
        }
        .textCase(nil)
    }
}

// MARK: SearchResultCountSection
private struct SearchResultCountSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.resultCount, selection: $ehSetting.searchResultCount) {
                ForEach(ehSetting.capableSearchResultCounts) { count in
                    Text(String(count.value))
                        .tag(count)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.searchResultCount)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.resultCount)
        }
        .textCase(nil)
    }
}

// MARK: ThumbnailSettingsSection
private struct ThumbnailSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.thumbnailLoadTiming,
                selection: $ehSetting.thumbnailLoadTiming
            ) {
                ForEach(EhSetting.ThumbnailLoadTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.thumbnailSettings)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.thumbnailLoadTiming)
        } footer: {
            Text(ehSetting.thumbnailLoadTiming.description)
        }
        .textCase(nil)

        Section(L10n.Localizable.EhSettingView.Description.thumbnailConfiguration) {
            LabeledContent(L10n.Localizable.EhSettingView.Title.thumbnailSize) {
                Picker(selection: $ehSetting.thumbnailConfigSize) {
                    ForEach(ehSetting.capableThumbnailConfigSizes) { size in
                        Text(size.value)
                            .tag(size)
                    }
                } label: {
                    Text(ehSetting.thumbnailConfigSize.value)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            LabeledContent(L10n.Localizable.EhSettingView.Title.thumbnailRowCount) {
                Picker(selection: $ehSetting.thumbnailConfigRows) {
                    ForEach(ehSetting.capableThumbnailConfigRowCounts) { row in
                        Text(row.value)
                            .tag(row)
                    }
                } label: {
                    Text(ehSetting.capableThumbnailConfigRowCount.value)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .textCase(nil)
    }
}

// MARK: ThumbnailScalingSection
private struct ThumbnailScalingSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.scaleFactor,
                value: $ehSetting.thumbnailScaleFactor,
                range: 75...150,
                unit: "%"
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.thumbnailScaling)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.scaleFactor)
        }
        .textCase(nil)
    }
}

// MARK: ViewportOverrideSection
private struct ViewportOverrideSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.virtualWidth,
                value: $ehSetting.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.viewportOverride)
                .newlineBold()
                .appending(L10n.Localizable.EhSettingView.Description.virtualWidth)
        }
        .textCase(nil)
    }
}

private struct ValuePicker: View {
    private let title: String
    @Binding private var value: Float
    private let range: ClosedRange<Float>
    private let unit: String

    init(title: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "") {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
    }

    var body: some View {
        LabeledContent(title) {
            Text(String(Int(value)) + unit)
                .foregroundStyle(.tint)
        }

        Slider(
            value: $value,
            in: range,
            step: 1,
            minimumValueLabel: Text(String(Int(range.lowerBound)) + unit)
                .fontWeight(.medium)
                .font(.callout),
            maximumValueLabel: Text(String(Int(range.upperBound)) + unit)
                .fontWeight(.medium)
                .font(.callout),
            label: EmptyView.init
        )
    }
}

// MARK: GalleryCommentsSection
private struct GalleryCommentsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryComments) {
            Picker(
                L10n.Localizable.EhSettingView.Title.commentsSortOrder,
                selection: $ehSetting.commentsSortOrder
            ) {
                ForEach(EhSetting.CommentsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)

            Picker(
                L10n.Localizable.EhSettingView.Title.commentsVotesShowTiming,
                selection: $ehSetting.commentVotesShowTiming
            ) {
                ForEach(EhSetting.CommentVotesShowTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: GalleryTagsSection
private struct GalleryTagsSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryTags) {
            Picker(L10n.Localizable.EhSettingView.Title.tagsSortOrder, selection: $ehSetting.tagsSortOrder) {
                ForEach(EhSetting.TagsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: GalleryPageNumberingSection
private struct GalleryPageNumberingSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryPageNumbering) {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showGalleryPageNumbers,
                isOn: $ehSetting.galleryShowPageNumbers
            )
        }
        .textCase(nil)
    }
}

// MARK: OriginalImagesSection
private struct OriginalImagesSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
            Section(L10n.Localizable.EhSettingView.Section.Title.originalImages) {
                Toggle(
                    L10n.Localizable.EhSettingView.Title.useOriginalImages,
                    isOn: useOriginalImagesBinding
                )
            }
            .textCase(nil)
        }
    }
}

// MARK: MultiplePageViewerSection
private struct MultiplePageViewerSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        if let useMultiplePageViewerBinding = Binding($ehSetting.useMultiplePageViewer),
           let multiplePageViewerStyleBinding = Binding($ehSetting.multiplePageViewerStyle),
           let multiplePageViewerShowPaneBinding = Binding($ehSetting.multiplePageViewerShowThumbnailPane)
        {
            Section(L10n.Localizable.EhSettingView.Section.Title.multiPageViewer) {
                Toggle(
                    L10n.Localizable.EhSettingView.Title.useMultiPageViewer,
                    isOn: useMultiplePageViewerBinding
                )

                Picker(
                    L10n.Localizable.EhSettingView.Title.displayStyle,
                    selection: multiplePageViewerStyleBinding
                ) {
                    ForEach(EhSetting.MultiplePageViewerStyle.allCases) { style in
                        Text(style.value)
                            .tag(style)
                    }
                }
                .pickerStyle(.menu)

                Toggle(
                    L10n.Localizable.EhSettingView.Title.showThumbnailPane,
                    isOn: multiplePageViewerShowPaneBinding
                )
            }
            .textCase(nil)
        }
    }
}

private extension String {
    var lineCount: Int {
        var count = 0
        enumerateLines { line, _ in
            if !line.isEmpty {
                count += 1
            }
        }
        return count
    }
}

private extension Text {
    func newlineBold() -> Text {
        bold() + Text("\n")
    }

    func appending(_ string: some StringProtocol) -> Text {
        self + Text(string)
    }
}

struct EhSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EhSettingView(
                store: .init(
                    initialState: .init(ehSetting: .empty, ehProfile: .empty, loadingState: .idle),
                    reducer: EhSettingReducer()
                ),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
