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
            return String(localized: .thumbnailLoadTimingOnMouseOver)
        case .onPageLoad:
            return String(localized: .thumbnailLoadTimingOnPageLoad)
        }
    }
    public var description: String {
        switch self {
        case .onMouseOver:
            return String(localized: .thumbnailLoadTimingOnMouseOverDescription)
        case .onPageLoad:
            return String(localized: .thumbnailLoadTimingOnPageLoadDescription)
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
            return String(localized: .thumbnailSizeNormal)
        case .large:
            return String(localized: .thumbnailSizeLarge)
        case .small:
            return String(localized: .thumbnailSizeSmall)
        case .auto:
            return String(localized: .thumbnailSizeAuto)
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
