//
//  EhProfile.swift
//  EhProfile
//
//  Created by 荒木辰造 on 2021/08/08.
//

// MARK: EhProfile
struct EhProfile {
    // swiftlint:disable line_length
    static let empty = EhProfile(capableImageResolution: .x780, capableSearchResultCount: .twentyFive, capableThumbnailConfigSize: .normal, capableThumbnailConfigRows: .twenty, loadThroughHathSetting: .anyClient, imageResolution: .auto, imageSizeWidth: 0, imageSizeHeight: 0, galleryName: .default, archiverBehavior: .manualSelectManualStart, displayMode: .compact, doujinshiDisabled: false, mangaDisabled: false, artistCGDisabled: false, gameCGDisabled: false, westernDisabled: false, nonHDisabled: false, imageSetDisabled: false, cosplayDisabled: false, asianPornDisabled: false, miscDisabled: false, favoriteName0: "Favorites 0", favoriteName1: "Favorites 1", favoriteName2: "Favorites 2", favoriteName3: "Favorites 3", favoriteName4: "Favorites 4", favoriteName5: "Favorites 5", favoriteName6: "Favorites 6", favoriteName7: "Favorites 7", favoriteName8: "Favorites 8", favoriteName9: "Favorites 9", favoritesSortOrder: .favoritedTime, ratingsColor: "", reclassExcluded: false, languageExcluded: false, parodyExcluded: false, characterExcluded: false, groupExcluded: false, artistExcluded: false, maleExcluded: false, femaleExcluded: false, tagFilteringThreshold: 0, tagWatchingThreshold: 0, excludedUploaders: "", searchResultCount: .twentyFive, thumbnailLoadTiming: .onMouseOver, thumbnailConfigSize: .normal, thumbnailConfigRows: .four, thumbnailScaleFactor: 100, viewportVirtualWidth: 0, commentsSortOrder: .oldest, commentVotesShowTiming: .onHoverOrClick, tagsSortOrder: .alphabetical, galleryShowPageNumbers: false, hathLocalNetworkHost: ""
    )
    // swiftlint:enable line_length

    var capableImageResolution: EhProfileImageResolution
    var capableSearchResultCount: EhProfileSearchResultCount
    var capableThumbnailConfigSize: EhProfileThumbnailSize
    var capableThumbnailConfigRows: EhProfileThumbnailRows

    var loadThroughHathSetting: EhProfileLoadThroughHathSetting
    var imageResolution: EhProfileImageResolution
    var imageSizeWidth: Float
    var imageSizeHeight: Float
    var galleryName: EhProfileGalleryName
    var archiverBehavior: EhProfileArchiverBehavior
    var displayMode: EhProfileDisplayMode

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

    var favoritesSortOrder: EhProfileFavoritesSortOrder
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
    var searchResultCount: EhProfileSearchResultCount
    var thumbnailLoadTiming: EhProfileThumbnailLoadTiming
    var thumbnailConfigSize: EhProfileThumbnailSize
    var thumbnailConfigRows: EhProfileThumbnailRows
    var thumbnailScaleFactor: Float
    var viewportVirtualWidth: Float
    var commentsSortOrder: EhProfileCommentsSortOrder
    var commentVotesShowTiming: EhProfileCommentVotesShowTiming
    var tagsSortOrder: EhProfileTagsSortOrder
    var galleryShowPageNumbers: Bool
    var hathLocalNetworkHost: String
    var useOriginalImages: Bool?
    var useMultiplePageViewer: Bool?
    var multiplePageViewerStyle: EhProfileMultiplePageViewerStyle?
    var multiplePageViewerShowThumbnailPane: Bool?
}

