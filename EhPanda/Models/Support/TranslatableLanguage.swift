//
//  TranslatableLanguage.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

enum TranslatableLanguage: Codable, CaseIterable {
    case japanese
    case simplifiedChinese
    case traditionalChinese
}

extension TranslatableLanguage {
    static var current: TranslatableLanguage? {
        guard let preferredLanguage = Locale.preferredLanguages.first,
              let translatableLanguage = TranslatableLanguage.allCases.compactMap({ lang in
                  preferredLanguage.contains(lang.languageCode) ? lang : nil
              }).first else { return nil }
        return translatableLanguage
    }
    var languageCode: String {
        switch self {
        case .japanese:
            return "ja"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
    var repoName: String {
        switch self {
        case .japanese:
            return "tatsuz0u/EhTagTranslation_Database_JPN"
        case .simplifiedChinese, .traditionalChinese:
            return "EhTagTranslation/Database"
        }
    }
    var remoteFilename: String {
        switch self {
        case .japanese:
            return "jpn_text.json"
        case .simplifiedChinese, .traditionalChinese:
            return "db.raw.json"
        }
    }
    var checkUpdateURL: URL {
        URLUtil.githubAPI(repoName: repoName)
    }
    var downloadURL: URL {
        URLUtil.githubDownload(repoName: repoName, fileName: remoteFilename)
    }
}
