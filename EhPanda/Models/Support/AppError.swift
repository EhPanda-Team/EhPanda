//
//  AppError.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
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
    case noUpdates
    case notFound
    case unknown
}

extension AppError {
    var isRetryable: Bool {
        switch self {
        case .databaseCorrupted, .ipBanned, .networkingFailed, .parseFailed,
                .noUpdates, .notFound, .unknown, .webImageFailed:
            return true
        case .copyrightClaim, .expunged:
            return false
        }
    }
    var localizedDescription: String {
        switch self {
        case .databaseCorrupted:
            return "Database Corrupted"
        case .copyrightClaim:
            return "Copyright Claim"
        case .ipBanned:
            return "IP Banned"
        case .expunged:
            return "Gallery Expunged"
        case .networkingFailed:
            return "Network Error"
        case .webImageFailed:
            return "Web image loading error"
        case .parseFailed:
            return "Parse Error"
        case .noUpdates:
            return "No updates available"
        case .notFound:
            return "Not found"
        case .unknown:
            return "Unknown Error"
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
        case .notFound, .unknown, .noUpdates, .webImageFailed:
            return .questionmarkCircleFill
        }
    }
    var alertText: String {
        let tryLater = R.string.localizable.errorViewTitleTryLater()
        switch self {
        case .databaseCorrupted(let reason):
            var lines = [R.string.localizable.errorViewTitleDatabaseCorrupted()]
            if let reason = reason {
                lines.append("(\(reason))")
            }
            return lines.joined(separator: "\n")
        case .copyrightClaim(let owner):
            return R.string.localizable.errorViewTitleCopyrightClaim(owner)
        case .ipBanned(let interval):
            return R.string.localizable.errorViewTitleIpBanned(interval.description)
        case .expunged(let reason):
            switch reason {
            case R.string.constant.websiteResponseGalleryUnavailable():
                return R.string.localizable.errorViewTitleGalleryUnavailable()
            default:
                return reason
            }
        case .networkingFailed:
            return [R.string.localizable.errorViewTitleNetwork(), tryLater].joined(separator: "\n")
        case .parseFailed:
            return [R.string.localizable.errorViewTitleParsing(), tryLater].joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return R.string.localizable.errorViewTitleNotFound()
        case .unknown:
            return [R.string.localizable.errorViewTitleUnknown(), tryLater].joined(separator: "\n")
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
        let and = R.string.localizable.enumBanIntervalDescriptionAnd()

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
        days > 1 ? R.string.localizable.commonValueDays("\(days)")
        : R.string.localizable.commonValueDay("\(days)")
    }
    private func hoursWithUnit(_ hours: Int) -> String {
        hours > 1 ? R.string.localizable.commonValueHours("\(hours)")
        : R.string.localizable.commonValueHour("\(hours)")
    }
    private func minutesWithUnit(_ minutes: Int) -> String {
        minutes > 1 ? R.string.localizable.commonValueMinutes("\(minutes)")
        : R.string.localizable.commonValueMinute("\(minutes)")
    }
    private func secondsWithUnit(_ seconds: Int) -> String {
        seconds > 1 ? R.string.localizable.commonValueSeconds("\(seconds)")
        : R.string.localizable.commonValueSecond("\(seconds)")
    }
}
