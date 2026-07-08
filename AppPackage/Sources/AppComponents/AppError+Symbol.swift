import AppModels
import SFSafeSymbols

extension AppError {
    public var symbol: SFSymbol {
        switch self {
        case .ipBanned:
            return .networkBadgeShieldHalfFilled
        case .copyrightClaim, .expunged:
            return .trashCircleFill
        case .networkingFailed:
            return .wifiExclamationmark
        case .parseFailed:
            return .rectangleAndTextMagnifyingglass
        case .quotaExceeded:
            return .gaugeWithDotsNeedle67percent
        case .authenticationRequired:
            return .lockCircleFill
        case .fileOperationFailed:
            return .folderFill
        case .notFound, .unknown, .noUpdates, .webImageFailed:
            return .questionmarkCircleFill
        }
    }
}
