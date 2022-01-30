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

extension AppError: LocalizedError {
    var isRetryable: Bool {
        switch self {
        case .ipBanned, .networkingFailed, .parseFailed,
                .noUpdates, .notFound, .unknown, .webImageFailed:
            return true
        case .copyrightClaim, .expunged:
            return false
        }
    }
    var localizedDescription: String {
        switch self {
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
        case .copyrightClaim(let owner):
            return R.string.localizable.errorViewTitleCopyrightClaim(owner)
        case .ipBanned(let interval):
            return R.string.localizable.errorViewTitleIpBanned(interval.description)
        case .expunged(let reason):
            switch reason {
            case Defaults.Response.galleryUnavailable:
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
        switch self {
        case .days(let days, let hours):
            params = [
                String(days), days > 1
                ? R.string.localizable.enumBanIntervalDescriptionDays()
                : R.string.localizable.enumBanIntervalDescriptionDay()
            ]
            if let hours = hours {
                params += [
                    R.string.localizable.enumBanIntervalDescriptionAnd(), String(hours), hours > 1
                    ? R.string.localizable.enumBanIntervalDescriptionHours()
                    : R.string.localizable.enumBanIntervalDescriptionHour()
                ]
            }
        case .hours(let hours, let minutes):
            params = [
                String(hours), hours > 1
                ? R.string.localizable.enumBanIntervalDescriptionHours()
                : R.string.localizable.enumBanIntervalDescriptionHour()
            ]
            if let minutes = minutes {
                params += [
                    R.string.localizable.enumBanIntervalDescriptionAnd(), String(minutes), minutes > 1
                    ? R.string.localizable.enumBanIntervalDescriptionMinutes()
                    : R.string.localizable.enumBanIntervalDescriptionMinute()
                ]
            }
        case .minutes(let minutes, let seconds):
            params = [
                String(minutes), minutes > 1
                ? R.string.localizable.enumBanIntervalDescriptionMinutes()
                : R.string.localizable.enumBanIntervalDescriptionMinute()
            ]
            if let seconds = seconds {
                params += [
                    R.string.localizable.enumBanIntervalDescriptionAnd(), String(seconds), seconds > 1
                    ? R.string.localizable.enumBanIntervalDescriptionSeconds()
                    : R.string.localizable.enumBanIntervalDescriptionSecond()
                ]
            }
        case .unrecognized(let content):
            params = [content]
        }
        return params.joined()
    }
}
