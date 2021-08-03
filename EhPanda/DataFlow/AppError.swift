//
//  AppError.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Foundation

enum AppError: Error, Identifiable, Equatable {
    var id: String { localizedDescription }

    case networkingFailed
    case mpvActivated(
        mpvKey: String,
        imgKeys: [Int: String]
    )
    case parseFailed
    case unknown
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .networkingFailed:
            return "Network Error"
        case .mpvActivated:
            return "MPV is activated"
        case .parseFailed:
            return "Parse Error"
        case .unknown:
            return "Unknown Error"
        }
    }
}
