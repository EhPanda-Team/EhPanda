//
//  AppError.swift
//  EhPanda
//

import Foundation
import SFSafeSymbols

enum AppError: Error, Identifiable, Equatable, Hashable {
    var id: String { localizedDescription }

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
    var isRetryable: Bool {
        switch self {
        case .databaseCorrupted, .networkingFailed, .parseFailed,
                .fileOperationFailed, .noUpdates, .unknown, .webImageFailed:
            return true
        case .copyrightClaim, .expunged, .quotaExceeded, .authenticationRequired, .notFound,
                .ipBanned:
            return false
        }
    }
    var localizedDescription: String {
        switch self {
        case .databaseCorrupted:
            return L10n.Localizable.AppError.LocalizedDescription.databaseCorrupted
        case .copyrightClaim:
            return L10n.Localizable.AppError.LocalizedDescription.copyrightClaim
        case .ipBanned:
            return L10n.Localizable.AppError.LocalizedDescription.ipBanned
        case .expunged:
            return L10n.Localizable.AppError.LocalizedDescription.galleryExpunged
        case .networkingFailed:
            return L10n.Localizable.AppError.LocalizedDescription.networkError
        case .webImageFailed:
            return L10n.Localizable.AppError.LocalizedDescription.webImageLoadingError
        case .parseFailed:
            return L10n.Localizable.AppError.LocalizedDescription.parseError
        case .quotaExceeded:
            return L10n.Localizable.AppError.LocalizedDescription.quotaExceeded
        case .authenticationRequired:
            return L10n.Localizable.AppError.LocalizedDescription.authenticationRequired
        case .fileOperationFailed:
            return L10n.Localizable.AppError.LocalizedDescription.fileOperationFailed
        case .noUpdates:
            return L10n.Localizable.AppError.LocalizedDescription.noUpdatesAvailable
        case .notFound:
            return L10n.Localizable.AppError.LocalizedDescription.notFound
        case .unknown:
            return L10n.Localizable.AppError.LocalizedDescription.unknownError
        }
    }
    var symbol: SFSymbol {
        switch self {
        case .databaseCorrupted:
            return .exclamationmarkTriangleFill
        case .ipBanned:
            return .networkBadgeShieldHalfFilled
        case .copyrightClaim, .expunged:
            return .trashCircleFill
        case .networkingFailed:
            return .wifiExclamationmark
        case .parseFailed:
            return .rectangleAndTextMagnifyingglass
        case .quotaExceeded:
            return .speedometer
        case .authenticationRequired:
            return .lockCircleFill
        case .fileOperationFailed:
            return .folderFill
        case .notFound, .unknown, .noUpdates, .webImageFailed:
            return .questionmarkCircleFill
        }
    }
    var alertText: String {
        let tryLater = L10n.Localizable.ErrorView.Title.tryLater
        switch self {
        case .databaseCorrupted(let reason):
            var lines = [L10n.Localizable.ErrorView.Title.databaseCorrupted]
            if let reason = reason {
                lines.append("(\(reason))")
            }
            return lines.joined(separator: "\n")
        case .copyrightClaim(let owner):
            return L10n.Localizable.ErrorView.Title.copyrightClaim(owner)
        case .ipBanned(let interval):
            return L10n.Localizable.ErrorView.Title.ipBanned(interval.description)
        case .expunged(let reason):
            switch reason {
            case L10n.Constant.Website.Response.galleryUnavailable:
                return L10n.Localizable.ErrorView.Title.galleryUnavailable
            default:
                return reason
            }
        case .networkingFailed:
            return [L10n.Localizable.ErrorView.Title.network, tryLater].joined(separator: "\n")
        case .parseFailed:
            return [L10n.Localizable.ErrorView.Title.parsing, tryLater].joined(separator: "\n")
        case .quotaExceeded:
            return L10n.Localizable.AppError.Alert.quotaExceeded
        case .authenticationRequired:
            return L10n.Localizable.AppError.Alert.authenticationRequired
        case .fileOperationFailed(let reason):
            return [L10n.Localizable.AppError.Alert.localFileOperationFailed, reason]
                .filter(\.notEmpty)
                .joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return L10n.Localizable.ErrorView.Title.notFound
        case .unknown:
            return [L10n.Localizable.ErrorView.Title.unknown, tryLater].joined(separator: "\n")
        }
    }
}

enum BanInterval: Equatable, Hashable {
    case days(_: Int, hours: Int?)
    case hours(_: Int, minutes: Int?)
    case minutes(_: Int, seconds: Int?)
    case unrecognized(content: String)
}

extension BanInterval {
    var description: String {
        var params: [String]
        let and = L10n.Localizable.Enum.BanInterval.Description.and

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
        return params.filter(\.notEmpty).joined(separator: " ")
    }

    private func daysWithUnit(_ days: Int) -> String {
        days > 1 ? L10n.Localizable.Common.Value.days("\(days)")
        : L10n.Localizable.Common.Value.day("\(days)")
    }
    private func hoursWithUnit(_ hours: Int) -> String {
        hours > 1 ? L10n.Localizable.Common.Value.hours("\(hours)")
        : L10n.Localizable.Common.Value.hour("\(hours)")
    }
    private func minutesWithUnit(_ minutes: Int) -> String {
        minutes > 1 ? L10n.Localizable.Common.Value.minutes("\(minutes)")
        : L10n.Localizable.Common.Value.minute("\(minutes)")
    }
    private func secondsWithUnit(_ seconds: Int) -> String {
        seconds > 1 ? L10n.Localizable.Common.Value.seconds("\(seconds)")
        : L10n.Localizable.Common.Value.second("\(seconds)")
    }
}
