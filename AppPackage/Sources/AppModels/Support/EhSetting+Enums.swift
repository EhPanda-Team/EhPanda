import Resources

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

    public var value: String {
        switch self {
        case .oldest:
            return String(localized: .commentsSortOrderOldest)
        case .recent:
            return String(localized: .commentsSortOrderRecent)
        case .highestScore:
            return String(localized: .commentsSortOrderHighestScore)
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

    public var value: String {
        switch self {
        case .onHoverOrClick:
            return String(localized: .commentsVotesShowTimingOnHoverOrClick)
        case .always:
            return String(localized: .commentsVotesShowTimingAlways)
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

    public var value: String {
        switch self {
        case .alphabetical:
            return String(localized: .tagsSortOrderAlphabetical)
        case .tagPower:
            return String(localized: .tagsSortOrderTagPower)
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

    public var value: String {
        switch self {
        case .alignLeftScaleIfOverWidth:
            return String(localized: .multiplePageViewerStyleAlignLeftScaleIfOverWidth)
        case .alignCenterScaleIfOverWidth:
            return String(localized: .multiplePageViewerStyleAlignCenterScaleIfOverWidth)
        case .alignCenterAlwaysScale:
            return String(localized: .multiplePageViewerStyleAlignCenterAlwaysScale)
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

    public var value: String {
        switch self {
        case .none: String(localized: .galleryPageNumberingNone)
        case .pageNumberOnly: String(localized: .galleryPageNumberingPageNumberOnly)
        case .pageNumberAndName: String(localized: .galleryPageNumberingPageNumberAndName)
        }
    }
}
