//
//  AppEnvMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/10.
//

import CoreData

public class AppEnvMO: NSManagedObject {}

extension AppEnvMO: ManagedObjectProtocol {
    func toEntity() -> AppEnv {
        AppEnv(
            user: user?.toObject() ?? User(),
            setting: setting?.toObject() ?? Setting(),
            searchFilter: searchFilter?.toObject() ?? Filter(),
            globalFilter: globalFilter?.toObject() ?? Filter(),
            watchedFilter: watchedFilter?.toObject() ?? Filter(),
            tagTranslator: tagTranslator?.toObject() ?? TagTranslator(),
            historyKeywords: historyKeywords?.toObject() ?? [String](),
            quickSearchWords: quickSearchWords?.toObject() ?? [QuickSearchWord]()
        )
    }
}

extension AppEnv: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> AppEnvMO {
        let appEnvMO = AppEnvMO(context: context)

        appEnvMO.user = user.toData()
        appEnvMO.setting = setting.toData()
        appEnvMO.searchFilter = searchFilter.toData()
        appEnvMO.globalFilter = globalFilter.toData()
        appEnvMO.watchedFilter = watchedFilter.toData()
        appEnvMO.tagTranslator = tagTranslator.toData()
        appEnvMO.historyKeywords = historyKeywords.toData()
        appEnvMO.quickSearchWords = quickSearchWords.toData()

        return appEnvMO
    }
}

struct AppEnv: Codable {
    let user: User
    let setting: Setting
    let searchFilter: Filter
    let globalFilter: Filter
    let watchedFilter: Filter
    let tagTranslator: TagTranslator
    let historyKeywords: [String]
    let quickSearchWords: [QuickSearchWord]
}

struct TagTranslator: Codable, Equatable {
    var language: TranslatableLanguage = .japanese
    var updatedDate: Date = .distantPast
    var contents = [String: String]()

    private func lookup(text: String) -> String {
        guard let translatedText = contents[text],
              !translatedText.isEmpty
        else { return text }

        return translatedText
    }
    func tryTranslate(text: String, returnOriginal: Bool) -> String {
        guard !returnOriginal else { return text }
        if let range = text.range(of: ":") {
            let before = text[...range.lowerBound]
            let after = String(text[range.upperBound...])
            let result = before + lookup(text: after)
            return String(result)
        }
        return lookup(text: text)
    }
}

extension TagTranslator: CustomStringConvertible {
    var description: String {
        "TagTranslator(language: \(language), "
        + "updatedDate: \(updatedDate), "
        + "contents: \(contents.count))"
    }
}
