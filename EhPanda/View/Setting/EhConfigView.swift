//
//  EhConfigView.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/07.
//

import SwiftUI

private enum LoadThroughHathSetting: Int, CaseIterable, Identifiable {
    case anyClient
    case defaultPortOnly
    case no
}
private extension LoadThroughHathSetting {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .anyClient:
            return "Any client"
        case .defaultPortOnly:
            return "Default port clients only"
        case .no:
            return "No"
        }
    }
    var description: String {
        switch self {
        case .anyClient:
            return "Recommended"
        case .defaultPortOnly:
            return "Can be slower. Enable if behind firewall/proxy that blocks outgoing non-standard ports."
        case .no:
            return "Donator only. You will not be able to browse as many pages, enable only if having severe problems."
        }
    }
}

private enum ImageResolution: Int, CaseIterable, Identifiable {
    case auto
    case x780
    case x980
    case x1280
    case x1600
    case x2400
}

private extension ImageResolution {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .auto:
            return "Auto"
        case .x780:
            return "780x"
        case .x980:
            return "980x"
        case .x1280:
            return "1280x"
        case .x1600:
            return "1600x"
        case .x2400:
            return "2400x"
        }
    }
}

private enum GalleryName: Int, CaseIterable, Identifiable {
    case `default`
    case japanese
}
private extension GalleryName {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .default:
            return "Default Title"
        case .japanese:
            return "Japanese Title (if available)"
        }
    }
}

private enum ArchiverBehavior: Int, CaseIterable, Identifiable {
    case manualSelectManualStart
    case manualSelectAutoStart
    case autoSelectOriginalManualStart
    case autoSelectOriginalAutoStart
    case autoSelectResampleManualStart
    case autoSelectResampleAutoStart
}
private extension ArchiverBehavior {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .manualSelectManualStart:
            return "Manual Select, Manual Start (Default)"
        case .manualSelectAutoStart:
            return "Manual Select, Auto Start"
        case .autoSelectOriginalManualStart:
            return "Auto Select Original, Manual Start"
        case .autoSelectOriginalAutoStart:
            return "Auto Select Original, Auto Start"
        case .autoSelectResampleManualStart:
            return "Auto Select Resample, Manual Start"
        case .autoSelectResampleAutoStart:
            return "Auto Select Resample, Auto Start"
        }
    }
}

private enum DisplayMode: Int, CaseIterable, Identifiable {
    case compact
    case thumbnail
    case extended
    case minimal
    case minimalPlus
}
private extension DisplayMode {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .compact:
            return "Compact"
        case .thumbnail:
            return "Thumbnail"
        case .extended:
            return "Extended"
        case .minimal:
            return "Minimal"
        case .minimalPlus:
            return "Minimal+"
        }
    }
}

private enum SortOrder: Int, CaseIterable, Identifiable {
    case lastUpdateTime
    case favoritedTime
}
private extension SortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .lastUpdateTime:
            return "By last gallery update time"
        case .favoritedTime:
            return "By favorited time"
        }
    }
}

private enum SearchResultCount: Int, CaseIterable, Identifiable {
    case twentyFive
    case fifty
    case oneHundred
    case twoHundred
}
private extension SearchResultCount {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .twentyFive:
            return "25"
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .twoHundred:
            return "200"
        }
    }
}

private enum ThumbnailLoadTiming: Int, CaseIterable, Identifiable {
    case onMouseOver
    case onPageLoad
}
private extension ThumbnailLoadTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onMouseOver:
            return "On mouse-over"
        case .onPageLoad:
            return "On page load"
        }
    }
    // swiftlint:disable line_length
    var description: String {
        switch self {
        case .onMouseOver:
            return "On mouse-over (pages load faster, but there may be a slight delay before a thumb appears)"
        case .onPageLoad:
            return "On page load (pages take longer to load, but there is no delay for loading a thumb after the page has loaded)"
        }
    }
    // swiftlint:enable line_length
}

private enum ThumbnailSize: Int, CaseIterable, Identifiable {
    case normal
    case large
}
private extension ThumbnailSize {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .normal:
            return "Normal"
        case .large:
            return "Large"
        }
    }
}

private enum ThumbnailRows: Int, CaseIterable, Identifiable {
    case four
    case ten
    case twenty
    case forty
}
private extension ThumbnailRows {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .four:
            return "4"
        case .ten:
            return "10"
        case .twenty:
            return "20"
        case .forty:
            return "40"
        }
    }
}

