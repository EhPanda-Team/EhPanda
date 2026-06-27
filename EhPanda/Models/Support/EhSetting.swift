// MARK: EhSetting
struct EhSetting: Equatable {
    // swiftlint:disable line_length
    static let empty: Self = .init(ehProfiles: [.empty], isCapableOfCreatingNewProfile: true, capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto, capableSearchResultCount: .fifty, capableThumbnailConfigRowCount: .forty, capableThumbnailConfigSizes: [], loadThroughHathSetting: .anyClient, browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto, imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default, archiverBehavior: .autoSelectOriginalAutoStart, displayMode: .compact, showSearchRangeIndicator: true, enableGalleryThumbnailSelector: false, disabledCategories: Array(repeating: false, count: 10), favoriteCategories: Array(repeating: "", count: 10), favoritesSortOrder: .favoritedTime, ratingsColor: "", tagFilteringThreshold: 0, tagWatchingThreshold: 0, showFilteredRemovalCount: true, excludedLanguages: Array(repeating: false, count: 50), excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad, thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, coverScaleFactor: 0, viewportVirtualWidth: 0, commentsSortOrder: .recent, commentVotesShowTiming: .always, tagsSortOrder: .alphabetical, galleryPageNumbering: .none)
    // swiftlint:enable line_length

    static let categoryNames = Category.allFiltersCases.map(\.rawValue).map { value in
        value.lowercased().replacingOccurrences(of: " ", with: "")
    }
    static let languageValues = [
        1024, 2048, 1, 1025, 2049, 10, 1034, 2058,
        20, 1044, 2068, 30, 1054, 2078, 40, 1064, 2088,
        50, 1074, 2098, 60, 1084, 2108, 70, 1094, 2118,
        80, 1104, 2128, 90, 1114, 2138, 100, 1124, 2148,
        110, 1134, 2158, 120, 1144, 2168, 130, 1154, 2178,
        254, 1278, 2302, 255, 1279, 2303
    ]

    let ehProfiles: [EhProfile]
    var ehpandaProfile: EhProfile? {
        ehProfiles.filter({ EhSetting.verifyEhPandaProfileName(with: $0.name) }).first
    }
    static func verifyEhPandaProfileName(with name: String?) -> Bool {
        ["EhPanda", "EhPanda (Default)"].contains(name ?? "")
    }

    let isCapableOfCreatingNewProfile: Bool
    let capableLoadThroughHathSetting: LoadThroughHathSetting
    let capableImageResolution: ImageResolution
    let capableSearchResultCount: SearchResultCount
    let capableThumbnailConfigRowCount: ThumbnailRowCount
    let capableThumbnailConfigSizes: [ThumbnailSize]

    var capableLoadThroughHathSettings: [LoadThroughHathSetting] {
        LoadThroughHathSetting.allCases.filter { setting in
            setting <= capableLoadThroughHathSetting
        }
    }
    var capableImageResolutions: [ImageResolution] {
        ImageResolution.allCases.filter { resolution in
            resolution <= capableImageResolution
        }
    }
    var capableSearchResultCounts: [SearchResultCount] {
        SearchResultCount.allCases.filter { count in
            count <= capableSearchResultCount
        }
    }
    var capableThumbnailConfigRowCounts: [ThumbnailRowCount] {
        ThumbnailRowCount.allCases.filter { row in
            row <= capableThumbnailConfigRowCount
        }
    }
    var localizedLiteralBrowsingCountry: String? {
        BrowsingCountry.allCases.first(where: { $0.englishName == literalBrowsingCountry })?.name
    }

    var loadThroughHathSetting: LoadThroughHathSetting
    var browsingCountry: BrowsingCountry
    let literalBrowsingCountry: String
    var imageResolution: ImageResolution
    var imageSizeWidth: Float
    var imageSizeHeight: Float
    var galleryName: GalleryName
    var archiverBehavior: ArchiverBehavior
    var displayMode: DisplayMode
    var showSearchRangeIndicator: Bool
    var enableGalleryThumbnailSelector: Bool
    var disabledCategories: [Bool]
    var favoriteCategories: [String]
    var favoritesSortOrder: FavoritesSortOrder
    var ratingsColor: String
    var tagFilteringThreshold: Float
    var tagWatchingThreshold: Float
    var showFilteredRemovalCount: Bool
    var excludedLanguages: [Bool]
    var excludedUploaders: String
    var searchResultCount: SearchResultCount
    var thumbnailLoadTiming: ThumbnailLoadTiming
    var thumbnailConfigSize: ThumbnailSize
    var thumbnailConfigRows: ThumbnailRowCount
    var coverScaleFactor: Float
    var viewportVirtualWidth: Float
    var commentsSortOrder: CommentsSortOrder
    var commentVotesShowTiming: CommentVotesShowTiming
    var tagsSortOrder: TagsSortOrder
    var galleryPageNumbering: GalleryPageNumbering
    var useOriginalImages: Bool?
    var useMultiplePageViewer: Bool?
    var multiplePageViewerStyle: MultiplePageViewerStyle?
    var multiplePageViewerShowThumbnailPane: Bool?
}

