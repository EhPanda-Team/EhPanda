import Foundation
import CoreData

extension NSManagedObjectModel {
    static func compatibleModelForStoreMetadata(_ metadata: [String: Any]) -> NSManagedObjectModel? {
        NSManagedObjectModel.mergedModel(from: [Bundle.module], forStoreMetadata: metadata)
    }
}
