//
//  EhSetting.swift
//  EhSetting
//
//  Created by 荒木辰造 on R 3/08/08.
//

// MARK: EhSetting
struct EhSetting: Equatable {
    // swiftlint:disable line_length
    static let empty: Self = .init(ehProfiles: [.empty], capableLoadThroughHathSetting: .anyClient, capableImageResolution: .auto, capableSearchResultCount: .fifty, capableThumbnailConfigSize: .normal, capableThumbnailConfigRowCount: .forty, loadThroughHathSetting: .anyClient, browsingCountry: .autoDetect, literalBrowsingCountry: "", imageResolution: .auto, imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default, archiverBehavior: .autoSelectOriginalAutoStart, displayMode: .compact, disabledCategories: Array(repeating: false, count: 10), favoriteNames: Array(repeating: "", count: 10), favoritesSortOrder: .favoritedTime, ratingsColor: "", excludedNamespaces: Array(repeating: false, count: 11), tagFilteringThreshold: 0, tagWatchingThreshold: 0, excludedLanguages: Array(repeating: false, count: 50), excludedUploaders: "", searchResultCount: .fifty, thumbnailLoadTiming: .onPageLoad, thumbnailConfigSize: .normal, thumbnailConfigRows: .ten, thumbnailScaleFactor: 0, viewportVirtualWidth: 0, commentsSortOrder: .recent, commentVotesShowTiming: .always, tagsSortOrder: .alphabetical, galleryShowPageNumbers: true, hathLocalNetworkHost: "")
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

    var capableLoadThroughHathSetting: LoadThroughHathSetting
    var capableImageResolution: ImageResolution
    var capableSearchResultCount: SearchResultCount
    var capableThumbnailConfigSize: ThumbnailSize
    var capableThumbnailConfigRowCount: ThumbnailRowCount

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
    var capableThumbnailConfigSizes: [ThumbnailSize] {
        ThumbnailSize.allCases.filter { size in
            size <= capableThumbnailConfigSize
        }
    }
    var capableThumbnailConfigRowCounts: [ThumbnailRowCount] {
        ThumbnailRowCount.allCases.filter { row in
            row <= capableThumbnailConfigRowCount
        }
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
    var disabledCategories: [Bool]
    var favoriteNames: [String]
    var favoritesSortOrder: FavoritesSortOrder
    var ratingsColor: String
    var excludedNamespaces: [Bool]
    var tagFilteringThreshold: Float
    var tagWatchingThreshold: Float
    var excludedLanguages: [Bool]
    var excludedUploaders: String
    var searchResultCount: SearchResultCount
    var thumbnailLoadTiming: ThumbnailLoadTiming
    var thumbnailConfigSize: ThumbnailSize
    var thumbnailConfigRows: ThumbnailRowCount
    var thumbnailScaleFactor: Float
    var viewportVirtualWidth: Float
    var commentsSortOrder: CommentsSortOrder
    var commentVotesShowTiming: CommentVotesShowTiming
    var tagsSortOrder: TagsSortOrder
    var galleryShowPageNumbers: Bool
    var hathLocalNetworkHost: String
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
        case no
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
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueAnyClient()
        case .defaultPortOnly:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueDefaultPortOnly()
        case .no:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingValueNo()
        }
    }
    var description: String {
        switch self {
        case .anyClient:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionAnyClient()
        case .defaultPortOnly:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionDefaultPortOnly()
        case .no:
            return R.string.localizable.enumEhSettingLoadThroughHathSettingDescriptionNo()
        }
    }
}

