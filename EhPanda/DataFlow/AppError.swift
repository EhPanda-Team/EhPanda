//
//  AppError.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Foundation

enum AppError: Error, Identifiable, Equatable {
    var id: String { localizedDescription }

    case copyrightClaim(owner: String)
    case expunged(reason: String)
    case networkingFailed
    case parseFailed
    case noUpdates
    case unknown
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
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
        case .unknown:
            return "Unknown Error"
        }
    }
    var symbolName: String {
        switch self {
        case .copyrightClaim, .expunged:
            return "trash.circle.fill"
        case .networkingFailed:
            return "wifi.exclamationmark"
        case .parseFailed:
            return "rectangle.and.text.magnifyingglass"
        case .noUpdates:
            return ""
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    var alertText: String {
        let tryLater = "Please try again later."

        switch self {
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
        case .unknown:
            return ["An unknown error occurred.", tryLater]
                .map(\.localized).joined(separator: "\n")
        }
    }
}
