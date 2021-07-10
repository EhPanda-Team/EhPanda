//
//  Persistence.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData
import SwiftyBeaver

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        container.loadPersistentStores {
            if let error = $1 {
                SwiftyBeaver.error(error as Any)
            }
        }
        return container
    }()

    static func saveContext() {
        let context = shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                SwiftyBeaver.error(error)
                fatalError("Unresolved error \(error)")
            }
        }
    }

    static func checkExistence<MO: NSManagedObject>(
        entityType: MO.Type,
        predicate: NSPredicate
    ) -> Bool {
        let request = NSFetchRequest<MO>(
            entityName: String(describing: entityType)
        )
        request.fetchLimit = 1
        request.predicate = predicate

        let context = shared.container.viewContext
        let resultCount = (try? context.count(for: request)) ?? 0
        return resultCount > 0
    }

    static func materializedObject(
        in context: NSManagedObjectContext,
        matching predicate: NSPredicate
    ) -> NSManagedObject? {
        for object in context.registeredObjects
        where !object.isFault {
            guard predicate.evaluate(with: object)
            else { continue }
            return object
        }
        return nil
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate
    ) -> MO? {
        let context = shared.container.viewContext
        if let object = materializedObject(
            in: context, matching: predicate
        ) as? MO { return object }

        let request = NSFetchRequest<MO>(
            entityName: String(describing: entityType)
        )
        request.fetchLimit = 1
        request.predicate = predicate
        return try? context.fetch(request).first
    }

    /// Create one if fetch result is empty, and update it.
    static func update<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        commitChanges: ((MO) -> Void)
    ) {
        let storedMO: MO = fetchOrCreate(
            entityType: entityType, gid: gid
        )
        commitChanges(storedMO)
        saveContext()
    }
}

// MARK: Protocol Definition
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
