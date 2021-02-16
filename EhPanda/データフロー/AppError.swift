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
    case fileError
    case unknown
}

extension AppError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .networkingFailed:
            return "ネットワークエラー"
        case .parseFailed:
            return "解析エラー"
        case .fileError:
            return "ファイル操作エラー"
        case .unknown:
            return "未知エラー"
        }
    }
}
