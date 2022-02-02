//
//  Persistence.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")

        container.loadPersistentStores {
            guard let error = $1 else { return }
            Logger.error(error as Any)
        }
        return container
    }()
}

protocol ManagedObjectProtocol {
    associatedtype Entity
    func toEntity() -> Entity
}

protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ManagedObjectProtocol

    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> ManagedObject
}

protocol GalleryIdentifiable: NSManagedObject {
    var gid: String { get set }
}