// MARK: EhConfig
private struct EhConfig {
    var loadThroughHath: LoadThroughHathSetting
    var imageResolution: ImageResolution
    var imageSizeWidth: Float
    var imageSizeHeight: Float
    var galleryName: GalleryName
    var archiverBehavior: ArchiverBehavior
    var displayMode: DisplayMode

    // Front Page Settings
    var doujinshiDisabled: Bool
    var mangaDisabled: Bool
    var artistCGDisabled: Bool
    var gameCGDisabled: Bool
    var westernDisabled: Bool
    var nonHDisabled: Bool
    var imageSetDisabled: Bool
    var cosplayDisabled: Bool
    var asianPornDisabled: Bool
    var miscDisabled: Bool

    // Favorites
    var favoriteName0: String
    var favoriteName1: String
    var favoriteName2: String
    var favoriteName3: String
    var favoriteName4: String
    var favoriteName5: String
    var favoriteName6: String
    var favoriteName7: String
    var favoriteName8: String
    var favoriteName9: String

    var sortOrder: SortOrder
    var ratingsColor: String

    // Tag Namespaces
    var reclassExcluded: Bool
    var languageExcluded: Bool
    var parodyExcluded: Bool
    var characterExcluded: Bool
    var groupExcluded: Bool
    var artistExcluded: Bool
    var maleExcluded: Bool
    var femaleExcluded: Bool

    var tagFilteringThreshold: Float
    var tagWatchingThreshold: Float
    var excludedUploaders: String
    var searchResultCount: SearchResultCount
    var thumbnailLoadTiming: ThumbnailLoadTiming
    var thumbnailConfigSize: ThumbnailSize
    var thumbnailConfigRows: ThumbnailRows
    var thumbnailScaleFactor: Float
    var viewportVirtualWidth: Float
}

// MARK: EhConfigView
struct EhConfigView: View {
    @State private var config = EhConfig(
        loadThroughHath: .anyClient,
        imageResolution: .auto,
        imageSizeWidth: 0,
        imageSizeHeight: 0,
        galleryName: .default,
        archiverBehavior: .manualSelectManualStart,
        displayMode: .compact,
        doujinshiDisabled: false,
        mangaDisabled: false,
        artistCGDisabled: false,
        gameCGDisabled: false,
        westernDisabled: false,
        nonHDisabled: false,
        imageSetDisabled: false,
        cosplayDisabled: false,
        asianPornDisabled: false,
        miscDisabled: false,
        favoriteName0: "Favorites 0",
        favoriteName1: "Favorites 1",
        favoriteName2: "Favorites 2",
        favoriteName3: "Favorites 3",
        favoriteName4: "Favorites 4",
        favoriteName5: "Favorites 5",
        favoriteName6: "Favorites 6",
        favoriteName7: "Favorites 7",
        favoriteName8: "Favorites 8",
        favoriteName9: "Favorites 9",
        sortOrder: .favoritedTime,
        ratingsColor: "",
        reclassExcluded: false,
        languageExcluded: false,
        parodyExcluded: false,
        characterExcluded: false,
        groupExcluded: false,
        artistExcluded: false,
        maleExcluded: false,
        femaleExcluded: false,
        tagFilteringThreshold: 0,
        tagWatchingThreshold: 0,
        excludedUploaders: "",
        searchResultCount: .twentyFive,
        thumbnailLoadTiming: .onMouseOver,
        thumbnailConfigSize: .normal,
        thumbnailConfigRows: .four,
        thumbnailScaleFactor: 100,
        viewportVirtualWidth: 0
    )

    var body: some View {
        Form {
//            Group {
//                ImageLoadSettingsSection(config: $config)
//                ImageSizeSettingsSection(config: $config)
//                GalleryNameDisplaySection(config: $config)
//                ArchiverSettingsSection(config: $config)
//                FrontPageSettingsSection(config: $config)
//                FavoritesSection(config: $config)
//                RatingsSection(config: $config)
//                TagNamespacesSection(config: $config)
//                TagFilteringThresholdSection(config: $config)
//                TagWatchingThresholdSection(config: $config)
//            }
            Group {
//                ExcludedUploadersSection(config: $config)
//                SearchResultCountSection(config: $config)
//                ThumbnailSettingsSection(config: $config)
                ThumbnailScalingSection(config: $config)
                ViewportOverrideSection(config: $config)
            }
        }
        .navigationTitle("EhConfig")
    }
}

