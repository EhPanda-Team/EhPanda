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
            return L10n.Localizable.ThumbnailLoadTiming.onMouseOver
        case .onPageLoad:
            return L10n.Localizable.ThumbnailLoadTiming.onPageLoad
        }
    }
    public var description: String {
        switch self {
        case .onMouseOver:
            return L10n.Localizable.ThumbnailLoadTiming.onMouseOverDescription
        case .onPageLoad:
            return L10n.Localizable.ThumbnailLoadTiming.onPageLoadDescription
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
            return L10n.Localizable.ThumbnailSize.normal
        case .large:
            return L10n.Localizable.ThumbnailSize.large
        case .small:
            return L10n.Localizable.ThumbnailSize.small
        case .auto:
            return L10n.Localizable.ThumbnailSize.auto
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
