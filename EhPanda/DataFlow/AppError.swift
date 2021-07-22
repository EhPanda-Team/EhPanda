//
//  AppError.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Foundation

enum AppError: Error, Identifiable {
    var id: String { localizedDescription }

    case networkingFailed
    case parseFailed
    case unknown
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .networkingFailed:
            return "Network Error"
        case .parseFailed:
            return "Parse Error"
        case .unknown:
            return "Unknown Error"
        }
    }
}
