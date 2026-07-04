import Resources

// MARK: EhSetting
public struct EhSetting: Equatable, Sendable {
    public init(
        ehProfiles: [EhProfile],
        isCapableOfCreatingNewProfile: Bool,
        capableLoadThroughHathSetting: LoadThroughHathSetting,
        capableImageResolution: ImageResolution,
        capableSearchResultCount: SearchResultCount,
        capableThumbnailConfigRowCount: ThumbnailRowCount,
        capableThumbnailConfigSizes: [ThumbnailSize],
        loadThroughHathSetting: LoadThroughHathSetting,
        browsingCountry: BrowsingCountry,
        literalBrowsingCountry: String,
        imageResolution: ImageResolution,
        imageSizeWidth: Float,
        imageSizeHeight: Float,
        galleryName: GalleryName,
        archiverBehavior: ArchiverBehavior,
        displayMode: DisplayMode,
        showSearchRangeIndicator: Bool,
        enableGalleryThumbnailSelector: Bool,
        disabledCategories: [Bool],
        favoriteCategories: [String],
        favoritesSortOrder: FavoritesSortOrder,
        ratingsColor: String,
        tagFilteringThreshold: Float,
        tagWatchingThreshold: Float,
        showFilteredRemovalCount: Bool,
        excludedLanguages: [Bool],
        excludedUploaders: String,
        searchResultCount: SearchResultCount,
        thumbnailLoadTiming: ThumbnailLoadTiming,
        thumbnailConfigSize: ThumbnailSize,
        thumbnailConfigRows: ThumbnailRowCount,
        coverScaleFactor: Float,
        viewportVirtualWidth: Float,
        commentsSortOrder: CommentsSortOrder,
        commentVotesShowTiming: CommentVotesShowTiming,
        tagsSortOrder: TagsSortOrder,
        galleryPageNumbering: GalleryPageNumbering,
        useOriginalImages: Bool? = nil,
        useMultiplePageViewer: Bool? = nil,
        multiplePageViewerStyle: MultiplePageViewerStyle? = nil,
        multiplePageViewerShowThumbnailPane: Bool? = nil
    ) {
        self.ehProfiles = ehProfiles
        self.isCapableOfCreatingNewProfile = isCapableOfCreatingNewProfile
        self.capableLoadThroughHathSetting = capableLoadThroughHathSetting
        self.capableImageResolution = capableImageResolution
        self.capableSearchResultCount = capableSearchResultCount
        self.capableThumbnailConfigRowCount = capableThumbnailConfigRowCount
        self.capableThumbnailConfigSizes = capableThumbnailConfigSizes
        self.loadThroughHathSetting = loadThroughHathSetting
        self.browsingCountry = browsingCountry
        self.literalBrowsingCountry = literalBrowsingCountry
        self.imageResolution = imageResolution
        self.imageSizeWidth = imageSizeWidth
        self.imageSizeHeight = imageSizeHeight
        self.galleryName = galleryName
        self.archiverBehavior = archiverBehavior
        self.displayMode = displayMode
        self.showSearchRangeIndicator = showSearchRangeIndicator
        self.enableGalleryThumbnailSelector = enableGalleryThumbnailSelector
        self.disabledCategories = disabledCategories
        self.favoriteCategories = favoriteCategories
        self.favoritesSortOrder = favoritesSortOrder
        self.ratingsColor = ratingsColor
        self.tagFilteringThreshold = tagFilteringThreshold
        self.tagWatchingThreshold = tagWatchingThreshold
        self.showFilteredRemovalCount = showFilteredRemovalCount
        self.excludedLanguages = excludedLanguages
        self.excludedUploaders = excludedUploaders
        self.searchResultCount = searchResultCount
        self.thumbnailLoadTiming = thumbnailLoadTiming
        self.thumbnailConfigSize = thumbnailConfigSize
        self.thumbnailConfigRows = thumbnailConfigRows
        self.coverScaleFactor = coverScaleFactor
        self.viewportVirtualWidth = viewportVirtualWidth
        self.commentsSortOrder = commentsSortOrder
        self.commentVotesShowTiming = commentVotesShowTiming
        self.tagsSortOrder = tagsSortOrder
        self.galleryPageNumbering = galleryPageNumbering
        self.useOriginalImages = useOriginalImages
        self.useMultiplePageViewer = useMultiplePageViewer
        self.multiplePageViewerStyle = multiplePageViewerStyle
        self.multiplePageViewerShowThumbnailPane = multiplePageViewerShowThumbnailPane
    }
    // swiftlint:disable line_length
    public static let empty: Self = .init(ehProfiles: [.empty], isCapableOfCreatingNewProfile: true, capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto, capableSearchResultCount: .fifty, capableThumbnailConfigRowCount: .forty, capableThumbnailConfigSizes: [], loadThroughHathSetting: .anyClient, browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto, imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default, archiverBehavior: .autoSelectOriginalAutoStart, displayMode: .compact, showSearchRangeIndicator: true, enableGalleryThumbnailSelector: false, disabledCategories: Array(repeating: false, count: 10), favoriteCategories: Array(repeating: "", count: 10), favoritesSortOrder: .favoritedTime, ratingsColor: "", tagFilteringThreshold: 0, tagWatchingThreshold: 0, showFilteredRemovalCount: true, excludedLanguages: Array(repeating: false, count: 50), excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad, thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, coverScaleFactor: 0, viewportVirtualWidth: 0, commentsSortOrder: .recent, commentVotesShowTiming: .always, tagsSortOrder: .alphabetical, galleryPageNumbering: .none)
    // swiftlint:enable line_length

