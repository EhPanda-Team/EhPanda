//
//  ManagedObjectProtocol.swift
//  Created by swifting.io Team
//

import CoreData
import SwiftyBeaver

protocol ManagedObjectProtocol {
    associatedtype Entity
    func toEntity() -> Entity
}
protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ManagedObjectProtocol
    func toManagedObject(in context: NSManagedObjectContext) -> ManagedObject
}

extension ManagedObjectProtocol where Self: NSManagedObject {

    static func getOrCreateSingle(
        with id: String,
        and key: String = "gid",
        from context: NSManagedObjectContext
    ) -> Self {
        let result = single(
            with: id,
            from: context
        ) ?? insertNew(in: context)
        result.setValue(id, forKey: key)

        return result
    }

    static func single(
        from context: NSManagedObjectContext,
        with predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) -> Self? {
        fetch(
            from: context,
            with: predicate,
            sortDescriptors: sortDescriptors,
            fetchLimit: 1
        )?.first
    }

    static func single(
        with id: String,
        and key: String = "gid",
        from context: NSManagedObjectContext
    ) -> Self? {
        let predicate = NSPredicate(format: "%@ == %@", key, id)
        return single(from: context, with: predicate, sortDescriptors: nil)
    }

    static func insertNew(in context: NSManagedObjectContext) -> Self {
        Self(context: context)
    }

    static func fetch(
        from context: NSManagedObjectContext,
        with predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?,
        fetchLimit: Int?
    ) -> [Self]? {

        let fetchRequest = Self.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        fetchRequest.returnsObjectsAsFaults = false

        if let fetchLimit = fetchLimit {
            fetchRequest.fetchLimit = fetchLimit
        }

        var result: [Self]?
        context.performAndWait { () -> Void in
            do {
                result = try context.fetch(fetchRequest) as? [Self]
            } catch {
                result = nil
                SwiftyBeaver.error("CoreData fetch error \(error)")
            }
        }
        return result
    }
}