// MARK: ImageLoadSettingsSection
private struct ImageLoadSettingsSection: View {
    @Binding private var config: EhConfig

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header:
                Text("Image Load Settings").newlineBold() +
                Text(config.loadThroughHath.description)
        ) {
            Text("Load images through the Hath network")
            Picker(selection: $config.loadThroughHath) {
                ForEach(LoadThroughHathSetting.allCases) { setting in
                    Text(setting.value).tag(setting)
                }
            } label: {
                Text(config.loadThroughHath.value)
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: ImageSizeSettingsSection
private struct ImageSizeSettingsSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let imageResolutionDescription = "Normally, images are resampled to 1280 pixels of horizontal resolution for online viewing. You can alternatively select one of the following resample resolutions. To avoid murdering the staging servers, resolutions above 1280x are temporarily restricted to donators, people with any hath perk, and people with a UID below 3,000,000."
    private let imageSizeDescription = "While the site will automatically scale down images to fit your screen width, you can also manually restrict the maximum display size of an image. Like the automatic scaling, this does not resample the image, as the resizing is done browser-side. (0 = no limit)"
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Image Size Settings").newlineBold()
            + Text(imageResolutionDescription)
        ) {
            HStack {
                Text("Image resolution")
                Spacer()
                Picker(selection: $config.imageResolution) {
                    ForEach(ImageResolution.allCases) { setting in
                        Text(setting.value).tag(setting)
                    }
                } label: {
                    Text(config.imageResolution.value)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(imageSizeDescription)) {
            Text("Image size")
            ValuePicker(
                title: "Horizontal",
                value: $config.imageSizeWidth,
                range: 0...65535,
                unit: "px"
            )
            ValuePicker(
                title: "Vertical",
                value: $config.imageSizeHeight,
                range: 0...65535,
                unit: "px"
            )
        }
        .textCase(nil)
    }
}

// MARK: GalleryNameDisplaySection
private struct GalleryNameDisplaySection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let galleryNameDescription = "Many galleries have both an English/Romanized title and a title in Japanese script. Which gallery name would you like as default?"
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Gallery Name Display").newlineBold()
            + Text(galleryNameDescription)
        ) {
            HStack {
                Text("Gallery name")
                Spacer()
                Picker(selection: $config.galleryName) {
                    ForEach(GalleryName.allCases) { name in
                        Text(name.value).tag(name)
                    }
                } label: {
                    Text(config.galleryName.value)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ArchiverSettingsSection
private struct ArchiverSettingsSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let archiverSettingsDescription = "The default behavior for the Archiver is to confirm the cost and selection for original or resampled archive, then present a link that can be clicked or copied elsewhere. You can change this behavior here."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Archiver Settings").newlineBold()
            + Text(archiverSettingsDescription)
        ) {
            Text("Archiver behavior")
            Picker(selection: $config.archiverBehavior) {
                ForEach(ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value).tag(behavior)
                }
            } label: {
                Text(config.archiverBehavior.value)
            }
            .pickerStyle(.menu)
        }
        .textCase(nil)
    }
}

// MARK: FrontPageSettingsSection
private struct FrontPageSettingsSection: View {
    @Binding private var config: EhConfig

    private var categoryBindings: [Binding<Bool>] {
        [
            $config.doujinshiDisabled,
            $config.mangaDisabled,
            $config.artistCGDisabled,
            $config.gameCGDisabled,
            $config.westernDisabled,
            $config.nonHDisabled,
            $config.imageSetDisabled,
            $config.cosplayDisabled,
            $config.asianPornDisabled,
            $config.miscDisabled
        ]
    }

    // swiftlint:disable line_length
    private let displayModeDescription = "Which display mode would you like to use on the front and search pages?"
    private let categoriesDescription = "What categories would you like to show by default on the front page and in searches?"
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Front Page Settings").newlineBold()
            + Text(displayModeDescription)
        ) {
            HStack {
                Text("Display mode")
                Spacer()
                Picker(selection: $config.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.value).tag(mode)
                    }
                } label: {
                    Text(config.displayMode.value)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(categoriesDescription)) {
            CategoryView(bindings: categoryBindings)
        }
        .textCase(nil)
    }
}

// MARK: FavoritesSection
private struct FavoritesSection: View {
    @Binding private var config: EhConfig

