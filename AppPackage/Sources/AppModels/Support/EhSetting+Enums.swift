import Foundation
import Resources

// MARK: HahRegion
extension EhSetting {
    /// Raw values are the site's own region codes: e-hentai reuses one ISO country code
    /// per region (e.g. `JP` = Asia, `NL` = Europe), likely for compatibility with the
    /// country-based `co` field this setting replaced.
    public enum HahRegion: String, CaseIterable, Identifiable, Sendable {
        case autoDetect = ""
        case europe = "NL"
        case northAmerica = "US"
        case southAmerica = "BR"
        case asia = "JP"
        case oceania = "AU"
        case chineseDominion = "CN"
    }
}
extension EhSetting.HahRegion {
    public var id: String { rawValue }

    public var name: LocalizedStringResource {
        switch self {
        case .autoDetect: .hahRegionAutoDetect
        case .europe: .hahRegionEurope
        case .northAmerica: .hahRegionNorthAmerica
        case .southAmerica: .hahRegionSouthAmerica
        case .asia: .hahRegionAsia
        case .oceania: .hahRegionOceania
        case .chineseDominion: .hahRegionChineseDominion
        }
    }

    /// The site's English display name, used to match the literal region name
    /// scraped from the settings page against a case.
    public var englishName: String {
        switch self {
        case .autoDetect: "Auto-Detect"
        case .europe: "Europe"
        case .northAmerica: "North America"
        case .southAmerica: "South America"
        case .asia: "Asia"
        case .oceania: "Oceania"
        case .chineseDominion: "Chinese Dominion"
        }
    }
}

// MARK: CommentsSortOrder
extension EhSetting {
    public enum CommentsSortOrder: Int, CaseIterable, Identifiable, Sendable {
        case oldest
        case recent
        case highestScore
    }
}
extension EhSetting.CommentsSortOrder {
    public var id: Int { rawValue }

    public var value: LocalizedStringResource {
        switch self {
        case .oldest:
            return .commentsSortOrderOldest
        case .recent:
            return .commentsSortOrderRecent
        case .highestScore:
            return .commentsSortOrderHighestScore
        }
    }
}

// MARK: CommentVotesShowTiming
extension EhSetting {
    public enum CommentVotesShowTiming: Int, CaseIterable, Identifiable, Sendable {
        case onHoverOrClick
        case always
    }
}
extension EhSetting.CommentVotesShowTiming {
    public var id: Int { rawValue }

    public var value: LocalizedStringResource {
        switch self {
        case .onHoverOrClick:
            return .commentsVotesShowTimingOnHoverOrClick
        case .always:
            return .commentsVotesShowTimingAlways
        }
    }
}

// MARK: TagsSortOrder
extension EhSetting {
    public enum TagsSortOrder: Int, CaseIterable, Identifiable, Sendable {
        case alphabetical
        case tagPower
    }
}
extension EhSetting.TagsSortOrder {
    public var id: Int { rawValue }

    public var value: LocalizedStringResource {
        switch self {
        case .alphabetical:
            return .tagsSortOrderAlphabetical
        case .tagPower:
            return .tagsSortOrderTagPower
        }
    }
}

// MARK: MultiplePageViewerStyle
extension EhSetting {
    public enum MultiplePageViewerStyle: Int, CaseIterable, Identifiable, Sendable {
        case alignLeftScaleIfOverWidth
        case alignCenterScaleIfOverWidth
        case alignCenterAlwaysScale
    }
}
extension EhSetting.MultiplePageViewerStyle {
    public var id: Int { rawValue }

    public var value: LocalizedStringResource {
        switch self {
        case .alignLeftScaleIfOverWidth:
            return .multiplePageViewerStyleAlignLeftScaleIfOverWidth
        case .alignCenterScaleIfOverWidth:
            return .multiplePageViewerStyleAlignCenterScaleIfOverWidth
        case .alignCenterAlwaysScale:
            return .multiplePageViewerStyleAlignCenterAlwaysScale
        }
    }
}

// MARK: GalleryPageNumbering
extension EhSetting {
    public enum GalleryPageNumbering: Int, CaseIterable, Identifiable, Sendable {
        case none
        case pageNumberOnly
        case pageNumberAndName
    }
}
extension EhSetting.GalleryPageNumbering {
    public var id: Int { rawValue }

    public var value: LocalizedStringResource {
        switch self {
        case .none: .galleryPageNumberingNone
        case .pageNumberOnly: .galleryPageNumberingPageNumberOnly
        case .pageNumberAndName: .galleryPageNumberingPageNumberAndName
        }
    }
}