// MARK: LoadThroughHathSetting
enum EhProfileLoadThroughHathSetting: Int, CaseIterable, Identifiable {
    case anyClient
    case defaultPortOnly
    case no
}
extension EhProfileLoadThroughHathSetting {
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

// MARK: ImageResolution
enum EhProfileImageResolution: Int, CaseIterable, Identifiable, Comparable {
    case auto
    case x780
    case x980
    case x1280
    case x1600
    case x2400
}
extension EhProfileImageResolution {
    var id: Int { rawValue }
    static func < (
        lhs: EhProfileImageResolution,
        rhs: EhProfileImageResolution
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

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

// MARK: GalleryName
enum EhProfileGalleryName: Int, CaseIterable, Identifiable {
    case `default`
    case japanese
}
extension EhProfileGalleryName {
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

// MARK: ArchiverBehavior
enum EhProfileArchiverBehavior: Int, CaseIterable, Identifiable {
    case manualSelectManualStart
    case manualSelectAutoStart
    case autoSelectOriginalManualStart
    case autoSelectOriginalAutoStart
    case autoSelectResampleManualStart
    case autoSelectResampleAutoStart
}
extension EhProfileArchiverBehavior {
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

// MARK: DisplayMode
enum EhProfileDisplayMode: Int, CaseIterable, Identifiable {
    case compact
    case thumbnail
    case extended
    case minimal
    case minimalPlus
}
extension EhProfileDisplayMode {
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

// MARK: FavoritesSortOrder
enum EhProfileFavoritesSortOrder: Int, CaseIterable, Identifiable {
    case lastUpdateTime
    case favoritedTime
}
extension EhProfileFavoritesSortOrder {
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

// MARK: SearchResultCount
enum EhProfileSearchResultCount: Int, CaseIterable, Identifiable, Comparable {
    case twentyFive
    case fifty
    case oneHundred
    case twoHundred
}
extension EhProfileSearchResultCount {
    var id: Int { rawValue }
    static func < (
        lhs: EhProfileSearchResultCount,
        rhs: EhProfileSearchResultCount
    ) -> Bool {
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
enum EhProfileThumbnailLoadTiming: Int, CaseIterable, Identifiable {
    case onMouseOver
    case onPageLoad
}
extension EhProfileThumbnailLoadTiming {
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

// MARK: ThumbnailSize
enum EhProfileThumbnailSize: Int, CaseIterable, Identifiable, Comparable {
    case normal
    case large
}
extension EhProfileThumbnailSize {
    var id: Int { rawValue }
    static func < (
        lhs: EhProfileThumbnailSize,
        rhs: EhProfileThumbnailSize
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var value: String {
        switch self {
        case .normal:
            return "Normal"
        case .large:
            return "Large"
        }
    }
}

// MARK: ThumbnailRows
enum EhProfileThumbnailRows: Int, CaseIterable, Identifiable, Comparable {
    case four
    case ten
    case twenty
    case forty
}
extension EhProfileThumbnailRows {
    var id: Int { rawValue }
    static func < (
        lhs: EhProfileThumbnailRows,
        rhs: EhProfileThumbnailRows
    ) -> Bool {
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
enum EhProfileCommentsSortOrder: Int, CaseIterable, Identifiable {
    case oldest
    case recent
    case highestScore
}
extension EhProfileCommentsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .oldest:
            return "Oldest comments first"
        case .recent:
            return "Recent comments first"
        case .highestScore:
            return "By highest score"
        }
    }
}

// MARK: CommentVotesShowTiming
enum EhProfileCommentVotesShowTiming: Int, CaseIterable, Identifiable {
    case onHoverOrClick
    case always
}
extension EhProfileCommentVotesShowTiming {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .onHoverOrClick:
            return "On score hover or click"
        case .always:
            return "Always"
        }
    }
}

// MARK: TagsSortOrder
enum EhProfileTagsSortOrder: Int, CaseIterable, Identifiable {
    case alphabetical
    case tagPower
}
extension EhProfileTagsSortOrder {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alphabetical:
            return "Alphabetical"
        case .tagPower:
            return "By tag power"
        }
    }
}

// MARK: MultiplePageViewerStyle
enum EhProfileMultiplePageViewerStyle: Int, CaseIterable, Identifiable {
    case alignLeftScaleIfOverWidth
    case alignCenterScaleIfOverWidth
    case alignCenterAlwaysScale
}
extension EhProfileMultiplePageViewerStyle {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .alignLeftScaleIfOverWidth:
            return "Align left, scale if overwidth"
        case .alignCenterScaleIfOverWidth:
            return "Align center, scale if overwidth"
        case .alignCenterAlwaysScale:
            return "Align center, always scale"
        }
    }
}

// MARK: MultiplePageViewerThumbnailPane
enum EhProfileMultiplePageViewerThumbnailPane: Int, CaseIterable, Identifiable {
    case show
    case hide
}
extension EhProfileMultiplePageViewerThumbnailPane {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .show:
            return "Show"
        case .hide:
            return "Hide"
        }
    }
}
