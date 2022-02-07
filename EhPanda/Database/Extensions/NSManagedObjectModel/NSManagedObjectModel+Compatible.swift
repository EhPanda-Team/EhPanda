//
//  NSManagedObjectModel+Compatible.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectModel {
    static func compatibleModelForStoreMetadata(_ metadata: [String: Any]) -> NSManagedObjectModel? {
        NSManagedObjectModel.mergedModel(from: [Bundle.main], forStoreMetadata: metadata)
    }
}
