//
//  AppEnv.swift
//  EhPanda
//

struct AppEnv: Codable, Equatable {
    let user: User
    let setting: Setting
    let searchFilter: Filter
    let globalFilter: Filter
    let watchedFilter: Filter
    let tagTranslator: TagTranslator
    let historyKeywords: [String]
    let quickSearchWords: [QuickSearchWord]
}

extension AppEnv: CustomStringConvertible {
    var description: String {
        let params = String(
            describing: [
                "user": user,
                "setting": setting,
                "tagTranslator": tagTranslator,
                "historyKeywordsCount": historyKeywords.count,
                "quickSearchWordsCount": quickSearchWords.count
            ]
            as [String: Any]
        )
        return "AppEnv(\(params))"
    }
}
