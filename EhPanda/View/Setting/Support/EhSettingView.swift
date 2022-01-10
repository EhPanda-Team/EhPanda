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

    private var title: String {
        [AppUtil.galleryHost.rawValue, "Setting".localized].joined(separator: " ")
    }

    // MARK: EhSettingView
    var body: some View {
        ZStack {
            // workaround: Stay if-else approach
            if viewStore.loadingState == .loading || viewStore.submittingState == .loading {
                LoadingView().tint(nil)
            } else if case .failed(let error) = viewStore.loadingState {
                ErrorView(error: error, retryAction: { viewStore.send(.fetchEhSetting) }).tint(nil)
            } else if let ehSetting = Binding(viewStore.binding(\.$ehSetting)),
                      let ehProfile = Binding(viewStore.binding(\.$ehProfile))
            {
                form(ehSetting: ehSetting, ehProfile: ehProfile)
                    .transition(.opacity.animation(.default))
            }
        }
        .onAppear { viewStore.send(.fetchEhSetting) }
        .onDisappear {
            if let profileSet = viewStore.ehSetting?.ehProfiles.filter({
                AppUtil.verifyEhPandaProfileName(with: $0.name)
            }).first?.value {
                viewStore.send(.setDefaultProfile(profileSet))
            }
        }
        .sheet(isPresented: viewStore.binding(\.$webViewSheetPresented)) {
            WebView(url: Defaults.URL.uConfig)
                .blur(radius: blurRadius).allowsHitTesting(blurRadius < 1)
                .animation(.linear(duration: 0.1), value: blurRadius)
        }
        .toolbar(content: toolbar).navigationTitle(title)
    }
    // MARK: Form
    private func form(ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>) -> some View {
        Form {
            Group {
                EhProfileSection(
                    ehSetting: ehSetting, ehProfile: ehProfile,
                    editingProfileName: viewStore.binding(\.$editingProfileName),
                    deleteDialogPresented: viewStore.binding(\.$deleteDialogPresented),
                    deleteAction: { viewStore.send(.setDeleteDialogPresented(true)) },
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
                HathLocalNetworkHostSection(ehSetting: ehSetting)
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
                    viewStore.send(.setWebViewSheetPresented(true))
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
                    Button("Done") {
                        viewStore.send(.setKeyboardHidden)
                    }
                }
            }
        }
    }
}

// MARK: EhProfileSection
private struct EhProfileSection: View {
    @Binding private var ehSetting: EhSetting
    @Binding private var ehProfile: EhProfile
    @Binding private var editingProfileName: String
    @Binding private var deleteDialogPresented: Bool
    private let deleteAction: () -> Void
    private let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    init(
        ehSetting: Binding<EhSetting>, ehProfile: Binding<EhProfile>,
        editingProfileName: Binding<String>, deleteDialogPresented: Binding<Bool>,
        deleteAction: @escaping () -> Void, performEhProfileAction:
        @escaping (EhProfileAction?, String?, Int) -> Void
    ) {
        _ehSetting = ehSetting
        _ehProfile = ehProfile
        _editingProfileName = editingProfileName
        _deleteDialogPresented = deleteDialogPresented
        self.deleteAction = deleteAction
        self.performEhProfileAction = performEhProfileAction
    }

