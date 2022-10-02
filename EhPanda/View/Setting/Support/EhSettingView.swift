//
//  EhSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/07.
//

import SwiftUI
import ComposableArchitecture

struct EhSettingView: View {
    private let store: Store<EhSettingState, EhSettingAction>
    @ObservedObject private var viewStore: ViewStore<EhSettingState, EhSettingAction>
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    init(store: Store<EhSettingState, EhSettingAction>, bypassesSNIFiltering: Bool, blurRadius: Double) {
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
                LoadingView().tint(nil)
            } else if case .failed(let error) = viewStore.loadingState {
                ErrorView(error: error, action: { viewStore.send(.fetchEhSetting) }).tint(nil)
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
        .sheet(unwrapping: viewStore.binding(\.$route), case: /EhSettingState.Route.webView) { route in
            WebView(url: route.wrappedValue).autoBlur(radius: blurRadius)
        }
        .toolbar(content: toolbar)
        .navigationTitle(R.string.localizable.ehSettingViewTitleHostSettings(AppUtil.galleryHost.rawValue))
    }
    // MARK: Form
    private func form(ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>) -> some View {
        Form {
            Group {
                EhProfileSection(
                    route: viewStore.binding(\.$route),
                    ehSetting: ehSetting, ehProfile: ehProfile,
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
                TagNamespacesSection(ehSetting: ehSetting)
                TagFilteringThresholdSection(ehSetting: ehSetting)
            }
            Group {
                TagWatchingThresholdSection(ehSetting: ehSetting)
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
//                HathLocalNetworkHostSection(ehSetting: ehSetting)
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
                HStack {
                    Spacer()
                    Button(R.string.localizable.ehSettingViewToolbarItemButtonDone()) {
                        viewStore.send(.setKeyboardHidden)
                    }
                }
            }
        }
    }
}

// MARK: EhProfileSection
private struct EhProfileSection: View {
    @Binding private var route: EhSettingState.Route?
    @Binding private var ehSetting: EhSetting
    @Binding private var ehProfile: EhProfile
    @Binding private var editingProfileName: String
    private let deleteAction: () -> Void
    private let deleteDialogAction: () -> Void
    private let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    init(
        route: Binding<EhSettingState.Route?>, ehSetting: Binding<EhSetting>,
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
        Section(R.string.localizable.ehSettingViewSectionTitleProfileSettings()) {
            Picker(R.string.localizable.ehSettingViewTitleSelectedProfile(), selection: $ehProfile) {
                ForEach(ehSetting.ehProfiles) { ehProfile in
                    Text(ehProfile.name).tag(ehProfile)
                }
            }
            .pickerStyle(.menu)
            if !ehProfile.isDefault {
                Button(R.string.localizable.ehSettingViewButtonSetAsDefault()) {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }
                Button(
                    R.string.localizable.ehSettingViewButtonDeleteProfile(),
                    role: .destructive, action: deleteDialogAction
                )
                .confirmationDialog(
                    message: R.string.localizable.confirmationDialogTitleDelete(),
                    unwrapping: $route, case: /EhSettingState.Route.deleteProfile
                ) {
                    Button(
                        R.string.localizable.confirmationDialogButtonDelete(),
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
            SettingTextField(
                text: $editingProfileName, width: nil, alignment: .leading, background: .clear
            )
            .focused($isFocused)
            Button(R.string.localizable.ehSettingViewButtonRename()) {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .disabled(isFocused)
            if ehSetting.ehProfiles.count < 10 {
                Button(R.string.localizable.ehSettingViewButtonCreateNew()) {
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleImageLoadSettings()),
            footer: Text(ehSetting.loadThroughHathSetting.description)
        ) {
            Picker(
                R.string.localizable.ehSettingViewTitleLoadImagesThroughTheHathNetwork(),
                selection: $ehSetting.loadThroughHathSetting
            ) {
                ForEach(ehSetting.capableLoadThroughHathSettings) { setting in
                    Text(setting.value).tag(setting)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(
            R.string.localizable.ehSettingViewDescriptionBrowsingCountry(
                ehSetting.localizedLiteralBrowsingCountry ?? ehSetting.literalBrowsingCountry
            )
            .localizedKey
        ) {
            Picker(R.string.localizable.ehSettingViewTitleBrowsingCountry(), selection: $ehSetting.browsingCountry) {
                ForEach(EhSetting.BrowsingCountry.allCases) { country in
                    Text(country.name).tag(country)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleImageSizeSettings()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionImageResolution())
        ) {
            Picker(R.string.localizable.ehSettingViewTitleImageResolution(), selection: $ehSetting.imageResolution) {
                ForEach(ehSetting.capableImageResolutions) { setting in
                    Text(setting.value).tag(setting)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(R.string.localizable.ehSettingViewDescriptionImageSize()) {
            Text(R.string.localizable.ehSettingViewTitleImageSize())
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleHorizontal(),
                value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px"
            )
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleVertical(),
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleGalleryNameDisplay()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionGalleryName())
        ) {
            Picker(R.string.localizable.ehSettingViewTitleGalleryName(), selection: $ehSetting.galleryName) {
                ForEach(EhSetting.GalleryName.allCases) { name in
                    Text(name.value).tag(name)
                }
            }
            .pickerStyle(.menu)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleArchiverSettings()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionArchiverBehavior())
        ) {
            Picker(R.string.localizable.ehSettingViewTitleArchiverBehavior(), selection: $ehSetting.archiverBehavior) {
                ForEach(EhSetting.ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value).tag(behavior)
                }
            }
            .pickerStyle(.menu)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleFrontPageSettings()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionDisplayMode())
        ) {
            Picker(R.string.localizable.ehSettingViewTitleDisplayMode(), selection: $ehSetting.displayMode) {
                ForEach(EhSetting.DisplayMode.allCases) { mode in
                    Text(mode.value).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(R.string.localizable.ehSettingViewDescriptionGalleryCategory()) {
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleFavorites()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionFavoriteCategories())
        ) {
            ForEach(tuples, id: \.0) { category, nameBinding in
                HStack(spacing: 30) {
                    Circle().foregroundColor(category.color).frame(width: 10)
                    SettingTextField(
                        text: nameBinding, width: nil, alignment: .leading, background: .clear
                    )
                    .focused($isFocused)
                }
                .padding(.leading)
            }
        }
        .textCase(nil)
        Section(R.string.localizable.ehSettingViewDescriptionFavoritesSortOrder()) {
            Picker(
                R.string.localizable.ehSettingViewTitleFavoritesSortOrder(),
                selection: $ehSetting.favoritesSortOrder
            ) {
                ForEach(EhSetting.FavoritesSortOrder.allCases) { order in
                    Text(order.value).tag(order)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleRatings()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionRatingsColor())
        ) {
            HStack {
                Text(R.string.localizable.ehSettingViewTitleRatingsColor())
                Spacer()
                SettingTextField(
                    text: $ehSetting.ratingsColor, promptText: R.string.localizable
                        .ehSettingViewPromtRatingsColor(), width: 80
                )
                .focused($isFocused)
            }
        }
        .textCase(nil)
    }
}

// MARK: TagNamespacesSection
private struct TagNamespacesSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    private var tuples: [(String, Binding<Bool>)] {
        TagNamespace.allCases.dropLast().enumerated().map { index, namespace in
            (namespace.value, $ehSetting.excludedNamespaces[index])
        }
    }

    var body: some View {
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleTagsNamespaces()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionTagsNamespaces())
        ) {
            ExcludeView(tuples: tuples)
        }
        .textCase(nil)
    }
}

private struct ExcludeView: View {
    private let tuples: [(String, Binding<Bool>)]

    init(tuples: [(String, Binding<Bool>)]) {
        self.tuples = tuples
    }

    private let gridItems = [
        GridItem(.adaptive(
            minimum: DeviceUtil.isPadWidth ? 100 : 80, maximum: 100
        ))
    ]

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.0) { text, isExcluded in
                ZStack {
                    Text(text).bold().opacity(isExcluded.wrappedValue ? 0 : 1)
                    ZStack {
                        Text(text)
                        let width = (CGFloat(text.count) * 8) + 8
                        let line = Rectangle().frame(width: width, height: 1)
                        VStack(spacing: 2) {
                            line
                            line
                        }
                    }
                    .foregroundColor(.red).opacity(isExcluded.wrappedValue ? 1 : 0)
                }
                .onTapGesture {
                    HapticUtil.generateFeedback(style: .soft)
                    withAnimation { isExcluded.wrappedValue.toggle() }
                }
            }
        }
        .padding(.vertical)
    }
}

// MARK: TagFilteringThresholdSection
private struct TagFilteringThresholdSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleTagFilteringThreshold()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionTagFilteringThreshold())
        ) {
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleTagFilteringThreshold(),
                value: $ehSetting.tagFilteringThreshold, range: -9999...0
            )
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleTagWatchingThreshold()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionTagWatchingThreshold())
        ) {
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleTagWatchingThreshold(),
                value: $ehSetting.tagWatchingThreshold, range: 0...9999
            )
        }
        .textCase(nil)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleExcludedLanguages()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionExcludedLanguages())
        ) {
            HStack {
                Text("").frame(width: DeviceUtil.windowW * 0.25)
                ForEach(EhSetting.ExcludedLanguagesCategory.allCases) { category in
                    Color.clear.overlay {
                        Text(category.value).lineLimit(1).font(.subheadline).fixedSize()
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
            HStack {
                Text(title).lineLimit(1).font(.subheadline).fixedSize()
                Spacer()
            }
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
        Color.clear.overlay {
            Image(systemSymbol: isOn ? .nosign : .circle).foregroundColor(isOn ? .red : .primary).font(.title)
        }
        .onTapGesture {
            withAnimation { isOn.toggle() }
            HapticUtil.generateFeedback(style: .soft)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleExcludedUploaders()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionExcludedUploaders()),
            footer: Text(
                R.string.localizable.ehSettingViewDescriptionExcludedUploadersCount(
                    "\(ehSetting.excludedUploaders.lineCount)", "\(1000)"
                )
                .localizedKey
            )
        ) {
            TextEditor(text: $ehSetting.excludedUploaders).textInputAutocapitalization(.none)
                .frame(maxHeight: DeviceUtil.windowH * 0.3).disableAutocorrection(true).focused($isFocused)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleSearchResultCount()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionResultCount())
        ) {
            Picker(R.string.localizable.ehSettingViewTitleResultCount(), selection: $ehSetting.searchResultCount) {
                ForEach(ehSetting.capableSearchResultCounts) { count in
                    Text(String(count.value)).tag(count)
                }
            }
            .pickerStyle(.menu)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleThumbnailSettings()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionThumbnailLoadTiming()),
            footer: Text(ehSetting.thumbnailLoadTiming.description)
        ) {
            Picker(
                R.string.localizable.ehSettingViewTitleThumbnailLoadTiming(),
                selection: $ehSetting.thumbnailLoadTiming
            ) {
                ForEach(EhSetting.ThumbnailLoadTiming.allCases) { timing in
                    Text(timing.value).tag(timing)
                }
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(R.string.localizable.ehSettingViewDescriptionThumbnailConfiguration()) {
            HStack {
                Text(R.string.localizable.ehSettingViewTitleThumbnailSize())
                Spacer()
                Picker(selection: $ehSetting.thumbnailConfigSize) {
                    ForEach(ehSetting.capableThumbnailConfigSizes) { size in
                        Text(size.value).tag(size)
                    }
                } label: {
                    Text(ehSetting.thumbnailConfigSize.value)
                }
                .pickerStyle(.segmented).frame(width: 200)
            }
            HStack {
                Text(R.string.localizable.ehSettingViewTitleThumbnailRowCount())
                Spacer()
                Picker(selection: $ehSetting.thumbnailConfigRows) {
                    ForEach(ehSetting.capableThumbnailConfigRowCounts) { row in
                        Text(row.value).tag(row)
                    }
                } label: {
                    Text(ehSetting.capableThumbnailConfigRowCount.value)
                }
                .pickerStyle(.segmented).frame(width: 200)
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleThumbnailScaling()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionScaleFactor())
        ) {
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleScaleFactor(),
                value: $ehSetting.thumbnailScaleFactor, range: 75...150, unit: "%"
            )
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
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleViewportOverride()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionVirtualWidth())
        ) {
            ValuePicker(
                title: R.string.localizable.ehSettingViewTitleVirtualWidth(),
                value: $ehSetting.viewportVirtualWidth, range: 0...9999, unit: "px"
            )
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
        VStack {
            HStack {
                Text(title)
                Spacer()
                Text(String(Int(value)) + unit).foregroundStyle(.tint)
            }
        }
        Slider(
            value: $value, in: range, step: 1,
            minimumValueLabel: Text(String(Int(range.lowerBound)) + unit).fontWeight(.medium).font(.callout),
            maximumValueLabel: Text(String(Int(range.upperBound)) + unit).fontWeight(.medium).font(.callout),
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
        Section(R.string.localizable.ehSettingViewSectionTitleGalleryComments()) {
            Picker(
                R.string.localizable.ehSettingViewTitleCommentsSortOrder(),
                selection: $ehSetting.commentsSortOrder
            ) {
                ForEach(EhSetting.CommentsSortOrder.allCases) { order in
                    Text(order.value).tag(order)
                }
            }
            .pickerStyle(.menu)
            Picker(
                R.string.localizable.ehSettingViewTitleCommentsVotesShowTiming(),
                selection: $ehSetting.commentVotesShowTiming
            ) {
                ForEach(EhSetting.CommentVotesShowTiming.allCases) { timing in
                    Text(timing.value).tag(timing)
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
        Section(R.string.localizable.ehSettingViewSectionTitleGalleryTags()) {
            Picker(R.string.localizable.ehSettingViewTitleTagsSortOrder(), selection: $ehSetting.tagsSortOrder) {
                ForEach(EhSetting.TagsSortOrder.allCases) { order in
                    Text(order.value).tag(order)
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
        Section(R.string.localizable.ehSettingViewSectionTitleGalleryPageNumbering()) {
            Toggle(
                R.string.localizable.ehSettingViewTitleShowGalleryPageNumbers(),
                isOn: $ehSetting.galleryShowPageNumbers
            )
        }
        .textCase(nil)
    }
}

/*
// MARK: HathLocalNetworkHostSection
private struct HathLocalNetworkHostSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState var isFocused

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text(R.string.localizable.ehSettingViewSectionTitleHathLocalNetworkHost()).newlineBold()
            + Text(R.string.localizable.ehSettingViewDescriptionIpAddressPort())
        ) {
            HStack {
                Text(R.string.localizable.ehSettingViewTitleIpAddressPort())
                Spacer()
                SettingTextField(text: $ehSetting.hathLocalNetworkHost, width: 150).focused($isFocused)
            }
        }
        .textCase(nil)
    }
}
 */

// MARK: OriginalImagesSection
private struct OriginalImagesSection: View {
    @Binding private var ehSetting: EhSetting

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Group {
            if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
                Section(R.string.localizable.ehSettingViewSectionTitleOriginalImages()) {
                    Toggle(
                        R.string.localizable.ehSettingViewTitleUseOriginalImages(),
                        isOn: useOriginalImagesBinding
                    )
                }
                .textCase(nil)
            }
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
        Group {
            if let useMultiplePageViewerBinding = Binding($ehSetting.useMultiplePageViewer),
               let multiplePageViewerStyleBinding = Binding($ehSetting.multiplePageViewerStyle),
               let multiplePageViewerShowPaneBinding = Binding($ehSetting.multiplePageViewerShowThumbnailPane)
            {
                Section(R.string.localizable.ehSettingViewSectionTitleMultiPageViewer()) {
                    Toggle(
                        R.string.localizable.ehSettingViewTitleUseMultiPageViewer(),
                        isOn: useMultiplePageViewerBinding
                    )
                    Picker(
                        R.string.localizable.ehSettingViewTitleDisplayStyle(),
                        selection: multiplePageViewerStyleBinding
                    ) {
                        ForEach(EhSetting.MultiplePageViewerStyle.allCases) { style in
                            Text(style.value).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    Toggle(
                        R.string.localizable.ehSettingViewTitleShowThumbnailPane(),
                        isOn: multiplePageViewerShowPaneBinding
                    )
                }
                .textCase(nil)
            }
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
}

struct EhSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EhSettingView(
                store: .init(
                    initialState: .init(ehSetting: .empty, ehProfile: .empty, loadingState: .idle),
                    reducer: ehSettingReducer,
                    environment: EhSettingEnvironment(
                        hapticClient: .live,
                        cookiesClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
