//
//  AppError.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Foundation

enum AppError: Error, Identifiable, Equatable, Hashable {
    var id: String { localizedDescription }

    case ipBanned(interval: BanInterval)
    case copyrightClaim(owner: String)
    case expunged(reason: String)
    case networkingFailed
    case parseFailed
    case noUpdates
    case notFound
    case unknown
}

extension AppError: LocalizedError {
    var isRetryable: Bool {
        switch self {
        case .ipBanned, .networkingFailed, .parseFailed,
                .noUpdates, .notFound, .unknown:
            return true
        case .copyrightClaim, .expunged:
            return false
        }
    }
    var localizedDescription: String {
        switch self {
        case .ipBanned:
            return "IP Banned"
        case .copyrightClaim:
            return "Copyright Claim"
        case .expunged:
            return "Gallery Expunged"
        case .networkingFailed:
            return "Network Error"
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
    var symbolName: String {
        switch self {
        case .ipBanned:
            return "network.badge.shield.half.filled"
        case .copyrightClaim, .expunged:
            return "trash.circle.fill"
        case .networkingFailed:
            return "wifi.exclamationmark"
        case .parseFailed:
            return "rectangle.and.text.magnifyingglass"
        case .noUpdates:
            return ""
        case .notFound, .unknown:
            return "questionmark.circle.fill"
        }
    }
    // swiftlint:disable line_length
    var alertText: String {
        let tryLater = "Please try again later."

        switch self {
        case .ipBanned(let interval):
            return "Your IP address has been temporarily banned for excessive pageloads which indicates that you are using automated mirroring / harvesting software.".localized + " " + interval.description
        case .copyrightClaim(let owner):
            return "This gallery is unavailable due to a copyright claim by PLACEHOLDER. Sorry about that."
                .localized.replacingOccurrences(of: "PLACEHOLDER", with: owner)
        case .expunged(let reason):
            return reason.localized
        case .networkingFailed:
            return ["A network error occurred.", tryLater]
                .map(\.localized).joined(separator: "\n")
        case .parseFailed:
            return ["A parsing error occurred.", tryLater]
                .map(\.localized).joined(separator: "\n")
        case .noUpdates:
            return ""
        case .notFound:
            return "There seems to be nothing here."
        case .unknown:
            return ["An unknown error occurred.", tryLater]
                .map(\.localized).joined(separator: "\n")
        }
    }
    // swiftlint:enable line_length
}

enum BanInterval: Equatable, Hashable {
    case days(_: Int, hours: Int?)
    case hours(_: Int, minutes: Int?)
    case minutes(_: Int, seconds: Int?)
    case unrecognized(content: String)
}

extension BanInterval {
    var description: String {
        let base = "The ban expires in PLACEHOLDER.".localized
        var placeholder = ""

        switch self {
        case .days(let days, let hours):
            var params = [String(days), "BAN_INTERVAL_DAYS"]
            if let hours = hours {
                params += [
                    "BAN_INTERVAL_AND", String(hours), "BAN_INTERVAL_HOURS"
                ]
            }
            placeholder = params.map{ $0.localized }.joined(separator: "")
        case .hours(let hours, let minutes):
            var params = [String(hours), "BAN_INTERVAL_HOURS"]
            if let minutes = minutes {
                params += [
                    "BAN_INTERVAL_AND", String(minutes), "BAN_INTERVAL_MINUTES"
                ]
            }
            placeholder = params.map{ $0.localized }.joined(separator: "")
        case .minutes(let minutes, let seconds):
            var params = [String(minutes), "BAN_INTERVAL_MINUTES"]
            if let seconds = seconds {
                params += [
                    "BAN_INTERVAL_AND", String(seconds), "BAN_INTERVAL_SECONDS"
                ]
            }
            placeholder = params.map{ $0.localized }.joined(separator: "")
        case .unrecognized(let content):
            placeholder = content
        }

        return base.replacingOccurrences(of: "PLACEHOLDER", with: placeholder)
    }
}
