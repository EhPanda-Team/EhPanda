//
//  EhSettingsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/07.
//

import SwiftUI
import SwiftyBeaver

struct EhSettingsView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    @State private var profile: EhProfile?
    @State private var loadingFlag = false
    @State private var loadFailedFlag = false
    @State private var submittingFlag = false
    @State private var shouldHideKeyboard = ""

    private var title: String {
        galleryHost.rawValue + " " + "Settings".localized()
    }

    private func form(profileBinding: Binding<EhProfile>) -> some View {
        Form {
            Group {
                ImageLoadSettingsSection(profile: profileBinding)
                ImageSizeSettingsSection(profile: profileBinding)
                GalleryNameDisplaySection(profile: profileBinding)
                ArchiverSettingsSection(profile: profileBinding)
                FrontPageSettingsSection(profile: profileBinding)
                FavoritesSection(profile: profileBinding, shouldHideKeyboard: $shouldHideKeyboard)
                RatingsSection(profile: profileBinding, shouldHideKeyboard: $shouldHideKeyboard)
            }
            Group {
                TagNamespacesSection(profile: profileBinding)
                TagFilteringThresholdSection(profile: profileBinding)
                TagWatchingThresholdSection(profile: profileBinding)
                ExcludedUploadersSection(profile: profileBinding, shouldHideKeyboard: $shouldHideKeyboard)
                SearchResultCountSection(profile: profileBinding)
                ThumbnailSettingsSection(profile: profileBinding)
                ThumbnailScalingSection(profile: profileBinding)
            }
            Group {
                ViewportOverrideSection(profile: profileBinding)
                GalleryCommentsSection(profile: profileBinding)
                GalleryTagsSection(profile: profileBinding)
                GalleryPageNumberingSection(profile: profileBinding)
                HathLocalNetworkHostSection(profile: profileBinding, shouldHideKeyboard: $shouldHideKeyboard)
                OriginalImagesSection(profile: profileBinding)
                MultiplePageViewerSection(profile: profileBinding)
            }
        }
        .transition(opacityTransition)
    }

    var body: some View {
        Group {
            if loadingFlag || submittingFlag {
                LoadingView()
            } else if loadFailedFlag {
                NetworkErrorView(
                    retryAction: fetchProfile
                )
            } else if let profileBinding = Binding($profile) {
                form(profileBinding: profileBinding)
            } else {
                Circle().frame(width: 1).opacity(0.1)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleWebViewConfig) {
                    Image(systemName: "globe")
                }
                .disabled(setting.bypassesSNIFiltering)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: submitProfileChanges) {
                    Image(systemName: "icloud.and.arrow.up")
                }
                .disabled(profile == nil)
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        shouldHideKeyboard = UUID().uuidString
                    }
                }
            }
        }
        .onAppear(perform: fetchProfile)
        .navigationTitle(title)
    }

    func fetchProfile() {
        loadFailedFlag = false
        guard !loadingFlag else { return }
        loadingFlag = true

        let token = SubscriptionToken()
        EhProfileRequest()
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                loadingFlag = false
                if case .failure(let error) = completion {
                    SwiftyBeaver.error(error)
                    loadFailedFlag = true
                }
                token.unseal()
            } receiveValue: { profile in
                self.profile = profile
            }
            .seal(in: token)
    }
    func submitProfileChanges() {
        guard let profile = profile,
              !submittingFlag
        else { return }

        submittingFlag = true

        let token = SubscriptionToken()
        SubmitEhProfileChangesRequest(profile: profile)
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                submittingFlag = false
                if case .failure(let error) = completion {
                    SwiftyBeaver.error(error)
                    loadFailedFlag = true
                }
                token.unseal()
            } receiveValue: { profile in
                self.profile = profile
            }
            .seal(in: token)
    }
    func toggleWebViewConfig() {
        store.dispatch(.toggleSettingViewSheet(state: .webviewConfig))
    }
}

