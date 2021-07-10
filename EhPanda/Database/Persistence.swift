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
        entityType: MO.Type, predicate: NSPredicate
    ) -> Bool {
        fetch(entityType: entityType, predicate: predicate) != nil
    }

    static func materializedObjects(
        in context: NSManagedObjectContext,
        matching predicate: NSPredicate
    ) -> [NSManagedObject] {
        var objects = [NSManagedObject]()
        for object in context.registeredObjects
        where !object.isFault {
            guard object.entity.attributesByName
                    .keys.contains("gid"),
                  predicate.evaluate(with: object)
            else { continue }
            objects.append(object)
        }
        return objects
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true
    ) -> MO? {
        fetch(
            entityType: entityType, fetchLimit: 1,
            predicate: predicate, findBeforeFetch: findBeforeFetch
        ).first
    }

    static func fetch<MO: NSManagedObject>(
        entityType: MO.Type,
        fetchLimit: Int = 0,
        predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) -> [MO] {
        let context = shared.container.viewContext
        if findBeforeFetch, let predicate = predicate {
            if let objects = materializedObjects(
                in: context, matching: predicate
            ) as? [MO], !objects.isEmpty { return objects }
        }
        let request = NSFetchRequest<MO>(
            entityName: String(describing: entityType)
        )
        request.predicate = predicate
        request.fetchLimit = fetchLimit
        request.sortDescriptors = sortDescriptors
        return (try? context.fetch(request)) ?? []
    }

    static func fetchOrCreate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil
    ) -> MO {
        if let storedMO = fetch(
            entityType: entityType,
            predicate: predicate
        ) {
            return storedMO
        } else {
            let newMO = MO(
                context: shared
                    .container
                    .viewContext
            )
            saveContext()
            return newMO
        }
    }

    static func update<MO: NSManagedObject>(
        entityType: MO.Type,
        predicate: NSPredicate? = nil,
        createIfNil: Bool = false,
        commitChanges: ((MO) -> Void)
    ) {
        let storedMO: MO?
        if createIfNil {
            storedMO = fetchOrCreate(
                entityType: entityType,
                predicate: predicate
            )
        } else {
            storedMO = fetch(
                entityType: entityType,
                predicate: predicate
            )
        }
        if let storedMO = storedMO {
            commitChanges(storedMO)
            saveContext()
        }
    }

    static func update<MO: GalleryIdentifiable>(
        entityType: MO.Type, gid: String,
        createIfNil: Bool = false,
        commitChanges: ((MO) -> Void)
    ) {
        let storedMO: MO?
        if createIfNil {
            storedMO = fetchOrCreate(
                entityType: entityType, gid: gid
            )
        } else {
            storedMO = fetch(
                entityType: entityType, gid: gid
            )
        }
        if let storedMO = storedMO {
            commitChanges(storedMO)
            saveContext()
        }
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
