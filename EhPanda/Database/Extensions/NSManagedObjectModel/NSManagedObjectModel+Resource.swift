//
//  NSManagedObjectModel+Resource.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectModel {
    static func managedObjectModel(forResource resource: String) -> NSManagedObjectModel {
        let subdirectory = "Model.momd"
        let omoURL = Bundle.main.url(forResource: resource, withExtension: "omo", subdirectory: subdirectory)
        let momURL = Bundle.main.url(forResource: resource, withExtension: "mom", subdirectory: subdirectory)

        guard let url = omoURL ?? momURL else {
            let message = "Unable to find model in bundle."
            Logger.error(message)
            fatalError(message)
        }
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            let message = "Unable to load model in bundle."
            Logger.error(message)
            fatalError(message)
        }

        return model
    }
}
