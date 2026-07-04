import Foundation
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

    public var value: LocalizedStringResource {
        switch self {
        case .onMouseOver:
            return .thumbnailLoadTimingOnMouseOver
        case .onPageLoad:
            return .thumbnailLoadTimingOnPageLoad
        }
    }
    public var description: LocalizedStringResource {
        switch self {
        case .onMouseOver:
            return .thumbnailLoadTimingOnMouseOverDescription
        case .onPageLoad:
            return .thumbnailLoadTimingOnPageLoadDescription
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

    public var value: LocalizedStringResource {
        switch self {
        case .normal:
            return .thumbnailSizeNormal
        case .large:
            return .thumbnailSizeLarge
        case .small:
            return .thumbnailSizeSmall
        case .auto:
            return .thumbnailSizeAuto
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