// MARK: EhProfile
struct EhProfile: Comparable, Identifiable, Hashable {
    static let empty: Self = .init(
        value: 0, name: "", isSelected: true
    )
    static func < (lhs: EhProfile, rhs: EhProfile) -> Bool {
        lhs.value < rhs.value
    }
    var id: Int { value }

    let value: Int
    let name: String
    let isSelected: Bool
    var isDefault: Bool {
        value == 1
    }
}
enum EhProfileAction: String {
    case create
    case delete
    case rename
    case `default`
}

// MARK: LoadThroughHathSetting
extension EhSetting {
    enum LoadThroughHathSetting: Int, CaseIterable, Identifiable, Comparable {
        case anyClient
        case defaultPortOnly
        case modernNo
        case legacyNo
    }
}
extension EhSetting.LoadThroughHathSetting {
    var id: Int { rawValue }
    static func < (
        lhs: EhSetting.LoadThroughHathSetting,
        rhs: EhSetting.LoadThroughHathSetting
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .anyClient:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.anyClient
        case .defaultPortOnly:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.defaultPortOnly
        case .modernNo:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.modernNo
        case .legacyNo:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Value.legacyNo
        }
    }
    var description: String {
        switch self {
        case .anyClient:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.anyClient
        case .defaultPortOnly:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.defaultPortOnly
        case .modernNo:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.modernNo
        case .legacyNo:
            return L10n.Localizable.Enum.EhSetting.LoadThroughHathSetting.Description.legacyNo
        }
    }
}

// MARK: ImageResolution
extension EhSetting {
    enum ImageResolution: Int, CaseIterable, Identifiable, Comparable, Codable {
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
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .auto:
            return L10n.Localizable.Enum.EhSetting.ImageResolution.Value.auto
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
    enum GalleryName: Int, CaseIterable, Identifiable {
        case `default`
        case japanese
    }
}
extension EhSetting.GalleryName {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .default:
            return L10n.Localizable.Enum.EhSetting.GalleryName.Value.default
        case .japanese:
            return L10n.Localizable.Enum.EhSetting.GalleryName.Value.japanese
        }
    }
}

// MARK: ArchiverBehavior
extension EhSetting {
    enum ArchiverBehavior: Int, CaseIterable, Identifiable {
        case manualSelectManualStart
        case manualSelectAutoStart
        case autoSelectOriginalManualStart
        case autoSelectOriginalAutoStart
        case autoSelectResampleManualStart
        case autoSelectResampleAutoStart
    }
}
extension EhSetting.ArchiverBehavior {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .manualSelectManualStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.manualSelectManualStart
        case .manualSelectAutoStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.manualSelectAutoStart
        case .autoSelectOriginalManualStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectOriginalManualStart
        case .autoSelectOriginalAutoStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectOriginalAutoStart
        case .autoSelectResampleManualStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectResampleManualStart
        case .autoSelectResampleAutoStart:
            return L10n.Localizable.Enum.EhSetting.ArchiverBehavior.Value.autoSelectResampleAutoStart
        }
    }
}

// MARK: DisplayMode
extension EhSetting {
    enum DisplayMode: Int, CaseIterable, Identifiable {
        case compact
        case thumbnail
        case extended
        case minimal
        case minimalPlus
    }
}
extension EhSetting.DisplayMode {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .compact:
            return L10n.Localizable.Enum.EhSetting.DisplayMode.Value.compact
        case .thumbnail:
            return L10n.Localizable.Enum.EhSetting.DisplayMode.Value.thumbnail
        case .extended:
            return L10n.Localizable.Enum.EhSetting.DisplayMode.Value.extended
        case .minimal:
            return L10n.Localizable.Enum.EhSetting.DisplayMode.Value.minimal
        case .minimalPlus:
            return L10n.Localizable.Enum.EhSetting.DisplayMode.Value.minimalPlus
        }
    }
}

// MARK: FavoritesSortOrder
extension EhSetting {
    enum FavoritesSortOrder: Int, CaseIterable, Identifiable {
        case lastUpdateTime
        case favoritedTime
    }
}
extension EhSetting.FavoritesSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .lastUpdateTime:
            return L10n.Localizable.Enum.EhSetting.FavoritesSortOrder.Value.lastUpdateTime
        case .favoritedTime:
            return L10n.Localizable.Enum.EhSetting.FavoritesSortOrder.Value.favoritedTime
        }
    }
}

// MARK: ExcludedLanguagesCategory
extension EhSetting {
    enum ExcludedLanguagesCategory: Int, Identifiable, CaseIterable {
        case original
        case translated
        case rewrite
    }
}
extension EhSetting.ExcludedLanguagesCategory {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .original:
            return L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.original
        case .translated:
            return L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.translated
        case .rewrite:
            return L10n.Localizable.Enum.EhSetting.ExcludedLanguagesCategory.Value.rewrite
        }
    }
}

// MARK: SearchResultCount
extension EhSetting {
    enum SearchResultCount: Int, CaseIterable, Identifiable, Comparable {
        case twentyFive
        case fifty
        case oneHundred
        case twoHundred
    }
}
extension EhSetting.SearchResultCount {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

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
