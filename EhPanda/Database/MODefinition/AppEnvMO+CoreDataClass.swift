//
//  AppEnvMO+CoreDataClass.swift
//  EhPanda
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
    @discardableResult func toManagedObject(in context: NSManagedObjectContext) -> AppEnvMO {
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