    var body: some View {
        Section("Profile Settings".localized) {
            HStack {
                Text("Selected profile")
                Spacer()
                Picker(selection: $ehProfile) {
                    ForEach(ehSetting.ehProfiles) { ehProfile in
                        Text(ehProfile.name).tag(ehProfile)
                    }
                } label: {
                    Text(ehProfile.name)
                }
                .pickerStyle(.menu)
            }
            if !ehProfile.isDefault {
                Button("Set as default") {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }
                Button("Delete profile", role: .destructive, action: deleteAction)
            }
        }
        .confirmationDialog(
            "Are you sure to delete this profile?",
            isPresented: $deleteDialogPresented, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                performEhProfileAction(.delete, nil, ehProfile.value)
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
            Button("Rename") {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .disabled(isFocused)
            if ehSetting.ehProfiles.count < 10 {
                Button("Create new") {
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

    private var capableSettings: [EhSettingLoadThroughHathSetting] {
        EhSettingLoadThroughHathSetting.allCases.filter { setting in
            setting <= ehSetting.capableLoadThroughHathSetting
        }
    }
    // swiftlint:disable line_length
    private var browsingCountryKey: LocalizedStringKey {
        LocalizedStringKey(
            "You appear to be browsing the site from **PLACEHOLDER** or use a VPN or proxy in this country, which means the site will try to load images from Hath clients in this general geographic region. If this is incorrect, or if you want to use a different region for any reason (like if you are using a split tunneling VPN), you can select a different country below.".localized
                .replacingOccurrences(of: "PLACEHOLDER", with: ehSetting.literalBrowsingCountry.localized)
        )
    }
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Image Load Settings"), footer: Text(ehSetting.loadThroughHathSetting.description.localized)
        ) {
            Text("Load images through the Hath network")
            Picker(selection: $ehSetting.loadThroughHathSetting) {
                ForEach(capableSettings) { setting in
                    Text(setting.value.localized).tag(setting)
                }
            } label: {
                Text(ehSetting.loadThroughHathSetting.value.localized)
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(browsingCountryKey) {
            Picker("Browsing country", selection: $ehSetting.browsingCountry) {
                ForEach(EhSettingBrowsingCountry.allCases) { country in
                    Text(country.name.localized).tag(country)
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

    private var capableResolutions: [EhSettingImageResolution] {
        EhSettingImageResolution.allCases.filter { resolution in
            resolution <= ehSetting.capableImageResolution
        }
    }

    // swiftlint:disable line_length
    private let imageResolutionDescription = "Normally, images are resampled to 1280 pixels of horizontal resolution for online viewing. You can alternatively select one of the following resample resolutions. To avoid murdering the staging servers, resolutions above 1280x are temporarily restricted to donators, people with any hath perk, and people with a UID below 3,000,000."
    private let imageSizeDescription = "While the site will automatically scale down images to fit your screen width, you can also manually restrict the maximum display size of an image. Like the automatic scaling, this does not resample the image, as the resizing is done browser-side. (0 = no limit)"
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Image Size Settings").newlineBold() + Text(imageResolutionDescription.localized)) {
            HStack {
                Text("Image resolution")
                Spacer()
                Picker(selection: $ehSetting.imageResolution) {
                    ForEach(capableResolutions) { setting in
                        Text(setting.value.localized).tag(setting)
                    }
                } label: {
                    Text(ehSetting.imageResolution.value.localized)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(imageSizeDescription.localized) {
            Text("Image size")
            ValuePicker(title: "Horizontal", value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px")
            ValuePicker(title: "Vertical", value: $ehSetting.imageSizeHeight, range: 0...65535, unit: "px")
        }
        .textCase(nil)
    }
}

// MARK: GalleryNameDisplaySection
private struct GalleryNameDisplaySection: View {
    @Binding private var ehSetting: EhSetting

    // swiftlint:disable line_length
    private let galleryNameDescription = "Many galleries have both an English/Romanized title and a title in Japanese script. Which gallery name would you like as default?"
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Gallery Name Display").newlineBold() + Text(galleryNameDescription.localized)) {
            HStack {
                Text("Gallery name")
                Spacer()
                Picker(selection: $ehSetting.galleryName) {
                    ForEach(EhSettingGalleryName.allCases) { name in
                        Text(name.value.localized).tag(name)
                    }
                } label: {
                    Text(ehSetting.galleryName.value.localized)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ArchiverSettingsSection
private struct ArchiverSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    // swiftlint:disable line_length
    private let archiverSettingsDescription = "The default behavior for the Archiver is to confirm the cost and selection for original or resampled archive, then present a link that can be clicked or copied elsewhere. You can change this behavior here."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Archiver Settings").newlineBold() + Text(archiverSettingsDescription.localized)) {
            Text("Archiver behavior")
            Picker(selection: $ehSetting.archiverBehavior) {
                ForEach(EhSettingArchiverBehavior.allCases) { behavior in
                    Text(behavior.value.localized).tag(behavior)
                }
            } label: {
                Text(ehSetting.archiverBehavior.value.localized)
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: FrontPageSettingsSection
private struct FrontPageSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    private var categoryBindings: [Binding<Bool>] {
        $ehSetting.disabledCategories.map({ $0 })
    }

    // swiftlint:disable line_length
    private let displayModeDescription = "Which display mode would you like to use on the front and search pages?"
    private let categoriesDescription = "What categories would you like to show by default on the front page and in searches?"
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Front Page Settings").newlineBold() + Text(displayModeDescription.localized)) {
            HStack {
                Text("Display mode")
                Spacer()
                Picker(selection: $ehSetting.displayMode) {
                    ForEach(EhSettingDisplayMode.allCases) { mode in
                        Text(mode.value.localized).tag(mode)
                    }
                } label: {
                    Text(ehSetting.displayMode.value.localized)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(categoriesDescription.localized) {
            CategoryView(bindings: categoryBindings)
        }
        .textCase(nil)
    }
}

// MARK: FavoritesSection
private struct FavoritesSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState private var isFocused

    private var tuples: [(Category, Binding<String>)] {
        Category.allFavoritesCases.enumerated().map { index, category in
            (category, $ehSetting.favoriteNames[index])
        }
    }

    // swiftlint:disable line_length
    private let favoriteNamesDescription = "Here you can choose and rename your favorite categories."
    private let sortOrderDescription = "You can also select your default sort order for galleries on your favorites page. Note that favorites added prior to the March 2016 revamp did not store a timestamp, and will use the gallery posted time regardless of this setting."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Favorites").newlineBold() + Text(favoriteNamesDescription.localized)) {
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
        Section(sortOrderDescription.localized) {
            HStack {
                Text("Favorites sort order")
                Spacer()
                Picker(selection: $ehSetting.favoritesSortOrder) {
                    ForEach(EhSettingFavoritesSortOrder.allCases) { order in
                        Text(order.value.localized).tag(order)
                    }
                } label: {
                    Text(ehSetting.favoritesSortOrder.value.localized)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: RatingsSection
private struct RatingsSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState var isFocused

    // swiftlint:disable line_length
    private let ratingsDescription = "By default, galleries that you have rated will appear with red stars for ratings of 2 stars and below, green for ratings between 2.5 and 4 stars, and blue for ratings of 4.5 or 5 stars. You can customize this by entering your desired color combination below. Each letter represents one star. The default RRGGB means R(ed) for the first and second star, G(reen) for the third and fourth, and B(lue) for the fifth. You can also use (Y)ellow for the normal stars. Any five-letter R/G/B/Y combo works."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Ratings").newlineBold() + Text(ratingsDescription.localized)) {
            HStack {
                Text("Ratings color")
                Spacer()
                SettingTextField(text: $ehSetting.ratingsColor, promptText: "RRGGB", width: 80).focused($isFocused)
            }
        }
        .textCase(nil)
    }
}

// MARK: TagNamespacesSection
private struct TagNamespacesSection: View {
    @Binding private var ehSetting: EhSetting

    private var tuples: [(String, Binding<Bool>)] {
        TagCategory.allCases.dropLast().enumerated().map { index, value in
            (value.rawValue.firstLetterCapitalized, $ehSetting.excludedNamespaces[index])
        }
    }

    // swiftlint:disable line_length
    private let tagNamespacesDescription = "If you want to exclude certain namespaces from a default tag search, you can check those below. Note that this does not prevent galleries with tags in these namespaces from appearing, it just makes it so that when searching tags, it will forego those namespaces."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Tag Namespaces").newlineBold() + Text(tagNamespacesDescription.localized)) {
            ExcludeView(tuples: tuples)
        }
        .textCase(nil)
    }
}

private struct ExcludeView: View {
    private let tuples: [(String, Binding<Bool>)]

    private let gridItems = [
        GridItem(.adaptive(
            minimum: DeviceUtil.isPadWidth ? 100 : 80, maximum: 100
        ))
    ]

    init(tuples: [(String, Binding<Bool>)]) {
        self.tuples = tuples
    }

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.0) { text, isExcluded in
                ZStack {
                    Text(text.localized).bold().opacity(isExcluded.wrappedValue ? 0 : 1)
                    ZStack {
                        Text(text.localized)
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

    // swiftlint:disable line_length
    private let tagFilteringThresholdDescription = "You can soft filter tags by adding them to My Tags with a negative weight. If a gallery has tags that add up to weight below this value, it is filtered from view. This threshold can be set between 0 and -9999."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Tag Filtering Threshold").newlineBold() + Text(tagFilteringThresholdDescription.localized)
        ) {
            ValuePicker(title: "Tag Filtering Threshold", value: $ehSetting.tagFilteringThreshold, range: -9999...0)
        }
        .textCase(nil)
    }
}

// MARK: TagWatchingThresholdSection
private struct TagWatchingThresholdSection: View {
    @Binding private var ehSetting: EhSetting

    // swiftlint:disable line_length
    private let tagWatchingThresholdDescription = "Recently uploaded galleries will be included on the watched screen if it has at least one watched tag with positive weight, and the sum of weights on its watched tags add up to this value or higher. This threshold can be set between 0 and 9999."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Tag Watching Threshold").newlineBold() + Text(tagWatchingThresholdDescription.localized
                                                                       )) {
            ValuePicker(title: "Tag Watching Threshold", value: $ehSetting.tagWatchingThreshold, range: 0...9999)
        }
        .textCase(nil)
    }
}

// MARK: ExcludedLanguagesSection
private struct ExcludedLanguagesSection: View {
    @Binding private var ehSetting: EhSetting

    private var languageBindings: [Binding<Bool>] {
        $ehSetting.excludedLanguages.map( { $0 })
    }
    private let languages = [
        "Japanese", "English", "Chinese", "Dutch",
        "French", "German", "Hungarian", "Italian",
        "Korean", "Polish", "Portuguese", "Russian",
        "Spanish", "Thai", "Vietnamese", "N/A", "Other"
    ]

    // swiftlint:disable line_length
    private let excludedLanguagesDescription = "If you wish to hide galleries in certain languages from the gallery list and searches, select them from the list below. Note that matching galleries will never appear regardless of your search query."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Excluded Languages").newlineBold() + Text(excludedLanguagesDescription.localized)) {
            HStack {
                Text("").frame(width: DeviceUtil.windowW * 0.25)
                ForEach(["Original", "Translated", "Rewrite"], id: \.self) { category in
                    Color.clear.overlay {
                        Text(category.localized).lineLimit(1).font(.subheadline).fixedSize()
                    }
                }
            }
            ForEach(0..<(languageBindings.count / 3) + 1) { index in
                ExcludeRow(
                    title: languages[index],
                    bindings: [-1, 0, 1].map { num in
                        let index = index * 3 + num

                        guard index != -1
                        else { return .constant(false) }
                        return languageBindings[index]
                    },
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
                Text(title.localized).lineLimit(1).font(.subheadline).fixedSize()
                Spacer()
            }
            .frame(width: DeviceUtil.windowW * 0.25)
            ForEach(0..<bindings.count) { index in
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

    // swiftlint:disable line_length
    private let excludedUploadersDescription = "If you wish to hide galleries from certain uploaders from the gallery list and searches, add them below. Put one username per line. Note that galleries from these uploaders will never appear regardless of your search query."
    private var exclusionSlotsKey: LocalizedStringKey {
        LocalizedStringKey("You are currently using **\(ehSetting.excludedUploaders.lineCount) / 1000** exclusion slots.")
    }
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Excluded Uploaders").newlineBold() + Text(excludedUploadersDescription.localized),
            footer: Text(exclusionSlotsKey)
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

    private var capableCounts: [EhSettingSearchResultCount] {
        EhSettingSearchResultCount.allCases.filter { count in
            count <= ehSetting.capableSearchResultCount
        }
    }

    // swiftlint:disable line_length
    private let searchResultCountDescription = "How many results would you like per page for the index/search page and torrent search pages?\n(Hath Perk: Paging Enlargement Required)"
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Search Result Count").newlineBold() + Text(searchResultCountDescription.localized)) {
            HStack {
                Text("Result count")
                Spacer()
                Picker(selection: $ehSetting.searchResultCount) {
                    ForEach(capableCounts) { count in
                        Text(String(count.value)).tag(count)
                    }
                } label: {
                    Text(String(ehSetting.searchResultCount.value))
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ThumbnailSettingsSection
private struct ThumbnailSettingsSection: View {
    @Binding private var ehSetting: EhSetting

    private var capableSizes: [EhSettingThumbnailSize] {
        EhSettingThumbnailSize.allCases.filter { size in
            size <= ehSetting.capableThumbnailConfigSize
        }
    }
    private var capableRows: [EhSettingThumbnailRows] {
        EhSettingThumbnailRows.allCases.filter { row in
            row <= ehSetting.capableThumbnailConfigRows
        }
    }

    // swiftlint:disable line_length
    private let thumbnailLoadTimingDescription = "How would you like the mouse-over thumbnails on the front page to load when using List Mode?"
    private let thumbnailConfigurationDescription = "You can set a default thumbnail configuration for all galleries you visit."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Thumbnail Settings").newlineBold() + Text(thumbnailLoadTimingDescription.localized),
            footer: Text(ehSetting.thumbnailLoadTiming.description.localized)
        ) {
            HStack {
                Text("Thumbnail load timing")
                Spacer()
                Picker(selection: $ehSetting.thumbnailLoadTiming) {
                    ForEach(EhSettingThumbnailLoadTiming.allCases) { timing in
                        Text(timing.value.localized).tag(timing)
                    }
                } label: {
                    Text(ehSetting.thumbnailLoadTiming.value.localized)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(thumbnailConfigurationDescription.localized) {
            HStack {
                Text("Size")
                Spacer()
                Picker(selection: $ehSetting.thumbnailConfigSize) {
                    ForEach(capableSizes) { size in
                        Text(size.value.localized).tag(size)
                    }
                } label: {
                    Text(ehSetting.thumbnailConfigSize.value.localized)
                }
                .pickerStyle(.segmented).frame(width: 200)
            }
            HStack {
                Text("Rows")
                Spacer()
                Picker(selection: $ehSetting.thumbnailConfigRows) {
                    ForEach(capableRows) { row in
                        Text(row.value).tag(row)
                    }
                } label: {
                    Text(ehSetting.thumbnailConfigRows.value)
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

    // swiftlint:disable line_length
    private let thumbnailScalingDescription = "Thumbnails on the thumbnail and extended gallery list views can be scaled to a custom value between 75% and 150%."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Thumbnail Scaling").newlineBold() + Text(thumbnailScalingDescription.localized)) {
            ValuePicker(title: "Scale factor", value: $ehSetting.thumbnailScaleFactor, range: 75...150, unit: "%")
        }
        .textCase(nil)
    }
}

// MARK: ViewportOverrideSection
private struct ViewportOverrideSection: View {
    @Binding private var ehSetting: EhSetting

    // swiftlint:disable line_length
    private let viewportOverrideDescription = "Allows you to override the virtual width of the site for mobile devices. This is normally determined automatically by your device based on its DPI. Sensible values at 100% thumbnail scale are between 640 and 1400."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(header: Text("Viewport Override").newlineBold() + Text(viewportOverrideDescription.localized)) {
            ValuePicker(title: "Virtual width", value: $ehSetting.viewportVirtualWidth, range: 0...9999, unit: "px")
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
                Text(title.localized)
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
        Section("Gallery Comments".localized) {
            HStack {
                Text("Comments sort order")
                Spacer()
                Picker(selection: $ehSetting.commentsSortOrder) {
                    ForEach(EhSettingCommentsSortOrder.allCases) { order in
                        Text(order.value.localized).tag(order)
                    }
                } label: {
                    Text(ehSetting.commentsSortOrder.value.localized)
                }
                .pickerStyle(.menu)
            }
            HStack {
                Text("Comment votes show timing")
                Spacer()
                Picker(selection: $ehSetting.commentVotesShowTiming) {
                    ForEach(EhSettingCommentVotesShowTiming.allCases) { timing in
                        Text(timing.value.localized).tag(timing)
                    }
                } label: {
                    Text(ehSetting.commentVotesShowTiming.value.localized)
                }
                .pickerStyle(.menu)
            }
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
        Section("Gallery Tags".localized) {
            HStack {
                Text("Tags sort order")
                Spacer()
                Picker(selection: $ehSetting.tagsSortOrder) {
                    ForEach(EhSettingTagsSortOrder.allCases) { order in
                        Text(order.value.localized).tag(order)
                    }
                } label: {
                    Text(ehSetting.tagsSortOrder.value.localized)
                }
                .pickerStyle(.menu)
            }
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
        Section("Gallery Page Numbering".localized) {
            Toggle("Show gallery page numbers", isOn: $ehSetting.galleryShowPageNumbers)
        }
        .textCase(nil)
    }
}

// MARK: HathLocalNetworkHostSection
private struct HathLocalNetworkHostSection: View {
    @Binding private var ehSetting: EhSetting
    @FocusState var isFocused

    // swiftlint:disable line_length
    private let hathLocalNetworkHostDescription = "This setting can be used if you have a Hath client running on your local network with the same public IP you browse the site with. Some routers are buggy and cannot route requests back to its own IP; this allows you to work around this problem.\nIf you are running the client on the same device you browse from, use the loopback address (127.0.0.1:port). If the client is running on another device on your network, use its local network IP. Some browser configurations prevent external web sites from accessing URLs with local network IPs, the site must then be whitelisted for this to work."
    // swiftlint:enable line_length

    init(ehSetting: Binding<EhSetting>) {
        _ehSetting = ehSetting
    }

    var body: some View {
        Section(
            header: Text("Hath Local Network Host").newlineBold() + Text(hathLocalNetworkHostDescription.localized)
        ) {
            HStack {
                Text("IP address:Port")
                Spacer()
                SettingTextField(text: $ehSetting.hathLocalNetworkHost, width: 150).focused($isFocused)
            }
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
        Group {
            if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
                Section("Original Images".localized) {
                    Toggle("Use original images", isOn: useOriginalImagesBinding)
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
                Section("Multi-Page Viewer".localized) {
                    Toggle("Use Multi-Page Viewer", isOn: useMultiplePageViewerBinding)
                    HStack {
                        Text("Display style")
                        Spacer()
                        Picker(selection: multiplePageViewerStyleBinding) {
                            ForEach(EhSettingMultiplePageViewerStyle.allCases) { style in
                                Text(style.value.localized).tag(style)
                            }
                        } label: {
                            Text(ehSetting.multiplePageViewerStyle?.value.localized ?? "")
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Show thumbnail pane", isOn: multiplePageViewerShowPaneBinding)
                }
                .textCase(nil)
            }
        }
    }
}

private extension String {
    var lineCount: Int {
        var count = 0
        enumerateLines { _, _ in
            count += 1
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
                    initialState: .init(),
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
        .navigationViewStyle(.stack)
    }
}
