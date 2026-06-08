//
//  DownloadFailure.swift
//  EhPanda
//

enum DownloadFailureCode: String, Codable, Equatable, Sendable {
    case quotaExceeded
    case authenticationRequired
    case fileOperationFailed
    case ipBanned
    case networkingFailed
    case parseFailed
    case notFound
    case unknown
}

struct DownloadFailure: Codable, Equatable, Sendable {
    var code: DownloadFailureCode
    var message: String

    init(code: DownloadFailureCode, message: String) {
        self.code = code
        self.message = message
    }

    init(error: AppError) {
        switch error {
        case .quotaExceeded:
            self = .init(code: .quotaExceeded, message: error.alertText)
        case .authenticationRequired:
            self = .init(code: .authenticationRequired, message: error.alertText)
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

    var appError: AppError {
        switch code {
        case .quotaExceeded:
            return .quotaExceeded
        case .authenticationRequired:
            return .authenticationRequired
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
