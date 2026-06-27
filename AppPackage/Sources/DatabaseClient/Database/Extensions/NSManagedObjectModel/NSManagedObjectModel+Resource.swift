import Foundation
import AppModels
import CoreData

extension NSManagedObjectModel {
    public static func managedObjectModel(forResource resource: String) throws -> NSManagedObjectModel {
        let subdirectory = "Model.momd"
        let omoURL = Bundle.module.url(forResource: resource, withExtension: "omo", subdirectory: subdirectory)
        let momURL = Bundle.module.url(forResource: resource, withExtension: "mom", subdirectory: subdirectory)

        guard let url = omoURL ?? momURL else {
            throw AppError.databaseCorrupted("Unable to find model in bundle.")
        }
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            throw AppError.databaseCorrupted("Unable to load model in bundle.")
        }

        return model
    }
}
