//
//  AppEnvMO+CoreDataProperties.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/10.
//

import CoreData

extension AppEnvMO {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppEnvMO> {
        NSFetchRequest<AppEnvMO>(entityName: "AppEnvMO")
    }

    @NSManaged public var user: Data?
    @NSManaged public var filter: Data?
    @NSManaged public var setting: Data?
    @NSManaged public var tagTranslator: Data?
    @NSManaged public var historyKeywords: Data?
}
