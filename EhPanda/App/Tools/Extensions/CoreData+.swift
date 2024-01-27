//
//  CoreData+.swift
//  EhPanda
//
//  Created by Chihchy on 2024/01/28.
//

import CoreData

extension NSManagedObjectContext {
    func saveIfNeeded() {
        let task = { [weak self] in
            guard let self = self else { return }
            if self.hasChanges {
                do {
                    try self.save()
                } catch {
                    Logger.error(error)
                    assertionFailure("Unresolved error \(error)")
                }
            }
        }
        performAndWait(task)
    }
}
