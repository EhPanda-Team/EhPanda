import Foundation
import Resources

public enum AppError: Error, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { localizedDescription }

    public init(_ error: any Error) {
        self = error as? AppError ?? .unknown
    }

    case databaseCorrupted(String?)
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
        case .databaseCorrupted, .networkingFailed, .parseFailed,
             .fileOperationFailed, .noUpdates, .unknown, .webImageFailed:
            return true
        case .copyrightClaim, .expunged, .quotaExceeded, .authenticationRequired, .notFound,
             .ipBanned:
            return false
        }
    }
    public var localizedDescription: String {
        switch self {
        case .databaseCorrupted:
            return String(localized: .appErrorDatabaseCorrupted)
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
        case .databaseCorrupted(let reason):
            var lines = [String(localized: .databaseCorrupted)]
            if let reason = reason {
                lines.append("(\(reason))")
            }
            return lines.joined(separator: "\n")
        case .copyrightClaim(let owner):
            return String(localized: .copyrightClaim(owner))
        case .ipBanned(let interval):
            return String(localized: .ipBanned(interval.description))
        case .expunged(let reason):
            switch reason {
            case L10n.Constant.galleryUnavailable:
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
                .filter { !$0.isEmpty }
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

public enum BanInterval: Equatable, Hashable, Sendable {
    case days(_: Int, hours: Int?)
    case hours(_: Int, minutes: Int?)
    case minutes(_: Int, seconds: Int?)
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
        return params.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func daysWithUnit(_ days: Int) -> String {
        days > 1 ? L10n.Localizable.Common.days("\(days)")
            : L10n.Localizable.Common.day("\(days)")
    }
    private func hoursWithUnit(_ hours: Int) -> String {
        hours > 1 ? L10n.Localizable.Common.hours("\(hours)")
            : L10n.Localizable.Common.hour("\(hours)")
    }
    private func minutesWithUnit(_ minutes: Int) -> String {
        minutes > 1 ? L10n.Localizable.Common.minutes("\(minutes)")
            : L10n.Localizable.Common.minute("\(minutes)")
    }
    private func secondsWithUnit(_ seconds: Int) -> String {
        seconds > 1 ? L10n.Localizable.Common.seconds("\(seconds)")
            : L10n.Localizable.Common.second("\(seconds)")
    }
}
