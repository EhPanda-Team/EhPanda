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
            return L10n.Localizable.AppError.databaseCorrupted
        case .copyrightClaim:
            return L10n.Localizable.AppError.copyrightClaim
        case .ipBanned:
            return L10n.Localizable.AppError.ipBanned
        case .expunged:
            return L10n.Localizable.AppError.galleryExpunged
        case .networkingFailed:
            return L10n.Localizable.AppError.networkError
        case .webImageFailed:
            return L10n.Localizable.AppError.webImageLoadingError
        case .parseFailed:
            return L10n.Localizable.AppError.parseError
        case .quotaExceeded:
            return L10n.Localizable.AppError.quotaExceeded
        case .authenticationRequired:
            return L10n.Localizable.AppError.authenticationRequired
        case .fileOperationFailed:
            return L10n.Localizable.AppError.fileOperationFailed
        case .noUpdates:
            return L10n.Localizable.AppError.noUpdatesAvailable
        case .notFound:
            return L10n.Localizable.AppError.notFound
        case .unknown:
            return L10n.Localizable.AppError.unknownError
        }
    }
    public var alertText: String {
        let tryLater = L10n.Localizable.ErrorView.tryLater
        switch self {
        case .databaseCorrupted(let reason):
            var lines = [L10n.Localizable.ErrorView.databaseCorrupted]
            if let reason = reason {
                lines.append("(\(reason))")
            }
            return lines.joined(separator: "\n")
        case .copyrightClaim(let owner):
            return L10n.Localizable.ErrorView.copyrightClaim(owner)
        case .ipBanned(let interval):
            return L10n.Localizable.ErrorView.ipBanned(interval.description)
        case .expunged(let reason):
            switch reason {
            case L10n.Constant.galleryUnavailable:
                return L10n.Localizable.ErrorView.galleryUnavailable
            default:
                return reason
            }
        case .networkingFailed:
            return [L10n.Localizable.ErrorView.network, tryLater].joined(separator: "\n")
        case .parseFailed:
            return [L10n.Localizable.ErrorView.parsing, tryLater].joined(separator: "\n")
        case .quotaExceeded:
            return L10n.Localizable.AppError.quotaExceededDescription
        case .authenticationRequired:
            return L10n.Localizable.AppError.authenticationRequiredDescription
        case .fileOperationFailed(let reason):
            return [L10n.Localizable.AppError.localFileOperationFailed, reason]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return L10n.Localizable.ErrorView.notFound
        case .unknown:
            return [L10n.Localizable.ErrorView.unknown, tryLater].joined(separator: "\n")
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
        let and = L10n.Localizable.BanInterval.and

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
