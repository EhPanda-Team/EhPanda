public enum DownloadFailureCode: String, Codable, Equatable, Sendable {
    /// Keeps the value already written into download manifests.
    case imageLimitReached = "quotaExceeded"
    /// Keeps the value already written into download manifests.
    case loginRequired = "authenticationRequired"
    case fileOperationFailed
    case ipBanned
    case networkingFailed
    case parseFailed
    case notFound
    case unknown
}

public struct DownloadFailure: Codable, Equatable, Sendable {
    public var code: DownloadFailureCode
    public var message: String

    public init(code: DownloadFailureCode, message: String) {
        self.code = code
        self.message = message
    }

    public init(error: AppError) {
        switch error {
        case .imageLimitReached:
            self = .init(code: .imageLimitReached, message: error.alertText)
        case .loginRequired:
            self = .init(code: .loginRequired, message: error.alertText)
        case .fileOperationFailed(let reason):
            self = .init(code: .fileOperationFailed, message: reason)
        case .ipBanned(let interval):
            self = .init(code: .ipBanned, message: interval.description)
        case .networkingFailed:
            self = .init(code: .networkingFailed, message: error.alertText)
        case .parseFailed:
            self = .init(code: .parseFailed, message: error.alertText)
        case .notFound:
            self = .init(code: .notFound, message: error.alertText)
        default:
            self = .init(code: .unknown, message: error.alertText)
        }
    }

    public var appError: AppError {
        switch code {
        case .imageLimitReached:
            return .imageLimitReached
        case .loginRequired:
            return .loginRequired
        case .fileOperationFailed:
            return .fileOperationFailed(message)
        case .ipBanned:
            return .ipBanned(.unrecognized(content: message))
        case .networkingFailed:
            return .networkingFailed
        case .parseFailed:
            return .parseFailed
        case .notFound:
            return .notFound
        case .unknown:
            return .unknown
        }
    }
}