    public static let categoryNames = Category.allFiltersCases.map(\.rawValue).map { value in
        value.lowercased().replacingOccurrences(of: " ", with: "")
    }
    public static let languageValues = [
        1024, 2048, 1, 1025, 2049, 10, 1034, 2058,
        20, 1044, 2068, 30, 1054, 2078, 40, 1064, 2088,
        50, 1074, 2098, 60, 1084, 2108, 70, 1094, 2118,
        80, 1104, 2128, 90, 1114, 2138, 100, 1124, 2148,
        110, 1134, 2158, 120, 1144, 2168, 130, 1154, 2178,
        254, 1278, 2302, 255, 1279, 2303
    ]

    public let ehProfiles: [EhProfile]
    public var ehpandaProfile: EhProfile? {
        ehProfiles.filter({ EhSetting.verifyEhPandaProfileName(with: $0.name) }).first
    }
    public static func verifyEhPandaProfileName(with name: String?) -> Bool {
        ["EhPanda", "EhPanda (Default)"].contains(name ?? "")
    }

    public let isCapableOfCreatingNewProfile: Bool
    public let capableLoadThroughHathSetting: LoadThroughHathSetting
    public let capableImageResolution: ImageResolution
    public let capableSearchResultCount: SearchResultCount
    public let capableThumbnailConfigRowCount: ThumbnailRowCount
    public let capableThumbnailConfigSizes: [ThumbnailSize]

    public var capableLoadThroughHathSettings: [LoadThroughHathSetting] {
        LoadThroughHathSetting.allCases.filter { setting in
            setting <= capableLoadThroughHathSetting
        }
    }
    public var capableImageResolutions: [ImageResolution] {
        ImageResolution.allCases.filter { resolution in
            resolution <= capableImageResolution
        }
    }
    public var capableSearchResultCounts: [SearchResultCount] {
        SearchResultCount.allCases.filter { count in
            count <= capableSearchResultCount
        }
    }
    public var capableThumbnailConfigRowCounts: [ThumbnailRowCount] {
        ThumbnailRowCount.allCases.filter { row in
            row <= capableThumbnailConfigRowCount
        }
    }
    public var localizedLiteralBrowsingCountry: String? {
        BrowsingCountry.allCases.first(where: { $0.englishName == literalBrowsingCountry })
            .map { String(localized: $0.name) }
    }

