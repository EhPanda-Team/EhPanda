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
            return L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.oldest
        case .recent:
            return L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.recent
        case .highestScore:
            return L10n.Localizable.Enum.EhSetting.CommentsSortOrder.Value.highestScore
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
            return L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.onHoverOrClick
        case .always:
            return L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.always
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
            return L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.alphabetical
        case .tagPower:
            return L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.tagPower
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
            return L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignLeftScaleIfOverWidth
        case .alignCenterScaleIfOverWidth:
            return L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignCenterScaleIfOverWidth
        case .alignCenterAlwaysScale:
            return L10n.Localizable.Enum.EhSetting.MultiplePageViewerStyle.Value.alignCenterAlwaysScale
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
        case .none: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.none
        case .pageNumberOnly: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberOnly
        case .pageNumberAndName: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberAndName
        }
    }
}
