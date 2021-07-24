//
//  MigrationPolicy.swift
//  MigrationPolicy
//
//  Created by 荒木辰造 on 2021/07/24.
//

import CoreData

struct MigrationUtility {
    static func mappingFromString<T: LosslessStringConvertible>(
        previousMO: NSManagedObject,
        targetMO: NSManagedObject,
        type: T.Type, key: String
    ) {
        let storedValue = previousMO.value(forKey: key) as? String
        let newValue = T(storedValue ?? "")
        targetMO.setValue(newValue, forKey: key)
    }
}

class ModelToModel2Policy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard let entityName = manager
                .destinationEntity(for: mapping)?.name
        else { return }

        let targetMO = NSEntityDescription.insertNewObject(
            forEntityName: entityName,
            into: manager.destinationContext
        )

        ["likeCount", "pageCount", "ratingCount"].forEach { key in
            MigrationUtility.mappingFromString(
                previousMO: sInstance,
                targetMO: targetMO,
                type: Int64.self,
                key: key
            )
        }
        MigrationUtility.mappingFromString(
            previousMO: sInstance,
            targetMO: targetMO,
            type: Float.self,
            key: "sizeCount"
        )

        manager.associate(
            sourceInstance: sInstance,
            withDestinationInstance: targetMO,
            for: mapping
        )
    }
}