    public var loadThroughHathSetting: LoadThroughHathSetting
    public var browsingCountry: BrowsingCountry
    public let literalBrowsingCountry: String
    public var imageResolution: ImageResolution
    public var imageSizeWidth: Float
    public var imageSizeHeight: Float
    public var galleryName: GalleryName
    public var archiverBehavior: ArchiverBehavior
    public var displayMode: DisplayMode
    public var showSearchRangeIndicator: Bool
    public var enableGalleryThumbnailSelector: Bool
    public var disabledCategories: [Bool]
    public var favoriteCategories: [String]
    public var favoritesSortOrder: FavoritesSortOrder
    public var ratingsColor: String
    public var tagFilteringThreshold: Float
    public var tagWatchingThreshold: Float
    public var showFilteredRemovalCount: Bool
    public var excludedLanguages: [Bool]
    public var excludedUploaders: String
    public var searchResultCount: SearchResultCount
    public var thumbnailLoadTiming: ThumbnailLoadTiming
    public var thumbnailConfigSize: ThumbnailSize
    public var thumbnailConfigRows: ThumbnailRowCount
    public var coverScaleFactor: Float
    public var viewportVirtualWidth: Float
    public var commentsSortOrder: CommentsSortOrder
    public var commentVotesShowTiming: CommentVotesShowTiming
    public var tagsSortOrder: TagsSortOrder
    public var galleryPageNumbering: GalleryPageNumbering
    public var useOriginalImages: Bool?
    public var useMultiplePageViewer: Bool?
    public var multiplePageViewerStyle: MultiplePageViewerStyle?
    public var multiplePageViewerShowThumbnailPane: Bool?
}

// MARK: EhProfile
public struct EhProfile: Comparable, Identifiable, Hashable, Sendable {
    public init(
        value: Int,
        name: String,
        isSelected: Bool
    ) {
        self.value = value
        self.name = name
        self.isSelected = isSelected
    }
    public static let empty: Self = .init(
        value: 0, name: "", isSelected: true
    )
    public static func < (lhs: EhProfile, rhs: EhProfile) -> Bool {
        lhs.value < rhs.value
    }
    public var id: Int { value }

    public let value: Int
    public let name: String
    public let isSelected: Bool
    public var isDefault: Bool {
        value == 1
    }
}
public enum EhProfileAction: String, Sendable {
    case create
    case delete
    case rename
    case `default`
}

