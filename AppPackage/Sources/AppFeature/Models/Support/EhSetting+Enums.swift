import Resources

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
            return L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.onHoverOrClick
        case .always:
            return L10n.Localizable.Enum.EhSetting.CommentsVotesShowTiming.Value.always
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
            return L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.alphabetical
        case .tagPower:
            return L10n.Localizable.Enum.EhSetting.TagsSortOrder.Value.tagPower
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
    enum GalleryPageNumbering: Int, CaseIterable, Identifiable {
        case none
        case pageNumberOnly
        case pageNumberAndName
    }
}
extension EhSetting.GalleryPageNumbering {
    var id: Int { rawValue }

    var value: String {
        switch self {
        case .none: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.none
        case .pageNumberOnly: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberOnly
        case .pageNumberAndName: L10n.Localizable.Enum.EhSetting.GalleryPageNumbering.Value.pageNumberAndName
        }
    }
}