// MARK: ImageResolution
extension EhSetting {
    enum ImageResolution: Int, CaseIterable, Identifiable, Comparable {
        case auto
        case x780
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
            return R.string.localizable.enumEhSettingImageResolutionValueAuto()
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
            return R.string.localizable.enumEhSettingGalleryNameValueDefault()
        case .japanese:
            return R.string.localizable.enumEhSettingGalleryNameValueJapanese()
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
            return R.string.localizable.enumEhSettingArchiverBehaviorValueManualSelectManualStart()
        case .manualSelectAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueManualSelectAutoStart()
        case .autoSelectOriginalManualStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectOriginalManualStart()
        case .autoSelectOriginalAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectOriginalAutoStart()
        case .autoSelectResampleManualStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectResampleManualStart()
        case .autoSelectResampleAutoStart:
            return R.string.localizable.enumEhSettingArchiverBehaviorValueAutoSelectResampleAutoStart()
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
            return R.string.localizable.enumEhSettingDisplayModeValueCompact()
        case .thumbnail:
            return R.string.localizable.enumEhSettingDisplayModeValueThumbnail()
        case .extended:
            return R.string.localizable.enumEhSettingDisplayModeValueExtended()
        case .minimal:
            return R.string.localizable.enumEhSettingDisplayModeValueMinimal()
        case .minimalPlus:
            return R.string.localizable.enumEhSettingDisplayModeValueMinimalPlus()
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
            return R.string.localizable.enumEhSettingFavoritesSortOrderValueLastUpdateTime()
        case .favoritedTime:
            return R.string.localizable.enumEhSettingFavoritesSortOrderValueFavoritedTime()
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
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueOriginal()
        case .translated:
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueTranslated()
        case .rewrite:
            return R.string.localizable.enumEhSettingExcludedLanguagesCategoryValueRewrite()
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

// MARK: ThumbnailLoadTiming
extension EhSetting {
    enum ThumbnailLoadTiming: Int, CaseIterable, Identifiable {
        case onMouseOver
        case onPageLoad
    }
}
extension EhSetting.ThumbnailLoadTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onMouseOver:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingValueOnMouseOver()
        case .onPageLoad:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingValueOnPageLoad()
        }
    }
    var description: String {
        switch self {
        case .onMouseOver:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingDescriptionOnMouseOver()
        case .onPageLoad:
            return R.string.localizable.enumEhSettingThumbnailLoadTimingDescriptionOnPageLoad()
        }
    }
}

// MARK: ThumbnailSize
extension EhSetting {
    enum ThumbnailSize: Int, CaseIterable, Identifiable, Comparable {
        case normal
        case large
    }
}
extension EhSetting.ThumbnailSize {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .normal:
            return R.string.localizable.enumEhSettingThumbnailSizeValueNormal()
        case .large:
            return R.string.localizable.enumEhSettingThumbnailSizeValueLarge()
        }
    }
}

// MARK: ThumbnailRowCount
extension EhSetting {
    enum ThumbnailRowCount: Int, CaseIterable, Identifiable, Comparable {
        case four
        case ten
        case twenty
        case forty
    }
}
extension EhSetting.ThumbnailRowCount {
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

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

// MARK: CommentsSortOrder
extension EhSetting {
    enum CommentsSortOrder: Int, CaseIterable, Identifiable {
        case oldest
        case recent
        case highestScore
    }
}
extension EhSetting.CommentsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .oldest:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueOldest()
        case .recent:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueRecent()
        case .highestScore:
            return R.string.localizable.enumEhSettingCommentsSortOrderValueHighestScore()
        }
    }
}

// MARK: CommentVotesShowTiming
extension EhSetting {
    enum CommentVotesShowTiming: Int, CaseIterable, Identifiable {
        case onHoverOrClick
        case always
    }
}
extension EhSetting.CommentVotesShowTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onHoverOrClick:
            return R.string.localizable.enumEhSettingCommentsVotesShowTimingValueOnHoverOrClick()
        case .always:
            return R.string.localizable.enumEhSettingCommentsVotesShowTimingValueAlways()
        }
    }
}

// MARK: TagsSortOrder
extension EhSetting {
    enum TagsSortOrder: Int, CaseIterable, Identifiable {
        case alphabetical
        case tagPower
    }
}
extension EhSetting.TagsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alphabetical:
            return R.string.localizable.enumEhSettingTagsSortOrderValueAlphabetical()
        case .tagPower:
            return R.string.localizable.enumEhSettingTagsSortOrderValueTagPower()
        }
    }
}

// MARK: MultiplePageViewerStyle
extension EhSetting {
    enum MultiplePageViewerStyle: Int, CaseIterable, Identifiable {
        case alignLeftScaleIfOverWidth
        case alignCenterScaleIfOverWidth
        case alignCenterAlwaysScale
    }
}
extension EhSetting.MultiplePageViewerStyle {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alignLeftScaleIfOverWidth:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignLeftScaleIfOverWidth()
        case .alignCenterScaleIfOverWidth:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignCenterScaleIfOverWidth()
        case .alignCenterAlwaysScale:
            return R.string.localizable.enumEhSettingMultiplePageViewerStyleValueAlignCenterAlwaysScale()
        }
    }
}