// MARK: LoadThroughHathSetting
extension EhSetting {
    public enum LoadThroughHathSetting: Int, CaseIterable, Identifiable, Comparable, Sendable {
        case anyClient
        case defaultPortOnly
        case modernNo
        case legacyNo
    }
}
extension EhSetting.LoadThroughHathSetting {
    public var id: Int { rawValue }
    public static func < (
        lhs: EhSetting.LoadThroughHathSetting,
        rhs: EhSetting.LoadThroughHathSetting
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var value: String {
        switch self {
        case .anyClient:
            return String(localized: .loadThroughHathSettingAnyClient)
        case .defaultPortOnly:
            return String(localized: .loadThroughHathSettingDefaultPortOnly)
        case .modernNo:
            return String(localized: .loadThroughHathSettingModernNo)
        case .legacyNo:
            return String(localized: .loadThroughHathSettingLegacyNo)
        }
    }
    public var description: String {
        switch self {
        case .anyClient:
            return String(localized: .loadThroughHathSettingAnyClientDescription)
        case .defaultPortOnly:
            return String(localized: .loadThroughHathSettingDefaultPortOnlyDescription)
        case .modernNo:
            return String(localized: .loadThroughHathSettingModernNoDescription)
        case .legacyNo:
            return String(localized: .loadThroughHathSettingLegacyNoDescription)
        }
    }
}

// MARK: ImageResolution
extension EhSetting {
    public enum ImageResolution: Int, CaseIterable, Identifiable, Comparable, Codable, Sendable {
        case auto
        case x780
        /// Deprecated
        case x980
        case x1280
        case x1600
        case x2400
    }
}
extension EhSetting.ImageResolution {
    public var id: Int { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var value: String {
        switch self {
        case .auto:
            return String(localized: .imageResolutionAuto)
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

// MARK: GalleryName
extension EhSetting {
    public enum GalleryName: Int, CaseIterable, Identifiable, Sendable {
        case `default`
        case japanese
    }
}
extension EhSetting.GalleryName {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .default:
            return String(localized: .galleryNameDefault)
        case .japanese:
            return String(localized: .galleryNameJapanese)
        }
    }
}

// MARK: ArchiverBehavior
extension EhSetting {
    public enum ArchiverBehavior: Int, CaseIterable, Identifiable, Sendable {
        case manualSelectManualStart
        case manualSelectAutoStart
        case autoSelectOriginalManualStart
        case autoSelectOriginalAutoStart
        case autoSelectResampleManualStart
        case autoSelectResampleAutoStart
    }
}
extension EhSetting.ArchiverBehavior {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .manualSelectManualStart:
            return String(localized: .ehSettingArchiverBehaviorManualSelectManualStart)
        case .manualSelectAutoStart:
            return String(localized: .ehSettingArchiverBehaviorManualSelectAutoStart)
        case .autoSelectOriginalManualStart:
            return String(localized: .ehSettingArchiverBehaviorAutoSelectOriginalManualStart)
        case .autoSelectOriginalAutoStart:
            return String(localized: .ehSettingArchiverBehaviorAutoSelectOriginalAutoStart)
        case .autoSelectResampleManualStart:
            return String(localized: .ehSettingArchiverBehaviorAutoSelectResampleManualStart)
        case .autoSelectResampleAutoStart:
            return String(localized: .ehSettingArchiverBehaviorAutoSelectResampleAutoStart)
        }
    }
}

// MARK: DisplayMode
extension EhSetting {
    public enum DisplayMode: Int, CaseIterable, Identifiable, Sendable {
        case compact
        case thumbnail
        case extended
        case minimal
        case minimalPlus
    }
}
extension EhSetting.DisplayMode {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .compact:
            return String(localized: .displayModeCompact)
        case .thumbnail:
            return String(localized: .displayModeThumbnail)
        case .extended:
            return String(localized: .displayModeExtended)
        case .minimal:
            return String(localized: .displayModeMinimal)
        case .minimalPlus:
            return String(localized: .displayModeMinimalPlus)
        }
    }
}

// MARK: FavoritesSortOrder
extension EhSetting {
    public enum FavoritesSortOrder: Int, CaseIterable, Identifiable, Sendable {
        case lastUpdateTime
        case favoritedTime
    }
}
extension EhSetting.FavoritesSortOrder {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .lastUpdateTime:
            return String(localized: .favoritesSortOrderLastUpdateTime)
        case .favoritedTime:
            return String(localized: .favoritesSortOrderFavoritedTime)
        }
    }
}

// MARK: ExcludedLanguagesCategory
extension EhSetting {
    public enum ExcludedLanguagesCategory: Int, Identifiable, CaseIterable, Sendable {
        case original
        case translated
        case rewrite
    }
}
extension EhSetting.ExcludedLanguagesCategory {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .original:
            return String(localized: .excludedLanguagesCategoryOriginal)
        case .translated:
            return String(localized: .excludedLanguagesCategoryTranslated)
        case .rewrite:
            return String(localized: .excludedLanguagesCategoryRewrite)
        }
    }
}

// MARK: SearchResultCount
extension EhSetting {
    public enum SearchResultCount: Int, CaseIterable, Identifiable, Comparable, Sendable {
        case twentyFive
        case fifty
        case oneHundred
        case twoHundred
    }
}
extension EhSetting.SearchResultCount {
    public var id: Int { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var value: String {
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