    private var tuples: [(Category, Binding<String>)] {
        [
            (.misc, $config.favoriteName0),
            (.doujinshi, $config.favoriteName1),
            (.manga, $config.favoriteName2),
            (.artistCG, $config.favoriteName3),
            (.gameCG, $config.favoriteName4),
            (.western, $config.favoriteName5),
            (.nonH, $config.favoriteName6),
            (.imageSet, $config.favoriteName7),
            (.cosplay, $config.favoriteName8),
            (.asianPorn, $config.favoriteName9)
        ]
    }

    // swiftlint:disable line_length
    private let favoriteNamesDescription = "Here you can choose and rename your favorite categories."
    private let sortOrderDescription = "You can also select your default sort order for galleries on your favorites page. Note that favorites added prior to the March 2016 revamp did not store a timestamp, and will use the gallery posted time regardless of this setting."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Favorites").newlineBold()
            + Text(favoriteNamesDescription)
        ) {
            ForEach(tuples, id: \.0) { category, nameBinding in
                HStack(spacing: 30) {
                    Circle().foregroundColor(category.color).frame(width: 10)
                    SettingTextField(
                        text: nameBinding, width: nil,
                        alignment: .leading, background: .clear
                    )
                }
                .padding(.leading)
            }
        }
        .textCase(nil)
        Section(header: Text(sortOrderDescription)) {
            HStack {
                Text("Sort order")
                Spacer()
                Picker(selection: $config.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.value).tag(order)
                    }
                } label: {
                    Text(config.sortOrder.value)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: RatingsSection
private struct RatingsSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let ratingsDescription = "By default, galleries that you have rated will appear with red stars for ratings of 2 stars and below, green for ratings between 2.5 and 4 stars, and blue for ratings of 4.5 or 5 stars. You can customize this by entering your desired color combination below. Each letter represents one star. The default RRGGB means R(ed) for the first and second star, G(reen) for the third and fourth, and B(lue) for the fifth. You can also use (Y)ellow for the normal stars. Any five-letter R/G/B/Y combo works."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Ratings").newlineBold()
            + Text(ratingsDescription)
        ) {
            HStack {
                Text("Ratings color")
                Spacer()
                SettingTextField(
                    text: $config.ratingsColor,
                    promptText: "RRGGB", width: 80
                )
            }
        }
        .textCase(nil)
    }
}

// MARK: TagNamespacesSection
private struct TagNamespacesSection: View {
    @Binding private var config: EhConfig

    private var tuples: [(String, Binding<Bool>)] {
        [
            ("reclass", $config.reclassExcluded),
            ("language", $config.languageExcluded),
            ("parody", $config.parodyExcluded),
            ("character", $config.characterExcluded),
            ("group", $config.groupExcluded),
            ("artist", $config.artistExcluded),
            ("male", $config.maleExcluded),
            ("female", $config.femaleExcluded)
        ]
    }

    // swiftlint:disable line_length
    private let tagNamespacesDescription = "If you want to exclude certain namespaces from a default tag search, you can check those below. Note that this does not prevent galleries with tags in these namespaces from appearing, it just makes it so that when searching tags, it will forego those namespaces."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Tag Namespaces").newlineBold()
            + Text(tagNamespacesDescription)
        ) {
            ExcludeView(tuples: tuples)
        }
        .textCase(nil)
    }
}

// MARK: TagFilteringThresholdSection
private struct TagFilteringThresholdSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let tagFilteringThresholdDescription = "You can soft filter tags by adding them to My Tags with a negative weight. If a gallery has tags that add up to weight below this value, it is filtered from view. This threshold can be set between 0 and -9999."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Tag Filtering Threshold").newlineBold()
            + Text(tagFilteringThresholdDescription)
        ) {
            ValuePicker(
                title: "Threshold",
                value: $config.tagFilteringThreshold,
                range: -9999...0
            )
        }
        .textCase(nil)
    }
}

// MARK: TagWatchingThresholdSection
private struct TagWatchingThresholdSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let tagWatchingThresholdDescription = "Recently uploaded galleries will be included on the watched screen if it has at least one watched tag with positive weight, and the sum of weights on its watched tags add up to this value or higher. This threshold can be set between 0 and 9999."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Tag Watching Threshold").newlineBold()
            + Text(tagWatchingThresholdDescription)
        ) {
            ValuePicker(
                title: "Threshold",
                value: $config.tagWatchingThreshold,
                range: 0...9999
            )
        }
        .textCase(nil)
    }
}

