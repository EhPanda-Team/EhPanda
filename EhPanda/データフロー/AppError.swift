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
    case fileError
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .networkingFailed:
            return "ネットワークエラー"
        case .fileError:
            return "ファイル操作エラー"
        }
    }
}
