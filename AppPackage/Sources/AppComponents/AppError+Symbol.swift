public import AppModels
public import SFSafeSymbols

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
        case .imageLimitReached:
            return .gaugeWithDotsNeedle67percent
        case .loginRequired:
            return .lockCircleFill
        case .cloudflareChallengeFailed:
            return .exclamationmarkShieldFill
        case .loginCaptchaRequired:
            return .checkmarkShieldFill
        case .loginRejected:
            return .personCropCircleFillBadgeXmark
        case .unsupportedDeepLink:
            return .exclamationmarkTriangleFill
        case .fileOperationFailed:
            return .folderFill
        case .notFound, .unknown, .noUpdates, .webImageFailed:
            return .questionmarkCircleFill
        }
    }
}