// MARK: ExcludedUploadersSection
private struct ExcludedUploadersSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private var excludedUploadersDescriptionText: Text {
        Text("If you wish to hide galleries from certain uploaders from the gallery list and searches, add them below. Put one username per line. Note that galleries from these uploaders will never appear regardless of your search query.\nYou are currently using ")
        + Text("**\(config.excludedUploaders.lineCount) / 1000** exclusion slots.")
    }
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Excluded Uploaders").newlineBold()
            + excludedUploadersDescriptionText
        ) {
            TextEditor(text: $config.excludedUploaders)
                .frame(maxHeight: windowH * 0.3)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
        .textCase(nil)
    }
}

// MARK: SearchResultCountSection
private struct SearchResultCountSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let searchResultCountDescription = "How many results would you like per page for the index/search page and torrent search pages? (Hath Perk: Paging Enlargement Required)"
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Search Result Count").newlineBold()
            + Text(searchResultCountDescription)
        ) {
            HStack {
                Text("Results per page")
                Spacer()
                Picker(selection: $config.searchResultCount) {
                    ForEach(SearchResultCount.allCases) { count in
                        Text(String(count.value) + " results").tag(count)
                    }
                } label: {
                    Text(String(config.searchResultCount.value) + " results")
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
    }
}

// MARK: ThumbnailSettingsSection
private struct ThumbnailSettingsSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let thumbnailLoadTimingDescription = "How would you like the mouse-over thumbnails on the front page to load when using List Mode?\n"
    private let thumbnailConfigurationDescription = "You can set a default thumbnail configuration for all galleries you visit."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Thumbnail Settings").newlineBold()
            + Text(
                thumbnailLoadTimingDescription
                + config.thumbnailLoadTiming.description
            )
        ) {
            HStack {
                Text("Thumbnail load timing")
                Spacer()
                Picker(selection: $config.thumbnailLoadTiming) {
                    ForEach(ThumbnailLoadTiming.allCases) { timing in
                        Text(timing.value).tag(timing)
                    }
                } label: {
                    Text(config.thumbnailLoadTiming.value)
                }
                .pickerStyle(.menu)
            }
        }
        .textCase(nil)
        Section(header: Text(thumbnailConfigurationDescription)) {
            HStack {
                Text("Size")
                Spacer()
                Picker(selection: $config.thumbnailConfigSize) {
                    ForEach(ThumbnailSize.allCases) { size in
                        Text(size.value).tag(size)
                    }
                } label: {
                    Text(config.thumbnailConfigSize.value)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            HStack {
                Text("Rows")
                Spacer()
                Picker(selection: $config.thumbnailConfigRows) {
                    ForEach(ThumbnailRows.allCases) { row in
                        Text(row.value).tag(row)
                    }
                } label: {
                    Text(config.thumbnailConfigRows.value)
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
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let thumbnailScalingDescription = "Thumbnails on the thumbnail and extended gallery list views can be scaled to a custom value between 75% and 150%."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Thumbnail Scaling").newlineBold()
            + Text(thumbnailScalingDescription)
        ) {
            ValuePicker(
                title: "Scale factor",
                value: $config.thumbnailScaleFactor,
                range: 75...150,
                unit: "%"
            )
        }
        .textCase(nil)
    }
}

// MARK: ViewportOverrideSection
private struct ViewportOverrideSection: View {
    @Binding private var config: EhConfig

    // swiftlint:disable line_length
    private let viewportOverrideDescription = "Allows you to override the virtual width of the site for mobile devices. This is normally determined automatically by your device based on its DPI. Sensible values at 100% thumbnail scale are between 640 and 1400."
    // swiftlint:enable line_length

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        Section(
            header: Text("Viewport Override").newlineBold()
            + Text(viewportOverrideDescription)
        ) {
            ValuePicker(
                title: "Virtual width",
                value: $config.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
        }
        .textCase(nil)
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
                Text(title)
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

    init(tuples: [(String, Binding<Bool>)]) {
        self.tuples = tuples
    }

    var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.0) { text, isExcluded in
                ZStack {
                    Text(text).bold()
                        .opacity(isExcluded.wrappedValue ? 0 : 1)
                    ZStack {
                        Text(text)
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

struct EhConfigView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EhConfigView()
        }
    }
}

// MARK: AnySection
private struct AnySection: View {
    @Binding private var config: EhConfig

    init(config: Binding<EhConfig>) {
        _config = config
    }

    var body: some View {
        EmptyView()
    }
}

// Workaround to solve footers freezing issue
private extension Text {
    func newlineBold() -> Text {
        bold() + Text("\n")
    }
}