// MARK: ImageLoadSettingsSection
private struct ImageLoadSettingsSection: View {
    @Binding private var profile: EhProfile

    private var capableSettings: [EhProfileLoadThroughHathSetting] {
        EhProfileLoadThroughHathSetting.allCases.filter { setting in
            setting <= profile.capableLoadThroughHathSetting
        }
    }
    // swiftlint:disable line_length
    private var browsingCountryKey: LocalizedStringKey {
        LocalizedStringKey(
            "You appear to be browsing the site from **PLACEHOLDER** or use a VPN or proxy in this country, which means the site will try to load images from Hath clients in this general geographic region. If this is incorrect, or if you want to use a different region for any reason (like if you are using a split tunneling VPN), you can select a different country below.".localized()
                .replacingOccurrences(of: "PLACEHOLDER", with: profile.literalBrowsingCountry.localized())
        )
    }
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Image Load Settings"),
            footer: Text(profile.loadThroughHathSetting.description.localized())
        ) {
            Text("Load images through the Hath network")
            Picker(selection: $profile.loadThroughHathSetting) {
                ForEach(capableSettings) { setting in
                    Text(setting.value.localized()).tag(setting)
                }
            } label: {
                Text(profile.loadThroughHathSetting.value.localized())
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
        Section(browsingCountryKey) {
            HStack {
                Text("Browsing country")
                Spacer()
                Picker(selection: $profile.browsingCountry) {
                    ForEach(EhProfileBrowsingCountry.allCases) { country in
                        Text(country.name.localized()).tag(country)
                    }
                } label: {
                    Text(profile.browsingCountry.name.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ImageSizeSettingsSection
private struct ImageSizeSettingsSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let imageResolutionDescription = "Normally, images are resampled to 1280 pixels of horizontal resolution for online viewing. You can alternatively select one of the following resample resolutions. To avoid murdering the staging servers, resolutions above 1280x are temporarily restricted to donators, people with any hath perk, and people with a UID below 3,000,000."
    private let imageSizeDescription = "While the site will automatically scale down images to fit your screen width, you can also manually restrict the maximum display size of an image. Like the automatic scaling, this does not resample the image, as the resizing is done browser-side. (0 = no limit)"
    // swiftlint:enable line_length

    private var capableResolutions: [EhProfileImageResolution] {
        EhProfileImageResolution.allCases.filter { resolution in
            resolution <= profile.capableImageResolution
        }
    }

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Image Size Settings").newlineBold()
            + Text(imageResolutionDescription.localized())
        ) {
            HStack {
                Text("Image resolution")
                Spacer()
                Picker(selection: $profile.imageResolution) {
                    ForEach(capableResolutions) { setting in
                        Text(setting.value.localized()).tag(setting)
                    }
                } label: {
                    Text(profile.imageResolution.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(imageSizeDescription.localized())) {
            Text("Image size")
            ValuePicker(
                title: "Horizontal",
                value: $profile.imageSizeWidth,
                range: 0...65535,
                unit: "px"
            )
            ValuePicker(
                title: "Vertical",
                value: $profile.imageSizeHeight,
                range: 0...65535,
                unit: "px"
            )
        }
        .textCase(nil)
    }
}

// MARK: GalleryNameDisplaySection
private struct GalleryNameDisplaySection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let galleryNameDescription = "Many galleries have both an English/Romanized title and a title in Japanese script. Which gallery name would you like as default?"
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Gallery Name Display").newlineBold()
            + Text(galleryNameDescription.localized())
        ) {
            HStack {
                Text("Gallery name")
                Spacer()
                Picker(selection: $profile.galleryName) {
                    ForEach(EhProfileGalleryName.allCases) { name in
                        Text(name.value.localized()).tag(name)
                    }
                } label: {
                    Text(profile.galleryName.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ArchiverSettingsSection
private struct ArchiverSettingsSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let archiverSettingsDescription = "The default behavior for the Archiver is to confirm the cost and selection for original or resampled archive, then present a link that can be clicked or copied elsewhere. You can change this behavior here."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Archiver Settings").newlineBold()
            + Text(archiverSettingsDescription.localized())
        ) {
            Text("Archiver behavior")
            Picker(selection: $profile.archiverBehavior) {
                ForEach(EhProfileArchiverBehavior.allCases) { behavior in
                    Text(behavior.value.localized()).tag(behavior)
                }
            } label: {
                Text(profile.archiverBehavior.value.localized())
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: FrontPageSettingsSection
private struct FrontPageSettingsSection: View {
    @Binding private var profile: EhProfile

    private var categoryBindings: [Binding<Bool>] {
        [
            $profile.doujinshiDisabled,
            $profile.mangaDisabled,
            $profile.artistCGDisabled,
            $profile.gameCGDisabled,
            $profile.westernDisabled,
            $profile.nonHDisabled,
            $profile.imageSetDisabled,
            $profile.cosplayDisabled,
            $profile.asianPornDisabled,
            $profile.miscDisabled
        ]
    }

    // swiftlint:disable line_length
    private let displayModeDescription = "Which display mode would you like to use on the front and search pages?"
    private let categoriesDescription = "What categories would you like to show by default on the front page and in searches?"
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Front Page Settings").newlineBold()
            + Text(displayModeDescription.localized())
        ) {
            HStack {
                Text("Display mode")
                Spacer()
                Picker(selection: $profile.displayMode) {
                    ForEach(EhProfileDisplayMode.allCases) { mode in
                        Text(mode.value.localized()).tag(mode)
                    }
                } label: {
                    Text(profile.displayMode.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(categoriesDescription.localized())) {
            CategoryView(bindings: categoryBindings)
        }
        .textCase(nil)
    }
}

// MARK: FavoritesSection
private struct FavoritesSection: View {
    @Binding private var profile: EhProfile
    @Binding private var shouldHideKeyboard: String
    @FocusState private var isFocused

    private var tuples: [(Category, Binding<String>)] {
        [
            (.misc, $profile.favoriteName0),
            (.doujinshi, $profile.favoriteName1),
            (.manga, $profile.favoriteName2),
            (.artistCG, $profile.favoriteName3),
            (.gameCG, $profile.favoriteName4),
            (.western, $profile.favoriteName5),
            (.nonH, $profile.favoriteName6),
            (.imageSet, $profile.favoriteName7),
            (.cosplay, $profile.favoriteName8),
            (.asianPorn, $profile.favoriteName9)
        ]
    }

    // swiftlint:disable line_length
    private let favoriteNamesDescription = "Here you can choose and rename your favorite categories."
    private let sortOrderDescription = "You can also select your default sort order for galleries on your favorites page. Note that favorites added prior to the March 2016 revamp did not store a timestamp, and will use the gallery posted time regardless of this setting."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>, shouldHideKeyboard: Binding<String>) {
        _profile = profile
        _shouldHideKeyboard = shouldHideKeyboard
    }

    var body: some View {
        Section(
            header: Text("Favorites").newlineBold()
            + Text(favoriteNamesDescription.localized())
        ) {
            ForEach(tuples, id: \.0) { category, nameBinding in
                HStack(spacing: 30) {
                    Circle().foregroundColor(category.color).frame(width: 10)
                    SettingTextField(
                        text: nameBinding, width: nil,
                        alignment: .leading, background: .clear
                    )
                    .focused($isFocused)
                }
                .padding(.leading)
            }
        }
        .onChange(of: shouldHideKeyboard) { _ in
            isFocused = false
        }
        .textCase(nil)
        Section(header: Text(sortOrderDescription.localized())) {
            HStack {
                Text("Favorites sort order")
                Spacer()
                Picker(selection: $profile.favoritesSortOrder) {
                    ForEach(EhProfileFavoritesSortOrder.allCases) { order in
                        Text(order.value.localized()).tag(order)
                    }
                } label: {
                    Text(profile.favoritesSortOrder.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: RatingsSection
private struct RatingsSection: View {
    @Binding private var profile: EhProfile
    @Binding private var shouldHideKeyboard: String
    @FocusState var isFocused

    // swiftlint:disable line_length
    private let ratingsDescription = "By default, galleries that you have rated will appear with red stars for ratings of 2 stars and below, green for ratings between 2.5 and 4 stars, and blue for ratings of 4.5 or 5 stars. You can customize this by entering your desired color combination below. Each letter represents one star. The default RRGGB means R(ed) for the first and second star, G(reen) for the third and fourth, and B(lue) for the fifth. You can also use (Y)ellow for the normal stars. Any five-letter R/G/B/Y combo works."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>, shouldHideKeyboard: Binding<String>) {
        _profile = profile
        _shouldHideKeyboard = shouldHideKeyboard
    }

    var body: some View {
        Section(
            header: Text("Ratings").newlineBold()
            + Text(ratingsDescription.localized())
        ) {
            HStack {
                Text("Ratings color")
                Spacer()
                SettingTextField(
                    text: $profile.ratingsColor,
                    promptText: "RRGGB", width: 80
                )
                .focused($isFocused)
            }
        }
        .onChange(of: shouldHideKeyboard) { _ in
            isFocused = false
        }
        .textCase(nil)
    }
}

// MARK: TagNamespacesSection
private struct TagNamespacesSection: View {
    @Binding private var profile: EhProfile

    private var tuples: [(String, Binding<Bool>)] {
        [
            ("reclass", $profile.reclassExcluded),
            ("language", $profile.languageExcluded),
            ("parody", $profile.parodyExcluded),
            ("character", $profile.characterExcluded),
            ("group", $profile.groupExcluded),
            ("artist", $profile.artistExcluded),
            ("male", $profile.maleExcluded),
            ("female", $profile.femaleExcluded)
        ]
    }

    // swiftlint:disable line_length
    private let tagNamespacesDescription = "If you want to exclude certain namespaces from a default tag search, you can check those below. Note that this does not prevent galleries with tags in these namespaces from appearing, it just makes it so that when searching tags, it will forego those namespaces."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Tag Namespaces").newlineBold()
            + Text(tagNamespacesDescription.localized())
        ) {
            ExcludeView(tuples: tuples)
        }
        .textCase(nil)
    }
}

// MARK: TagFilteringThresholdSection
private struct TagFilteringThresholdSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let tagFilteringThresholdDescription = "You can soft filter tags by adding them to My Tags with a negative weight. If a gallery has tags that add up to weight below this value, it is filtered from view. This threshold can be set between 0 and -9999."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Tag Filtering Threshold").newlineBold()
            + Text(tagFilteringThresholdDescription.localized())
        ) {
            ValuePicker(
                title: "Tag Filtering Threshold",
                value: $profile.tagFilteringThreshold,
                range: -9999...0
            )
        }
        .textCase(nil)
    }
}

// MARK: TagWatchingThresholdSection
private struct TagWatchingThresholdSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let tagWatchingThresholdDescription = "Recently uploaded galleries will be included on the watched screen if it has at least one watched tag with positive weight, and the sum of weights on its watched tags add up to this value or higher. This threshold can be set between 0 and 9999."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Tag Watching Threshold").newlineBold()
            + Text(tagWatchingThresholdDescription.localized())
        ) {
            ValuePicker(
                title: "Tag Watching Threshold",
                value: $profile.tagWatchingThreshold,
                range: 0...9999
            )
        }
        .textCase(nil)
    }
}

// MARK: ExcludedUploadersSection
private struct ExcludedUploadersSection: View {
    @Binding private var profile: EhProfile
    @Binding private var shouldHideKeyboard: String
    @FocusState var isFocused

    // swiftlint:disable line_length
    private let excludedUploadersDescription = "If you wish to hide galleries from certain uploaders from the gallery list and searches, add them below. Put one username per line. Note that galleries from these uploaders will never appear regardless of your search query."
    private var exclusionSlotsKey: LocalizedStringKey {
        LocalizedStringKey("You are currently using **\(profile.excludedUploaders.lineCount) / 1000** exclusion slots.")
    }
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>, shouldHideKeyboard: Binding<String>) {
        _profile = profile
        _shouldHideKeyboard = shouldHideKeyboard
    }

    var body: some View {
        Section(
            header: Text("Excluded Uploaders").newlineBold()
            + Text(excludedUploadersDescription.localized()),
            footer: Text(exclusionSlotsKey)
        ) {
            TextEditor(text: $profile.excludedUploaders)
                .frame(maxHeight: windowH * 0.3)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .focused($isFocused)
        }
        .onChange(of: shouldHideKeyboard) { _ in
            isFocused = false
        }
        .textCase(nil)
    }
}

// MARK: SearchResultCountSection
private struct SearchResultCountSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let searchResultCountDescription = "How many results would you like per page for the index/search page and torrent search pages?\n(Hath Perk: Paging Enlargement Required)"
    // swiftlint:enable line_length

    private var capableCounts: [EhProfileSearchResultCount] {
        EhProfileSearchResultCount.allCases.filter { count in
            count <= profile.capableSearchResultCount
        }
    }

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Search Result Count").newlineBold()
            + Text(searchResultCountDescription.localized())
        ) {
            HStack {
                Text("Result count")
                Spacer()
                Picker(selection: $profile.searchResultCount) {
                    ForEach(capableCounts) { count in
                        Text(String(count.value)).tag(count)
                    }
                } label: {
                    Text(String(profile.searchResultCount.value))
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ThumbnailSettingsSection
private struct ThumbnailSettingsSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let thumbnailLoadTimingDescription = "How would you like the mouse-over thumbnails on the front page to load when using List Mode?"
    private let thumbnailConfigurationDescription = "You can set a default thumbnail configuration for all galleries you visit."
    // swiftlint:enable line_length

    private var capableSizes: [EhProfileThumbnailSize] {
        EhProfileThumbnailSize.allCases.filter { size in
            size <= profile.capableThumbnailConfigSize
        }
    }
    private var capableRows: [EhProfileThumbnailRows] {
        EhProfileThumbnailRows.allCases.filter { row in
            row <= profile.capableThumbnailConfigRows
        }
    }

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Thumbnail Settings").newlineBold()
            + Text(thumbnailLoadTimingDescription.localized()),
            footer: Text(profile.thumbnailLoadTiming.description.localized())
        ) {
            HStack {
                Text("Thumbnail load timing")
                Spacer()
                Picker(selection: $profile.thumbnailLoadTiming) {
                    ForEach(EhProfileThumbnailLoadTiming.allCases) { timing in
                        Text(timing.value.localized()).tag(timing)
                    }
                } label: {
                    Text(profile.thumbnailLoadTiming.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(thumbnailConfigurationDescription.localized())) {
            HStack {
                Text("Size")
                Spacer()
                Picker(selection: $profile.thumbnailConfigSize) {
                    ForEach(capableSizes) { size in
                        Text(size.value.localized()).tag(size)
                    }
                } label: {
                    Text(profile.thumbnailConfigSize.value.localized())
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            HStack {
                Text("Rows")
                Spacer()
                Picker(selection: $profile.thumbnailConfigRows) {
                    ForEach(capableRows) { row in
                        Text(row.value).tag(row)
                    }
                } label: {
                    Text(profile.thumbnailConfigRows.value)
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
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let thumbnailScalingDescription = "Thumbnails on the thumbnail and extended gallery list views can be scaled to a custom value between 75% and 150%."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Thumbnail Scaling").newlineBold()
            + Text(thumbnailScalingDescription.localized())
        ) {
            ValuePicker(
                title: "Scale factor",
                value: $profile.thumbnailScaleFactor,
                range: 75...150,
                unit: "%"
            )
        }
        .textCase(nil)
    }
}

// MARK: ViewportOverrideSection
private struct ViewportOverrideSection: View {
    @Binding private var profile: EhProfile

    // swiftlint:disable line_length
    private let viewportOverrideDescription = "Allows you to override the virtual width of the site for mobile devices. This is normally determined automatically by your device based on its DPI. Sensible values at 100% thumbnail scale are between 640 and 1400."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section(
            header: Text("Viewport Override").newlineBold()
            + Text(viewportOverrideDescription.localized())
        ) {
            ValuePicker(
                title: "Virtual width",
                value: $profile.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
        }
        .textCase(nil)
    }
}

// MARK: GalleryCommentsSection
private struct GalleryCommentsSection: View {
    @Binding private var profile: EhProfile

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section("Gallery Comments".localized()) {
            HStack {
                Text("Comments sort order")
                Spacer()
                Picker(selection: $profile.commentsSortOrder) {
                    ForEach(EhProfileCommentsSortOrder.allCases) { order in
                        Text(order.value.localized()).tag(order)
                    }
                } label: {
                    Text(profile.commentsSortOrder.value.localized())
                }
                .pickerStyle(.menu)
            }
            HStack {
                Text("Comment votes show timing")
                Spacer()
                Picker(selection: $profile.commentVotesShowTiming) {
                    ForEach(EhProfileCommentVotesShowTiming.allCases) { timing in
                        Text(timing.value.localized()).tag(timing)
                    }
                } label: {
                    Text(profile.commentVotesShowTiming.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: GalleryTagsSection
private struct GalleryTagsSection: View {
    @Binding private var profile: EhProfile

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section("Gallery Tags".localized()) {
            HStack {
                Text("Tags sort order")
                Spacer()
                Picker(selection: $profile.tagsSortOrder) {
                    ForEach(EhProfileTagsSortOrder.allCases) { order in
                        Text(order.value.localized()).tag(order)
                    }
                } label: {
                    Text(profile.tagsSortOrder.value.localized())
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: GalleryPageNumberingSection
private struct GalleryPageNumberingSection: View {
    @Binding private var profile: EhProfile

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Section("Gallery Page Numbering".localized()) {
            Toggle(
                "Show gallery page numbers",
                isOn: $profile.galleryShowPageNumbers
            )
        }
        .textCase(nil)
    }
}

// MARK: HathLocalNetworkHostSection
private struct HathLocalNetworkHostSection: View {
    @Binding private var profile: EhProfile
    @Binding private var shouldHideKeyboard: String
    @FocusState var isFocused

    // swiftlint:disable line_length
    private let hathLocalNetworkHostDescription = "This setting can be used if you have a Hath client running on your local network with the same public IP you browse the site with. Some routers are buggy and cannot route requests back to its own IP; this allows you to work around this problem.\nIf you are running the client on the same device you browse from, use the loopback address (127.0.0.1:port). If the client is running on another device on your network, use its local network IP. Some browser configurations prevent external web sites from accessing URLs with local network IPs, the site must then be whitelisted for this to work."
    // swiftlint:enable line_length

    init(profile: Binding<EhProfile>, shouldHideKeyboard: Binding<String>) {
        _profile = profile
        _shouldHideKeyboard = shouldHideKeyboard
    }

    var body: some View {
        Section(
            header: Text("Hath Local Network Host").newlineBold()
            + Text(hathLocalNetworkHostDescription.localized())
        ) {
            HStack {
                Text("IP address:Port")
                Spacer()
                SettingTextField(text: $profile.hathLocalNetworkHost, width: 150)
                .focused($isFocused)
            }
        }
        .onChange(of: shouldHideKeyboard) { _ in
            isFocused = false
        }
        .textCase(nil)
    }
}

// MARK: OriginalImagesSection
private struct OriginalImagesSection: View {
    @Binding private var profile: EhProfile

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Group {
            if let useOriginalImagesBinding =
                Binding($profile.useOriginalImages)
            {
                Section("Original Images".localized()) {
                    Toggle(
                        "Use original images",
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
    @Binding private var profile: EhProfile

    init(profile: Binding<EhProfile>) {
        _profile = profile
    }

    var body: some View {
        Group {
            if let useMultiplePageViewerBinding =
                Binding($profile.useMultiplePageViewer),
               let multiplePageViewerStyleBinding =
                Binding($profile.multiplePageViewerStyle),
               let multiplePageViewerShowPaneBinding =
                Binding($profile.multiplePageViewerShowThumbnailPane)
            {
                Section("Multi-Page Viewer".localized()) {
                    Toggle(
                        "Use Multi-Page Viewer",
                        isOn: useMultiplePageViewerBinding
                    )
                    HStack {
                        Text("Display style")
                        Spacer()
                        Picker(selection: multiplePageViewerStyleBinding) {
                            ForEach(EhProfileMultiplePageViewerStyle.allCases) { style in
                                Text(style.value.localized()).tag(style)
                            }
                        } label: {
                            Text(profile.multiplePageViewerStyle?.value.localized() ?? "")
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle(
                        "Show thumbnail pane",
                        isOn: multiplePageViewerShowPaneBinding
                    )
                }
                .textCase(nil)
            }
        }
    }
}

// MARK: ValuePicker
private struct ValuePicker: View {
    private let title: String
    @Binding private var value: Float
    private let range: ClosedRange<Float>
    private let unit: String

    init(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        unit: String = ""
    ) {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
    }

    var body: some View {
        VStack {
            HStack {
                Text(title.localized())
                Spacer()
                Text(String(Int(value)) + unit)
                    .foregroundStyle(.tint)
            }
        }
        Slider(
            value: $value,
            in: range,
            step: 1,
            minimumValueLabel:
                Text(String(Int(range.lowerBound)) + unit)
                .fontWeight(.medium)
                .font(.callout),
            maximumValueLabel:
                Text(String(Int(range.upperBound)) + unit)
                .fontWeight(.medium)
                .font(.callout),
            label: EmptyView.init
        )
    }
}

// MARK: ExcludeView
private struct ExcludeView: View {
    private let tuples: [(String, Binding<Bool>)]

    private let gridItems = [
        GridItem(.adaptive(
            minimum: isPadWidth ? 100 : 80, maximum: 100
        ))
    ]
    private func localizedText(_ text: String) -> String {
        if text.capitalizingFirstLetter().hasLocalizedString {
            return text.capitalizingFirstLetter().localized()
        } else {
            return text
        }
    }

    init(tuples: [(String, Binding<Bool>)]) {
        self.tuples = tuples
    }

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.0) { text, isExcluded in
                ZStack {
                    Text(localizedText(text)).bold()
                        .opacity(isExcluded.wrappedValue ? 0 : 1)
                    ZStack {
                        Text(localizedText(text))
                        let width = (CGFloat(text.count) * 8) + 8
                        let line = Rectangle().frame(
                            width: width, height: 1
                        )
                        VStack(spacing: 2) {
                            line
                            line
                        }
                    }
                    .foregroundColor(.red)
                    .opacity(isExcluded.wrappedValue ? 1 : 0)
                }
                .onTapGesture {
                    isExcluded.wrappedValue.toggle()
                }
            }
        }
        .padding(.vertical)
    }
}

private extension Text {
    func newlineBold() -> Text {
        bold() + Text("\n")
    }
}

struct EhSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EhSettingsView()
        }
    }
}
