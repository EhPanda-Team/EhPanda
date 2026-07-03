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
            return L10n.Localizable.CommentsSortOrder.oldest
        case .recent:
            return L10n.Localizable.CommentsSortOrder.recent
        case .highestScore:
            return L10n.Localizable.CommentsSortOrder.highestScore
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
            return L10n.Localizable.CommentsVotesShowTiming.onHoverOrClick
        case .always:
            return L10n.Localizable.CommentsVotesShowTiming.always
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
            return L10n.Localizable.TagsSortOrder.alphabetical
        case .tagPower:
            return L10n.Localizable.TagsSortOrder.tagPower
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
            return L10n.Localizable.MultiplePageViewerStyle.alignLeftScaleIfOverWidth
        case .alignCenterScaleIfOverWidth:
            return L10n.Localizable.MultiplePageViewerStyle.alignCenterScaleIfOverWidth
        case .alignCenterAlwaysScale:
            return L10n.Localizable.MultiplePageViewerStyle.alignCenterAlwaysScale
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
        case .none: L10n.Localizable.GalleryPageNumbering.none
        case .pageNumberOnly: L10n.Localizable.GalleryPageNumbering.pageNumberOnly
        case .pageNumberAndName: L10n.Localizable.GalleryPageNumbering.pageNumberAndName
        }
    }
}
