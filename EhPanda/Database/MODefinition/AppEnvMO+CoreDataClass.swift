//
//  AppEnvMO+CoreDataClass.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/10.
//

import CoreData

public class AppEnvMO: NSManagedObject {}

extension AppEnvMO: ModelConvertible {
    func toModel() -> AppEnv {
        .init(
            user: user?.toObject() ?? .init(),
            setting: setting?.toObject() ?? .init(),
            searchFilter: searchFilter?.toObject() ?? .init(),
            globalFilter: globalFilter?.toObject() ?? .init(),
            watchedFilter: watchedFilter?.toObject() ?? .init(),
            tagTranslator: tagTranslator?.toObject() ?? .init(),
            historyKeywords: historyKeywords?.toObject() ?? .init(),
            quickSearchWords: quickSearchWords?.toObject() ?? .init()
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
