import Resources

// MARK: ThumbnailLoadTiming
extension EhSetting {
    public enum ThumbnailLoadTiming: Int, CaseIterable, Identifiable, Sendable {
        case onMouseOver
        case onPageLoad
    }
}
extension EhSetting.ThumbnailLoadTiming {
    public var id: Int { rawValue }

    public var value: String {
        switch self {
        case .onMouseOver:
            return L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Value.onMouseOver
        case .onPageLoad:
            return L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Value.onPageLoad
        }
    }
    public var description: String {
        switch self {
        case .onMouseOver:
            return L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Description.onMouseOver
        case .onPageLoad:
            return L10n.Localizable.Enum.EhSetting.ThumbnailLoadTiming.Description.onPageLoad
        }
    }
}

// MARK: ThumbnailSize
extension EhSetting {
    public enum ThumbnailSize: Int, CaseIterable, Identifiable, Comparable, Sendable {
        case auto
        case small
        case normal
        /// Deprecated
        case large
    }
}
extension EhSetting.ThumbnailSize {
    public var id: Int { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var value: String {
        switch self {
        case .normal:
            return L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.normal
        case .large:
            return L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.large
        case .small:
            return L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.small
        case .auto:
            return L10n.Localizable.Enum.EhSetting.ThumbnailSize.Value.auto
        }
    }
}

// MARK: ThumbnailRowCount
extension EhSetting {
    public enum ThumbnailRowCount: Int, CaseIterable, Identifiable, Comparable, Sendable {
        case four
        case ten
        case twenty
        case forty
    }
}
extension EhSetting.ThumbnailRowCount {
    public var id: Int { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var value: String {
        switch self {
        case .four: "4"
        case .ten: "8"
        case .twenty: "20"
        case .forty: "40"
        }
    }
}
