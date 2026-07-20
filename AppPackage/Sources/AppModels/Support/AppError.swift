import Foundation
import Resources

public enum AppError: Error, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { localizedDescription }

    public init(_ error: any Error) {
        self = error as? AppError ?? .unknown
    }

    case copyrightClaim(String)
    case ipBanned(BanInterval)
    case expunged(String)
    case networkingFailed
    case webImageFailed
    case parseFailed
    case quotaExceeded
    case authenticationRequired
    case fileOperationFailed(String)
    case noUpdates
    case notFound
    case unknown
}

extension AppError {
    public var isRetryable: Bool {
        switch self {
        case .networkingFailed, .parseFailed,
             .fileOperationFailed, .noUpdates, .unknown, .webImageFailed:
            return true
        case .copyrightClaim, .expunged, .quotaExceeded, .authenticationRequired, .notFound,
             .ipBanned:
            return false
        }
    }
    public var localizedDescription: String {
        switch self {
        case .copyrightClaim:
            return String(localized: .appErrorCopyrightClaim)
        case .ipBanned:
            return String(localized: .appErrorIpBanned)
        case .expunged:
            return String(localized: .appErrorGalleryExpunged)
        case .networkingFailed:
            return String(localized: .appErrorNetworkError)
        case .webImageFailed:
            return String(localized: .appErrorWebImageLoadingError)
        case .parseFailed:
            return String(localized: .appErrorParseError)
        case .quotaExceeded:
            return String(localized: .appErrorQuotaExceeded)
        case .authenticationRequired:
            return String(localized: .appErrorAuthenticationRequired)
        case .fileOperationFailed:
            return String(localized: .appErrorFileOperationFailed)
        case .noUpdates:
            return String(localized: .appErrorNoUpdatesAvailable)
        case .notFound:
            return String(localized: .appErrorNotFound)
        case .unknown:
            return String(localized: .appErrorUnknownError)
        }
    }
    public var alertText: String {
        let tryLater = String(localized: .tryLater)
        switch self {
        case .copyrightClaim(let owner):
            return String(localized: .copyrightClaim(owner))
        case .ipBanned(let interval):
            return String(localized: .ipBanned(interval.description))
        case .expunged(let reason):
            switch reason {
            case String(localized: .RConstant.responseGalleryUnavailable):
                return String(localized: .galleryUnavailable)
            default:
                return reason
            }
        case .networkingFailed:
            return [String(localized: .networkError), tryLater].joined(separator: "\n")
        case .parseFailed:
            return [String(localized: .parsing), tryLater].joined(separator: "\n")
        case .quotaExceeded:
            return String(localized: .appErrorQuotaExceededDescription)
        case .authenticationRequired:
            return String(localized: .appErrorAuthenticationRequiredDescription)
        case .fileOperationFailed(let reason):
            return [String(localized: .appErrorLocalFileOperationFailed), reason]
                .filter({ !$0.isEmpty })
                .joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return String(localized: .notFound)
        case .unknown:
            return [String(localized: .unknown), tryLater].joined(separator: "\n")
        }
    }
}

extension AppError {
    public var solution: String? {
        switch self {
        case .networkingFailed:
            String(localized: .appErrorNetworkSolution)
        case .authenticationRequired:
            String(localized: .appErrorAuthenticationSolution)
        case .ipBanned:
            String(localized: .appErrorIpBannedSolution)
        case .quotaExceeded:
            String(localized: .appErrorQuotaExceededSolution)
        case .notFound:
            String(localized: .appErrorNotFoundSolution)
        case .copyrightClaim, .expunged, .webImageFailed, .parseFailed, .fileOperationFailed,
             .noUpdates, .unknown:
            nil
        }
    }
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription
    }

    public var recoverySuggestion: String? {
        solution
    }
}

public enum BanInterval: Equatable, Hashable, Sendable {
    case days(days: Int, hours: Int?)
    case hours(hours: Int, minutes: Int?)
    case minutes(minutes: Int, seconds: Int?)
    case unrecognized(content: String)
}

extension BanInterval {
    public var description: String {
        var params: [String]
        let and = String(localized: .banIntervalAnd)

        switch self {
        case .days(let days, let hours):
            params = [daysWithUnit(days)]
            if let hours = hours {
                params += [and, hoursWithUnit(hours)]
            }
        case .hours(let hours, let minutes):
            params = [hoursWithUnit(hours)]
            if let minutes = minutes {
                params += [and, minutesWithUnit(minutes)]
            }
        case .minutes(let minutes, let seconds):
            params = [minutesWithUnit(minutes)]
            if let seconds = seconds {
                params += [and, secondsWithUnit(seconds)]
            }
        case .unrecognized(let content):
            params = [content]
        }
        return params.filter({ !$0.isEmpty }).joined(separator: " ")
    }

    private func daysWithUnit(_ days: Int) -> String {
        String(localized: .RLocalizable.days(count: days))
    }
    private func hoursWithUnit(_ hours: Int) -> String {
        String(localized: .RLocalizable.hours(count: hours))
    }
    private func minutesWithUnit(_ minutes: Int) -> String {
        String(localized: .RLocalizable.minutes(count: minutes))
    }
    private func secondsWithUnit(_ seconds: Int) -> String {
        String(localized: .RLocalizable.seconds(count: seconds))
    }
}
