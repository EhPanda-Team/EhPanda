//
//  CoreDataVersion.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import CoreData

enum CoreDataMigrationVersion: String, CaseIterable {
    case version1 = "Model"
    case version2 = "Model 2"
    case version3 = "Model 3"
    case version4 = "Model 4"
    case version5 = "Model 5"
    case version6 = "Model 6"
    case version7 = "Model 7"

    static func current() throws -> CoreDataMigrationVersion {
        guard let latest = allCases.last else {
            throw AppError.databaseCorrupted("No model versions found.")
        }
        return latest
    }

    func nextVersion() -> CoreDataMigrationVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return .version3
        case .version3:
            return .version4
        case .version4:
            return .version5
        case .version5:
            return .version6
        case .version6:
            return .version7
        case .version7:
            return nil
        }
    }
}
