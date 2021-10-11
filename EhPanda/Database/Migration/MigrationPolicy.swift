//
//  MigrationPolicy.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/24.
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
